class Deploy::Update < Thor
  namespace :update

  desc "#{namespace}:system", "install updates for all packages installed"
  def system
    servers = invoke 'deploy:start'

    servers.each do | server |
      next unless server.connect
      server.system_update
      server.disconnect
      puts
    end
  end

end
