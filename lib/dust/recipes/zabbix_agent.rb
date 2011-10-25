require 'erb'

module Dust
  class Deploy
    private
    def zabbix_agent node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless install_zabbix node

      # configure node using erb template
      template = ERB.new File.read("#{template_path}/zabbix_agentd.conf.erb"), nil, '%<>'
      Dust.print_msg 'adjusting and deploying zabbix_agentd.conf'
      node.write '/etc/zabbix/zabbix_agentd.conf', template.result(binding), true
      Dust.print_ok
      
      # restart using new configuration
      node.restart_service('zabbix-agent') if node.is_os? ['debian', 'ubuntu', 'centos'], true
      node.restart_service('zabbix-agentd') if node.is_gentoo? true
    end

    # installs zabbix and its dependencies
    def install_zabbix node

      if node.uses_apt? true
        return false unless node.install_package('zabbix-agent')

        # debsecan is needed for zabbix checks (security updates)
        return false unless node.install_package('debsecan')

      elsif node.uses_emerge? true
        return false unless node.install_package('zabbix', false, 1, "USE=agent")

        # glsa-check (part of gentoolkit) is needed for zabbix checks (security updates)
        return false unless node.install_package('gentoolkit')

      elsif node.uses_rpm? true
        return false unless node.inspall_package('zabbix-agent')

      else
        Dust.print_msg 'os not supported'
        Dust.print_failed
        return false
      end

      true
    end
  end


  def configure_postgres

      next unless node.is_gentoo?
      next unless node.package_installed?('postgresql-node')

      Dust.print_msg 'add zabbix system user to postgres group'
      Dust.print_result( node.exec('usermod -a -G postgres zabbix')[:exit_code] )

      Dust.print_msg 'checking if zabbix user exists in postgres'
      ret = Dust.print_result( node.exec('psql -U postgres -c ' +
                                             '  "SELECT usename FROM pg_user WHERE usename = \'zabbix\'"' +
                                             '  postgres |grep -q zabbix')[:exit_code] )

      # if user was not found, create him
      unless ret
        Dust.print_msg 'create zabbix user in postgres', 2
        Dust.print_result( node.exec('createuser -U postgres zabbix -RSD')[:exit_code] )
      end

# TODO: only GRANT is this is a master
      Dust.print_msg 'GRANT zabbix user access to postgres database'
      Dust.print_result( node.exec('psql -U postgres -c "GRANT SELECT ON pg_stat_database TO zabbix" postgres')[:exit_code] )

      # reload postgresql
      node.reload_service('postgresql-9.0')

      node.disconnect
      puts
  end
end
