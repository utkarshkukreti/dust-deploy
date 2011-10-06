class Deploy::Pacemaker< Thor
  namespace :pacemaker

  desc "#{namespace}:postgres", "deploys postgres pacemaker script"
  def postgres
    servers = invoke 'deploy:start', [ 'group' => 'postgres' ]

    servers.each do | server |
      next unless server.connect
      next unless server.package_installed?('pacemaker')
      next unless server.package_installed?('postgresql-server')

      server.scp("templates/#{self.class.namespace}/pacemaker.sh", '/var/lib/postgresql/pacemaker.sh')

      server.disconnect
      puts
    end
  end
end

