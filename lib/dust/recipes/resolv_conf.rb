class ResolvConf < Thor
  desc 'resolv_conf:deploy', 'configures /etc/resolv.conf'
  def deploy node, config, options
    ::Dust.print_msg "configuring resolv.conf\n"

    # if config is just true, create empty hash and use defaults
    config = {} unless config.class == Hash

    # setting default config variables (unless already set)
    config['nameservers'] ||= [ '208.67.222.222', '208.67.220.220' ] # opendns

    config_file = ''

    # configures whether daily reports are sent
    if config['search']
      ::Dust.print_msg "adding search #{config['search']}", 2
      config_file += "search #{config['search']}\n"
      ::Dust.print_ok
    end

    if config['domain']
      ::Dust.print_msg "adding domain #{config['domain']}", 2
      config_file += "domain #{config['domain']}\n"
      ::Dust.print_ok
    end

    if config['options']
      ::Dust.print_msg "adding options #{config['options']}", 2
      config_file += "options #{config['options']}\n"
      ::Dust.print_ok
    end

    config['nameservers'].each do |nameserver|
      ::Dust.print_msg "adding nameserver #{nameserver}", 2
      config_file += "nameserver #{nameserver}\n"
      ::Dust.print_ok
    end
 
    node.write '/etc/resolv.conf', config_file
  end
end

