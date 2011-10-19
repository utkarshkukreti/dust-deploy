require 'yaml'

module Dust
  class Deploy
    private
    def ssh_authorized_keys node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # load users and their ssh keys from yaml file
      users = YAML.load_file "#{template_path}/users.yaml"

      authorized_keys = Hash.new
      ingredients.each do |remote_user, ssh_users|
        Dust.print_msg "generating authorized_keys for #{remote_user}\n"
        authorized_keys = String.new

        # create the authorized_keys hash for this user
        ssh_users.each do |ssh_user|
          Dust.print_msg "adding user #{users[ssh_user]['name']}", 2
          users[ssh_user]['keys'].each do |key|
            authorized_keys += "#{key}"
            authorized_keys += " #{users[ssh_user]['name']}" if users[ssh_user]['name']
            authorized_keys += " <#{users[ssh_user]['email']}>" if users[ssh_user]['email']
            authorized_keys += "\n"
          end

          Dust.print_ok
        end

        # check and create necessary directories
        next unless node.mkdir("~#{remote_user}/.ssh")

        # deploy authorized_keys
        next unless node.write "~#{remote_user}/.ssh/authorized_keys", authorized_keys

        # check permissions
        node.chown "#{remote_user}:#{remote_user}", "~#{remote_user}/.ssh"
        node.chmod '0644', "~#{remote_user}/.ssh/authorized_keys"


        # TODO: add this option
        # remove authorized_keys files for all other users
        if options.cleanup?
          Dust.print_msg "deleting other authorized_keys files\n"
          node.get_system_users(true).each do |user|
            next if users.keys.include? user
            if node.file_exists? "~#{user}/.ssh/authorized_keys", true
              node.rm "~#{user}/.ssh/authorized_keys", 2
             end
          end
        end

        puts
      end
    end
  end
end
