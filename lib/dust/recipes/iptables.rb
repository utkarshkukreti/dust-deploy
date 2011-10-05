class Deploy::Iptables < Thor
  namespace :iptables

  desc "#{namespace}:deploy", 'deploy and activate packet filter'
  def deploy
    servers = invoke 'deploy:start'

    servers.each do | server |
      Dust.print_hostname server

      server.install('iptables') unless server.package_installed?('iptables')

      # configure server using erb template
      template = ERB.new( File.read("templates/#{self.class.namespace}/iptables.erb"), nil, '%<>' )
      print ' - adjusting and deploying iptables configration'
      #server.write('/etc/zabbix/zabbix_agentd.conf', template.result(binding), true )
      #server.print_result true

      # apply new rules

      server.disconnect
      puts
    end
  end

  desc "#{namespace}:show", 'show packet filter rules'
  def show
    servers = invoke 'deploy:start'

    servers.each do | server |
      Dust.print_hostname server
      next unless server.package_installed?('iptables')

      server.disconnect
      puts
    end

  end
end
