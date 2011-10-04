class Deploy::Postfix < Thor
  namespace :postfix

  desc "#{namespace}:aliases", "deploy aliases"
  def aliases
    servers = invoke 'deploy:start', [ 'group' => 'postfix' ]

    servers.each do | server |
      puts "#{@@green}#{server.attr['hostname']}#{@@none}:"    
      next unless server.package_installed?('postfix')

      server.scp("templates/#{self.class.namespace}/aliases", '/etc/aliases')
      print ' - running newaliases'
      server.print_result( server.exec('newaliases')[:exit_code] )

      server.disconnect
      puts
    end
  end
end

