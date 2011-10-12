require 'erb'

class Deploy::Nginx < Thor
  namespace :nginx

  desc "#{namespace}:proxy", "install and configure nginx as a reverse proxy"
  def proxy
    servers = invoke 'deploy:start', [ 'group' => 'proxy' ]

    servers.each do | server |
      next unless server.connect

      deploy_config server, 'proxy'
      check_config server

      server.disconnect
      puts
    end
  end

  desc "#{namespace}:rails", "install and configure nginx as a rails server"
  def rails
    servers = invoke 'deploy:start', [ 'group' => 'rails' ]

    servers.each do | server |
      next unless server.connect

      deploy_config server, 'rails'
      check_config server

      server.disconnect
      puts
    end
  end


  private
  def deploy_config server, type
    next unless server.is_debian?
    next unless server.install_package('nginx')

    server.scp("templates/#{self.class.namespace}/#{type}/nginx.conf", '/etc/nginx/nginx.conf')
    server.scp("templates/#{self.class.namespace}/#{type}/flinc", '/etc/nginx/sites-available/flinc')

    # render proxy according to template
    template = ERB.new( File.read("templates/#{self.class.namespace}/#{type}/proxy.erb"), nil, '%<>' )
    print ' - writing proxy according to template'
    server.write('/etc/nginx/sites-available/proxy', template.result(binding), true )
    Dust.print_ok

    # enable server configuration via symlink
    unless server.file_exists?('/etc/nginx/sites-enabled/proxy')
      print '   - symlinking proxy to sites-enabled'
      Dust.print_result( server.exec('cd /etc/nginx/sites-enabled && ln -s ../sites-available/proxy proxy')[:exit_code] )
    end
  end

  def check_config server
    # check configuration and restart nginx
    print ' - checking nginx configuration'
    if server.exec('/etc/init.d/nginx configtest')[:exit_code] == 0
      Dust.print_ok
      server.restart_service('nginx')
    else
      Dust.print_failed
    end
  end
end

