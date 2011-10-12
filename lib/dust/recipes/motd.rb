require 'erb'

class Deploy::Motd < Thor
  namespace :motd

  desc "#{namespace}:deploy", 'deploys message of the day'
  def deploy
    servers = invoke 'deploy:start'

    servers.each do | server |
      next unless server.connect

      # configure server using erb template
      template = ERB.new( File.read("templates/#{self.class.namespace}/motd.erb"), nil, '%<>' )
      print ' - adjusting and deploying /etc/motd'
      print ' (including the awesome warning cow)' if server['environment'] == 'production'
      server.write('/etc/motd', template.result(binding), true )
      Dust.print_ok

      server.disconnect
      puts
    end
  end

  desc "#{namespace}:show", 'have a look at your message of the day'
  def show
    server = invoke('deploy:start').first

    template = ERB.new( File.read("templates/#{self.class.namespace}/motd.erb"), nil, '%<>' )
    puts template.result(binding)
  end
end
