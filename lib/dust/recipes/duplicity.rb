require 'erb'

module Dust
  class Deploy
    private

    # sets the system locale
    def duplicity node, config
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # if the config simply sais "remove" then remove all duplicity cronjobs
      return remove_duplicity_cronjobs node if config == 'remove'

      # if hosts and directory config options are not given, use hostname of this node
      config['hosts'] ||= [ node['hostname'] ]
      config['directory'] ||= node['hostname']

      # check whether backend is specified, skip to next scenario if not
      return Dust.print_failed 'no backend specified.' unless config['backend']

      # check if interval is correct   
      unless [ 'monthly', 'weekly', 'daily', 'hourly' ].include? config['interval']
        return Dust.print_failed "invalid interval: '#{config['interval']}'"
      end

      # clear all other duplicity cronjobs that might have been deployed earlier
      remove_duplicity_cronjobs node 

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
      cronjob_path = "/etc/cron.#{config['interval']}/duplicity"
      cronjob_path += "-#{config['title']}" if config['title']

      # adjust and upload cronjob
      template = ERB.new File.read("#{template_path}/cronjob.erb"), nil, '%<>'
      Dust.print_msg "adjusting and deploying cronjob (interval: #{config['interval']})", 2
      node.write cronjob_path, template.result(binding), true
      Dust.print_ok

      # making cronjob executeable
      node.chmod '0700', cronjob_path
    end

    # removes all duplicity cronjobs
    def remove_duplicity_cronjobs node
      Dust.print_msg 'deleting old duplicity cronjobs'
      node.rm '/etc/cron.*/duplicity*', true
      Dust.print_ok
    end
  end

end

