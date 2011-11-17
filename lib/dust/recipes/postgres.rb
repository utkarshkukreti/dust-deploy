require 'erb'

module Dust
  class Deploy
    private
    def postgres node, config
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return Dust.print_failed 'no version specified' unless config['version']

      if node.uses_emerge? true
        return unless node.package_installed? 'postgresql-server'
        config['data-dir'] ||= "/var/lib/postgresql/#{config['version']}/data"
        config['conf-dir'] ||= "/etc/postgresql-#{config['version']}"
        config['archive-dir'] ||= "/var/lib/postgresql/#{config['version']}/archive"
      elsif node.uses_apt? true
        return unless node.package_installed? "postgresql-#{config['version']}"
        config['data-dir'] ||= "/var/lib/postgresql/#{config['version']}/#{config['cluster']}"
        config['conf-dir'] ||= "/etc/postgresql/#{config['version']}/#{config['cluster']}"
        config['archive-dir'] ||= "/var/lib/postgresql/#{config['version']}/#{config['cluster']}-archive"
      else
        return 'os not supported'
      end


      deploy_file 'postgresql.conf', "#{config['conf-dir']}/postgresql.conf", binding
      deploy_file 'pg_hba.conf', "#{config['conf-dir']}/pg_hba.conf", binding
      deploy_file 'pg_ident.conf', "#{config['conf-dir']}/pg_ident.conf", binding

      node.chmod '644', "#{config['conf-dir']}/postgresql.conf"
      node.chmod '644', "#{config['conf-dir']}/pg_hba.conf"
      node.chmod '644', "#{config['conf-dir']}/pg_ident.conf"

      # deploy pacemaker script
      if node.package_installed? 'pacemaker'
        deploy_file 'pacemaker.sh', "#{config['conf-dir']}/pacemaker.sh", binding
        node.chmod '755', "#{config['conf-dir']}/pacemaker.sh"
      end

      # copy recovery.conf to either recovery.conf or recovery.done
      # depending on which file already exists.
      if node.file_exists? "#{config['data-dir']}/recovery.conf", true
        deploy_file 'recovery.conf', "#{config['data-dir']}/recovery.conf", binding
      else
        deploy_file 'recovery.conf', "#{config['data-dir']}/recovery.done", binding
      end

      # deploy certificates to data-dir
      deploy_file 'server.crt', "#{config['data-dir']}/server.crt", binding
      deploy_file 'server.key', "#{config['data-dir']}/server.key", binding

      node.chown config['dbuser'], config['data-dir'] if config['dbuser']
      node.chmod 'u+Xrw,g-rwx,o-rwx', config['data-dir']

      # create archive dir
      node.mkdir config['archive-dir']
      node.chown config['dbuser'], config['archive-dir'] if config['dbuser']
      node.chmod 'u+Xrw,g-rwx,o-rwx', config['archive-dir']

      # TODO:
      # reload/restart postgres (--restart for restarting)
      # node.reload_service "postgresql-#{config['version'}"
    end

    def deploy_file file, target, recipe_binding
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # get node and config from binding
      node = eval 'node', recipe_binding
      config = eval 'config', recipe_binding

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

