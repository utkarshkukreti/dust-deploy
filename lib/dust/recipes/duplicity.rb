class Deploy::Duplicity < Thor
  namespace :duplicity

  method_options :backend => :string, :generate_passphrase => :integer, :force => :boolean, # generate_config
                 :enable => :boolean, :disable => :boolean # cronjobs
                 
  @@config_file = "templates/#{namespace}/configuration.yaml"

  desc "#{namespace}:generate_config", 'generates basic configuration.yaml based on servers.yaml'
  def generate_config
    servers = invoke 'deploy:start'

    if File.exists?(@@config_file) and not options.force?
      puts "#{@@config_file} already exists, not overwriting. Use --force"
      return -1
    end

    config_file = File.open(@@config_file, 'w+')

    # get servers, but don't connect
    servers.each connect=false do |server|
      config_file.puts "#{server['hostname']}:"
      config_file.puts "  hostname: #{server['hostname']}"
      config_file.puts "  backend: \"#{options[:backend]}\"" if options[:backend]

      # use pwgen to generate passphrases
      if options[:generate_passphrase]
        passphrase = `pwgen #{options[:generate_passphrase]}`
        config_file.puts "  passphrase: #{passphrase}" 
      end

      config_file.puts
    end

    config_file.close
    puts "config file written to: #{@@config_file}"
  end

  desc "#{namespace}:cronjobs", 'installs duplicity and places cronjobs'
  def cronjobs
    servers = invoke 'deploy:start'

    unless File.exists?(@@config_file)
      puts "config file #{@@config_file} not found."
      return -1
    end

    config_file = YAML.load_file(@@config_file)

    servers.each do | server |
      puts "#{@@green}#{server.attr['hostname']}#{@@none}:"

      # get configuration from yaml file
      print ' - getting configuration'
      scenarios = config_file.select do |title, config|
        config['hosts'].include?(server.attr['hostname'])
      end
      next unless scenarios.empty? ? server.print_result(false) : server.print_result(true)

      server.install('duplicity') unless server.package_installed?('duplicity')
      server.install('ncftp') unless server.package_installed?('ncftp')

      scenarios.each do |title, scenario_config|
        print " - deploying #{title}"

        config = merge_with_defaults(scenario_config, server)

        # check if interval is correct   
        unless [ 'monthly', 'weekly', 'daily', 'hourly' ].include?(config['interval'])
          print "\n   ERROR: invalid interval: '#{config['interval']}'"
          server.print_result false
          next
        end

        # adjust and upload duplicity.include
        template = ERB.new( File.read("templates/#{self.class.namespace}/cronjob.erb"), nil, '%<>' )
        print " - adjusting and deploying cronjob (#{config['interval']})"
        server.write("/etc/cron.#{config['interval']}/duplicity-#{title}", template.result(binding), true )
        server.print_result true

        # if the backup directory is shared, don't enable backup script automatically 
        unless config['shared_dir']
          server.chmod '0700', "/etc/cron.#{config['interval']}/duplicity-#{title}" unless options.disable?
        else
          server.chmod '0700', "/etc/cron.#{config['interval']}/duplicity-#{title}" if options.enable?
          server.print_warning('   - this scenario uses a shared backup dir, thus not enabling cronjob automatically, use --enable')
        end
        server.chmod '0600', "/etc/cron.#{config['interval']}/duplicity-#{title}" if options.disable?
      end

      server.disconnect    
      puts
    end
  end

  desc "#{namespace}:status", 'run duplicity collection-status'
  def status
    servers = invoke 'deploy:start'

    scenarios = YAML.load_file("templates/#{self.class.namespace}/configuration.yaml")

    scenarios.each do |title, scenario_config|

      if scenario_config['hosts'].class == Array
        # join array to string
        hostname = scenario_config['hosts'].join(',')
      else
        hostname = scenario_config['hosts']
      end
        
      servers.select('hostname' => hostname) 

      servers.each do |server|
        config = merge_with_defaults(scenario_config, server)

        next unless config['hosts'].include?(server.attr['hostname'])

        puts "#{@@green}#{server.attr['hostname']}#{@@none}:"
        next unless server.package_installed?('duplicity')

        # if this scenario shares a dir for multiple servers, only query the first one
        if config['shared_dir'] and server.attr['hostname'] != config['hosts'].first
          print " - The #{title} backup scenario uses a shared directory with #{config['hosts'].first}. Not checking again."
          server.print_result(true)
          server.disconnect
          puts
          next
        end

        print " - running collection-status (#{title})"
        ret = server.exec("nice -n #{config['nice']} duplicity collection-status " +
                           "--archive-dir #{config['archive']} " +
                           "#{File.join(config['backend'], config['directory'])} " +
                           "|tail -n3 |head -n1")
        server.print_result(ret[:exit_code])

        puts "\t#{ret[:stdout].sub(/^\s+([a-zA-Z]+)\s+(\w+\s\w+\s\d+\s\d+:\d+:\d+\s\d+)\s+(\d+)$/, 'Last backup: \1 (\3 sets) on \2')}"

        server.disconnect
        puts
      end
    end
  end


  private
  def merge_with_defaults config, server
    shared_dir = config['directory'] ? true : false

    {
      'interval' => 'daily',
      'nice' => 10,
      'keep-n-full' => 5,
      'archive' => '/tmp/duplicity',
      'full-if-older-than' => '7D',
      'include' => [ '/etc/', '/root/', '/var/log/' ],
      'exclude' => [ "'**'" ],
      'shared_dir' => shared_dir,
      'directory' => server.attr['hostname'] # set hostname as default directory on backup server
    }.merge(config)
  end
end

