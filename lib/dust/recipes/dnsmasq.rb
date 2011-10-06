class Deploy::Dnsmasq < Thor
  namespace :dnsmasq

  desc "#{namespace}:hosts", "deploy hosts file"
  def hosts
    servers = invoke 'deploy:start', [ 'group' => 'proxy' ]

    servers.each do | server |
      next unless server.connect
      next unless server.package_installed?('dnsmasq')
      server.scp("templates/#{self.class.namespace}/hosts", '/etc/hosts')
      server.restart_service('dnsmasq')

      server.disconnect
      puts
    end
  end
end

