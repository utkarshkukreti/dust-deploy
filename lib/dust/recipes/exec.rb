class Deploy::Exec < Thor
  namespace :exec

  method_options :command => :string

  desc "#{namespace}:cmd --command CMD", "runs command on all hosts"
  def cmd
    servers = invoke 'deploy:start'

    exit unless options[:command]

    servers.each do | server |
      next unless server.connect

      print " - running command: #{options[:command]}"
      ret = server.exec options[:command]
      Dust.print_result ret[:exit_code]

      puts ret[:stdout].chomp if ret[:stdout].length
      puts ret[:stderr].chomp if ret[:stderr].length

      server.disconnect
    end
  end
end

