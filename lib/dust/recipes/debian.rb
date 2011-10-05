class Deploy::Debian < Thor
  namespace :debian

  desc "#{namespace}:unattended_upgrades", "installs and configures security updates"
  def unattended_upgrades
    servers = invoke 'deploy:start', [ 'group' => 'debian' ]

    servers.each do | server |
      Dust.print_hostname server
      next unless server.is_debian?
      server.install('unattended-upgrades') unless server.package_installed?('unattended-upgrades')
      server.scp("templates/#{self.class.namespace}/02periodic", '/etc/apt/apt.conf.d/02periodic')

      server.disconnect
      puts
    end
  end

  desc "#{namespace}:locale", "configures locale"
  def locale
    servers = invoke 'deploy:start', [ 'group' => 'debian' ]

    servers.each do | server |
      Dust.print_hostname server
      next unless server.is_os?( [ "debian", "ubuntu" ] )
      server.scp("templates/#{self.class.namespace}/locale", '/etc/default/locale')

      server.disconnect
      puts
    end
  end
end

