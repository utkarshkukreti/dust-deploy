module Dust
  class Deploy
    private

    # deploy firewall rules
    def iptables node, rules
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # install iptables
      if node.is_os? ['debian', 'ubuntu', 'gentoo'], true
        node.install_package 'iptables'

      elsif node.is_os? [ 'centos', 'scientific' ], true
        node.install_package 'iptables-ipv6'

      else
        Dust.print_failed 'os not supported'
        return 
      end

      # configure attributes (using empty arrays as default)
      rules['ports'] ||= []
      rules['ipv4-custom-input-rules'] ||= []
      rules['ipv6-custom-input-rules'] ||= []
      rules['ipv4-custom-output-rules'] ||= []
      rules['ipv6-custom-output-rules'] ||= []
      rules['ipv4-custom-forward-rules'] ||= []
      rules['ipv6-custom-forward-rules'] ||= []
      rules['ipv4-custom-prerouting-rules'] ||= []
      rules['ipv6-custom-prerouting-rules'] ||= []
      rules['ipv4-custom-postrouting-rules'] ||= []
      rules['ipv6-custom-postrouting-rules'] ||= []

      # convert ports: int to array if its just a single int so .each won't get hickups
      rules['ports'] = [ rules['ports'] ] if rules['ports'].class == Fixnum

      [ 'iptables', 'ip6tables' ].each do |iptables|
        ipv4 = iptables == 'iptables'
        ipv6 = iptables == 'ip6tables'

        Dust.print_msg "configuring and deploying ipv4 rules\n" if ipv4
        Dust.print_msg "configuring and deploying ipv6 rules\n" if ipv6

        rule_file = '' 

        # default policy for chains
        if node.is_os? [ 'debian', 'ubuntu', 'gentoo' ], true
          rule_file += "-P INPUT DROP\n" +
                       "-P OUTPUT DROP\n" +
                       "-P FORWARD DROP\n" +
                       "-F\n"
          rule_file += "-F -t nat\n" if ipv4
          rule_file += "-X\n"
  
        elsif node.is_os? [ 'centos', 'scientific' ], true
          rule_file += "*filter\n" +
                       ":INPUT DROP [0:0]\n" +
                       ":FORWARD DROP [0:0]\n" +
                       ":OUTPUT DROP [0:0]\n"
        end

        # allow localhost
        rule_file += "-A INPUT -i lo -j ACCEPT\n"

        # drop invalid packets
        rule_file += "-A INPUT -m state --state INVALID -j DROP\n"

        # allow related packets
        rule_file += "-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT\n"

        # drop tcp packets with the syn bit set if the tcp connection is already established
        rule_file += "-A INPUT -p tcp --tcp-flags SYN SYN -m state --state ESTABLISHED -j DROP\n" # if ipv4

        # drop icmp timestamps
        rule_file += "-A INPUT -p icmp --icmp-type timestamp-request -j DROP\n" if ipv4
        rule_file += "-A INPUT -p icmp --icmp-type timestamp-reply -j DROP\n" if ipv4

        # allow other icmp packets
        rule_file += "-A INPUT -p icmpv6 -j ACCEPT\n" if ipv6
        rule_file += "-A INPUT -p icmp -j ACCEPT\n"

        # open ports
        rules['ports'].each do |rule|
          # if config is something like
          #   ports: 22
          # or 
          #   ports: [ 22, 443, 1000:2000 ]
          # generate a new hash, and set rule['port']
          unless rule.class == Hash
            port = rule
            rule = {}
            rule['port'] = port
          end

          # skip rule for other ipversion than specified
          rule['ip-version'] ||= 0 # default to 0, means both protocols
          next if rule['ip-version'].to_i == 4 and ipv6
          next if rule['ip-version'].to_i == 6 and ipv4

          # convert to string if port is a int
          rule['port'] = rule['port'].to_s if rule['port'].class == Fixnum

          # skip this port if no portnumber is specified
          unless rule['port']
            Dust.print_failed "no port specified: #{rule.inspect}", 2
            next
          end

          # tcp is the default protocol
          rule['protocol'] ||= 'tcp'

          # apply one rule for each port(range)
          rule['port'].each do |port| 
            Dust.print_msg "allowing port #{port}:#{rule['protocol']}", 2
            rule_file += "-A INPUT -p #{rule['protocol']} --dport #{port} "
            if rule['interface']
              print " [dev: #{rule['interface']}]"
              rule_file += "-i #{rule['interface']} " 
            end
            if rule['source']
              print " [source: #{rule['source']}]"
              rule_file += "--source #{rule['source']} "
            end
            rule_file += "-m state --state NEW "
            rule_file += "-j ACCEPT\n"
            Dust.print_ok
          end
        end

        # add custom ipv4 iput rules
        rules['ipv4-custom-input-rules'].each do |rule|
          Dust.print_msg "adding custom ipv4 input rule: #{rule}", 2
          rule_file += "-A INPUT #{rule}\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv6 iput rules
        rules['ipv6-custom-input-rules'].each do |rule|
          Dust.print_msg "adding custom ipv6 input rule: #{rule}", 2
          rule_file += "-A INPUT #{rule}\n"
          Dust.print_ok
        end if ipv6

        # deny the rest
        rule_file += "-A INPUT -p tcp -j REJECT --reject-with tcp-reset\n"
        rule_file += "-A INPUT -j REJECT --reject-with icmp-port-unreachable\n" if ipv4

        # add custom ipv4 prerouting rules
        rules['ipv4-custom-prerouting-rules'].each do |rule|
          Dust.print_msg "adding custom ipv4 prerouting rule: #{rule}", 2
          rule_file += "-A PREROUTING #{rule}\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv6 prerouting rules
        rules['ipv6-custom-prerouting-rules'].each do |rule|
          Dust.print_msg "adding custom ipv6 prerouting rule: #{rule}", 2
          rule_file += "-A PREROUTING #{rule}\n"
          Dust.print_ok
        end if ipv6

        # add custom ipv4 postrouting rules
        rules['ipv4-custom-postrouting-rules'].each do |rule|
          Dust.print_msg "adding custom ipv4 postrouting rule: #{rule}", 2
          rule_file += "-A POSTROUTING #{rule}\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv6 postrouting rules
        rules['ipv6-custom-postrouting-rules'].each do |rule|
          Dust.print_msg "adding custom ipv6 postrouting rule: #{rule}", 2
          rule_file += "-A POSTROUTING #{rule}\n"
          Dust.print_ok
        end if ipv6


        # drop invalid outgoing packets
        rule_file += "-A OUTPUT -m state --state INVALID -j DROP\n"

        # allow related outgoing packets
        rule_file += "-A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT\n"

        # add custom ipv4 output rules
        rules['ipv4-custom-output-rules'].each do |rule|
          Dust.print_msg "adding custom ipv4 outgoing rule: #{rule}", 2
          rule_file += "-A OUTPUT #{rule}\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv6 output rules
        rules['ipv6-custom-output-rules'].each do |rule|
          Dust.print_msg "adding custom ipv6 outgoing rule: #{rule}", 2
          rule_file += "-A OUTPUT #{rule}\n"
          Dust.print_ok
        end if ipv6

        # allow everything out
        rule_file += "-A OUTPUT -j ACCEPT\n"


        # enable packet forwarding
        if rules['forward']
          Dust.print_msg 'enabling ipv4 forwarding', 2
          rule_file += "-A FORWARD -m state --state INVALID -j DROP\n"
          rule_file += "-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT\n"
          rule_file += "-A FORWARD -j ACCEPT\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv4 forward rules
        rules['ipv4-custom-forward-rules'].each do |rule|
          Dust.print_msg "adding custom ipv4 forward rule: #{rule}", 2
          rule_file += "-A FORWARD #{rule}\n"
          Dust.print_ok
        end if ipv4

        # add custom ipv6 forward rules
        rules['ipv6-custom-forward-rules'].each do |rule|
          Dust.print_msg "adding custom ipv6 forward rule: #{rule}", 2
          rule_file += "-A FORWARD #{rule}\n"
          Dust.print_ok
        end if ipv6

        rule_file += "COMMIT\n" if node.is_os? [ 'centos', 'scientific' ], true

        # prepend iptables command on non-centos-like machines
        rule_file = rule_file.map { |s| "#{iptables} #{s}" }.to_s if node.is_os? ['debian', 'ubuntu', 'gentoo'], true

        # set header
	header  = ''
        header  = "#!/bin/sh\n" if node.is_os? ['debian', 'ubuntu', 'gentoo'], true
        header += "# automatically generated by dust\n\n"
        rule_file = header + rule_file

        # set the target file depending on distribution
        target = "/etc/network/if-pre-up.d/#{iptables}" if node.is_os? ['debian', 'ubuntu'], true
        target = "/etc/#{iptables}" if node.is_gentoo? true
        target = "/etc/sysconfig/#{iptables}" if node.is_os? [ 'centos', 'scientific' ], true

        node.write target, rule_file, true

        node.chmod '700', target if node.is_os? ['debian', 'ubuntu', 'gentoo'], true
        node.chmod '600', target if node.is_os? [ 'centos', 'scientific' ], true

        Dust.print_msg 'applying ipv4 rules' if ipv4
        Dust.print_msg 'applying ipv6 rules' if ipv6

        if node.is_os? ['centos', 'scientific'], true
          Dust.print_result node.exec("/etc/init.d/#{iptables} restart")[:exit_code]

        elsif node.is_os? ['debian', 'ubuntu', 'gentoo'], true
          ret = node.exec target
          Dust.print_result( (ret[:exit_code] == 0 and ret[:stdout].empty? and ret[:stderr].empty?) )
        end

        # on gentoo, rules have to be saved using the init script,
        # otherwise they won't get re-applied on next startup
        if node.is_gentoo? true
          Dust.print_msg 'saving ipv4 rules' if ipv4
          Dust.print_msg 'saving ipv6 rules' if ipv6
          Dust.print_result node.exec("/etc/init.d/#{iptables} save")[:exit_code]
        end

        puts
      end
    end
  end
end

