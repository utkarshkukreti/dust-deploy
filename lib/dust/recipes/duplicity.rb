require 'erb'

module Dust
  class Deploy
    private

    # configures and deploy duplicity cronjob
    def duplicity node, scenarios
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # clear all other duplicity cronjobs that might have been deployed earlier
      remove_duplicity_cronjobs node

      # return if config simply says 'remove'
      return if scenarios == 'remove'

      scenarios.each do |scenario, config|
        # if hosts and directory config options are not given, use hostname of this node
        config['hosts'] ||= [ node['hostname'] ]
        config['directory'] ||= "#{node['hostname']}-#{scenario}"

        # check whether backend is specified, skip to next scenario if not
        return Dust.print_failed 'no backend specified.' unless config['backend']

        # check if interval is correct   
        unless [ 'monthly', 'weekly', 'daily', 'hourly' ].include? config['interval']
          return Dust.print_failed "invalid interval: '#{config['interval']}'"
        end

        # check whether we need ncftp
        node.install_package 'ncftp' if config['backend'].include? 'ftp://'

        # add hostkey to known_hosts
        if config['backend'].include? 'scp://' and config['hostkey']
          Dust.print_msg 'checking if ssh key is in known_hosts', 2
          unless Dust.print_result node.exec("grep -q '#{config['hostkey']}' ~/.ssh/known_hosts")[:exit_code] == 0
            node.mkdir '~/.ssh'
            node.append '~/.ssh/known_hosts', config['hostkey']
          end
        end

        # generate path for the cronjob
        cronjob_path = "/etc/cron.#{config['interval']}/duplicity-#{scenario}"

        # adjust and upload cronjob
        template = ERB.new File.read("#{template_path}/cronjob.erb"), nil, '%<>'
        Dust.print_msg "adjusting and deploying cronjob (scenario: #{scenario}, interval: #{config['interval']})"
        node.write cronjob_path, template.result(binding), true
        Dust.print_ok
 
        # making cronjob executeable
        node.chmod '0700', cronjob_path
        puts
      end
    end


    # print duplicity-status
    def duplicity_status node, scenarios

      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      scenarios.each do |scenario, config|

        # if hosts and directory config options are not given, use hostname of this node
        config['hosts'] ||= [ node['hostname'] ]
        config['directory'] ||= "#{node['hostname']}-#{scenario}"

        # check whether backend is specified, skip to next scenario if not
        return Dust.print_failed 'no backend specified.' unless config['backend']

        Dust.print_msg "running collection-status for scenario '#{scenario}'"
        cmd = "nice -n #{config['nice']} duplicity collection-status " +
              "--archive-dir #{config['archive']} " +
              "#{File.join(config['backend'], config['directory'])}"
  
        cmd += " |tail -n3 |head -n1" unless options.long?

        ret = node.exec cmd
        Dust.print_result(ret[:exit_code])

        if options.long?
          Dust.print_msg "#{Dust.black}#{ret[:stdout]}#{Dust.none}", 0
        else
          Dust.print_msg "\t#{Dust.black}#{ret[:stdout].sub(/^\s+([a-zA-Z]+)\s+(\w+\s\w+\s\d+\s\d+:\d+:\d+\s\d+)\s+(\d+)$/, 'Last backup: \1 (\3 sets) on \2')}#{Dust.none}", 0
        end

        puts
      end
    end


    # removes all duplicity cronjobs
    def remove_duplicity_cronjobs node
      Dust.print_msg 'deleting old duplicity cronjobs'
      node.rm '/etc/cron.*/duplicity*', true
      Dust.print_ok
    end
  end

end

