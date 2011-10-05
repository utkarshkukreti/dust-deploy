class Deploy::ZabbixAgent < Thor
  namespace :zabbix_agent

  desc "#{namespace}:deploy", "install and configure zabbix-agent"
  def deploy
    servers = invoke 'deploy:start'

    servers.each do | server |
      Dust.print_hostname server

      os = server.discover_os
      os = 'debian' if os == 'ubuntu' # treat ubuntu as debian

      # install zabbix package
      if os == 'debian'
        server.install('zabbix-agent') unless server.package_installed?('zabbix-agent')

        # debsecan is needed for zabbix checks (security updates)
        server.install('debsecan') unless server.package_installed?('debsecan')

      elsif os == 'gentoo'
        server.install('zabbix', "USE=agent") unless server.package_installed?('zabbix')

        # glsa-check (part of gentoolkit) is needed for zabbix checks (security updates)
        server.install('gentoolkit') unless server.package_installed?('gentoolkit')

      else
        print ' - os not supported'
        Dust.print_failed
        next
      end

      # configure server using erb template
      template = ERB.new( File.read("templates/#{self.class.namespace}/zabbix_agentd.conf.erb"), nil, '%<>' )
      print ' - adjusting and deploying zabbix_agentd.conf'
      server.write('/etc/zabbix/zabbix_agentd.conf', template.result(binding), true )
      Dust.print_ok

      # restart using new configuration
      server.restart_service('zabbix-agentd') if os == 'gentoo'
      server.restart_service('zabbix-agent') if  os == 'debian'

      server.disconnect
      puts
    end
  end

  desc "#{namespace}:configure_postgres", "autoconfigure postgres database for zabbix monitoring"
  def configure_postgres
    servers = invoke 'deploy:start', [ 'group' => 'postgres' ]

    servers.each do | server |
      Dust.print_hostname server
      next unless server.is_gentoo?
      next unless server.package_installed?('postgresql-server')

      print ' - add zabbix system user to postgres group'
      Dust.print_result( server.exec('usermod -a -G postgres zabbix')[:exit_code] )

      print ' - checking if zabbix user exists in postgres'
      ret = Dust.print_result( server.exec('psql -U postgres -c ' +
                                             '  "SELECT usename FROM pg_user WHERE usename = \'zabbix\'"' +
                                             '  postgres |grep -q zabbix')[:exit_code] )

      # if user was not found, create him
      unless ret
        print '   - create zabbix user in postgres'
        Dust.print_result( server.exec('createuser -U postgres zabbix -RSD')[:exit_code] )
      end

# TODO: only GRANT is this is a master
      print ' - GRANT zabbix user access to postgres database'
      Dust.print_result( server.exec('psql -U postgres -c "GRANT SELECT ON pg_stat_database TO zabbix" postgres')[:exit_code] )

      # reload postgresql
      server.reload_service('postgresql-9.0')

      server.disconnect
      puts
    end

  end
end
