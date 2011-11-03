module Dust
  class Deploy
    private

    # deploy firewall rules
    def iptables node, config
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # if config is simply set to "true", use defaults
      config = {} unless config.class == Hash

      # setting default config variables (unless already set)
      config['public-ports'] ||= []
      config['backnet-ports'] ||= []
      config['zabbix-server'] ||= ''
      config['ipv4-custom-input-rules'] ||= []
      config['ipv4-custom-prerouting-rules'] ||= []
      config['ipv4-custom-output-rules'] ||= []

      # if *-ports is a single int, convert to string, so .each won't get hickups
      config['public-ports'] = config['public-ports'].to_s if config['public-ports'].class == Fixnum
      config['backnet-ports'] = config['backnet-ports'].to_s if config['backnet-ports'].class == Fixnum

      # if *-ports is an array, map all ints to strings, so split will work
      config['public-ports'].map! { |i| i.to_s } if config['public-ports'].class == Array
      config['backnet-ports'].map! { |i| i.to_s } if config['backnet-ports'].class == Array

      if node.is_os? ['debian', 'ubuntu', 'gentoo'], true
        node.install_package 'iptables'

        target = '/etc/network/if-pre-up.d/iptables' if node.is_os? ['debian', 'ubuntu'], true
        target = '/etc/iptables' if node.is_gentoo? true

        Dust.print_msg 'configuring and deploying firewall'

        # configure node using erb template
        template = ERB.new File.read("#{template_path}/iptables_debian.erb"), nil, '%<>'
        node.write target, template.result(binding), true
        Dust.print_ok

        node.chmod '700', target

        Dust.print_msg 'applying firewall rules'
        ret = node.exec target
        Dust.print_result( (ret[:exit_code] == 0 and ret[:stdout].empty? and ret[:stderr].empty?) )

        if node.is_gentoo? true
          Dust.print_msg 'saving ipv4 rules'
          Dust.print_result node.exec('/etc/init.d/iptables save')[:exit_code]

          Dust.print_msg 'saving ipv6 rules'
          Dust.print_result node.exec('/etc/init.d/ip6tables save')[:exit_code]
        end

      elsif node.is_os? [ 'centos', 'scientific' ], true
        node.install_package 'iptables'
        node.install_package 'iptables-ipv6'

        target = '/etc/sysconfig/iptables'

        Dust.print_msg 'configuring and deploying firewall'

        # configure node using erb template
        template = ERB.new File.read("#{template_path}/iptables_centos.erb"), nil, '%<>'
        node.write target, template.result(binding), true
        Dust.print_ok

        node.chmod '600', target

        Dust.print_msg 'applying ipv4 firewall rules'
        Dust.print_result node.exec('/etc/init.d/iptables restart')[:exit_code]
        # TODO: install ipv6 rules as well (using second template?)
        #Dust.print_msg 'applying ipv6 firewall rules' 
        #Dust.print_result node.exec('/etc/init.d/ip6tables restart')[:exit_code]

      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

