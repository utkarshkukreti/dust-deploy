require 'yaml'

module Dust
class Deploy
  private
  def ssh_authorized_keys node, ingredients
    module_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

    # load users and their ssh keys from yaml file
    users = YAML.load_file "#{module_path}/users.yaml"

    # connect to server
    server = Dust::Server.new node
    server.connect

    authorized_keys = Hash.new
    ingredients.each do |remote_user, ssh_users|
      puts " - generating authorized_keys for #{remote_user}"
      authorized_keys = String.new

      # create the authorized_keys hash for this user
      ssh_users.each do |ssh_user|
        print "   - adding user #{users[ssh_user]['name']}"
        users[ssh_user]['keys'].each do |key|
          authorized_keys += "#{key}"
          authorized_keys += " #{users[ssh_user]['name']}" if users[ssh_user]['name']
          authorized_keys += " <#{users[ssh_user]['email']}>" if users[ssh_user]['email']
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
      server.write "~#{remote_user}/.ssh/authorized_keys", authorized_keys

      # check permissions
      server.chown "#{remote_user}:#{remote_user}", "~#{remote_user}/.ssh"
      server.chmod '0644', "~#{remote_user}/.ssh/authorized_keys"


      # remove authorized_keys files for all other users
      if options.cleanup?
        puts ' - deleting other authorized_keys files'
        server.get_system_users(true).each do |user|
          next if users.keys.include? user
          if server.file_exists? "~#{user}/.ssh/authorized_keys", true
            print '  '
            server.rm "~#{user}/.ssh/authorized_keys"
           end
        end
      end

      puts
    end

    server.disconnect
  end
end
end
