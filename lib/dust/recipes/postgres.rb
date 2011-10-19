require 'erb'

module Dust
  class Deploy
    private
    def postgres node, config
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      if node.is_gentoo?
        return unless node.package_installed? 'postgresql-server'
      else
        return 'os not supported'
      end

      return Dust.print_failed 'no conf-dir specified' unless config['conf-dir']
      return Dust.print_failed 'no data-dir specified' unless config['data-dir']

      deploy_file node, 'postgresql.conf', "#{config['conf-dir']}/postgresql.conf"
      deploy_file node, 'pg_hba.conf', "#{config['conf-dir']}/pg_hba.conf"
      deploy_file node, 'pg_ident.conf', "#{config['conf-dir']}/pg_ident.conf"

      # deploy pacemaker script
      if node.package_installed? 'pacemaker'
        deploy_file node, 'pacemaker.sh', "#{config['conf-dir']}/pacemaker.sh"
        node.chmod '755', "#{config['conf-dir']}/pacemaker.sh"
      end

      # copy recovery.conf to either recovery.conf or recovery.done
      # depending on which file already exists.
      if node.file_exists? "#{config['data-dir']}/recovery.conf", true
        deploy_file node, 'recovery.conf', "#{config['data-dir']}/recovery.conf"
      else
        deploy_file node, 'recovery.conf', "#{config['data-dir']}/recovery.done"
      end

      # deploy certificates to data-dir
      deploy_file node, 'server.crt', "#{config['data-dir']}/server.crt"
      deploy_file node, 'server.key', "#{config['data-dir']}/server.key"

      node.chown config['dbuser'], config['data-dir'] if config['dbuser']
      node.chmod 'u+Xrw,g-rwx,o-rwx', config['data-dir']

      # TODO:
      # reload/restart postgres (--restart for restarting)
      # node.reload_service 'postgresql-9.0'
    end

    def deploy_file node, file, target
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # if file is just a regular file, copy it to sites-available
      if File.exists? "#{template_path}/#{file}"
        node.scp "#{template_path}/#{file}", target

      # if file is an erb template, render it and deploy
      elsif File.exists? "#{template_path}/#{file}.erb"
        Dust.print_msg "adjusting and deploying #{file}"
        template = ERB.new( File.read("#{template_path}/#{file}.erb"), nil, '%<>')
        Dust.print_result node.write(target, template.result(binding), true)

      # file was not found, return
      else
        return Dust.print_failed "file '#{template_path}/#{file}' not found."
      end
    end

  end
end

