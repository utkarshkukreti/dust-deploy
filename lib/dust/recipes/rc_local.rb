class RcLocal < Thor
  desc 'rc_local:deploy', 'configures custom startup script'
  def deploy node, config, options

    if node.uses_apt? true
      ::Dust.print_msg "configuring custom startup script\n"

      rc = ''
      config.each do |cmd|
        ::Dust.print_msg "adding command: #{cmd}", 2
        rc += "#{cmd}\n"
        ::Dust.print_ok
      end
      rc += "\nexit 0\n"

      node.write '/etc/rc.local', rc
      node.chown 'root:root', '/etc/rc.local'
      node.chmod '755', '/etc/rc.local'
    else
      ::Dust.print_failed 'os not supported'
    end
  end
end

