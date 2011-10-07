class Deploy::Ssh < Thor
  namespace :ssh

  @@authorized_keys_config = "templates/#{namespace}/authorized_keys.yaml"

  method_options :cleanup => :boolean

  desc "#{namespace}:authorized_keys", "deploy authorized_keys"
  def authorized_keys
    servers = invoke 'deploy:start'

    # load configuration from yaml file
    nodes = YAML.load_file(@@authorized_keys_config)['nodes']

    # get default users
    default_users = nodes.delete('default_users')

    servers.each do |server|
      users = default_users

      nodes.values.each do |node_config|
        users = node_config['users'] if node_config['hosts'].include?(server['hostname'])
      end

      next unless server.connect

      # generate authorized_keys
      users.each do |remote_user, ssh_users|
        puts " - generating authorized_keys for #{remote_user}"
        authorized_keys = String.new
        ssh_users.each do |ssh_user|
          print "   - adding user #{ssh_user['name']}"
          ssh_user['keys'].each do |key|
            authorized_keys += "#{key}"
            authorized_keys += " #{ssh_user['name']}" if ssh_user['name']
            authorized_keys += " <#{ssh_user['email']}>" if ssh_user['email']
            authorized_keys += "\n"
          end
          Dust.print_ok
        end

        # check and create necessary directories
        print " - checking whether ~#{remote_user}/.ssh exists"
        unless Dust.print_result server.exec("test -d ~#{remote_user}/.ssh")[:exit_code]
          print "   - creating ~#{remote_user}/.ssh"
          unless Dust.print_result server.exec("mkdir ~#{remote_user}/.ssh")[:exit_code]
            puts
            next
          end
        end

        # deploy authorized_keys
        server.write("~#{remote_user}/.ssh/authorized_keys", authorized_keys)

        # check permissions
        server.chown("#{remote_user}:#{remote_user}", "~#{remote_user}/.ssh")
        server.chmod('0644', "~#{remote_user}/.ssh/authorized_keys")


        # remove authorized_keys files for all other users
        if options.cleanup?
          puts ' - deleting other authorized_keys files'
          server.get_system_users(true).each do |user|
            next if users.keys.include?(user)
            if server.file_exists?("~#{user}/.ssh/authorized_keys", true)
              print '  '
              server.rm "~#{user}/.ssh/authorized_keys" 
            end
          end
        end

      end

      server.disconnect
      puts
    end
  end
end

