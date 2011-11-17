module Dust
  class Deploy
    private

    # configures rc_local
    def rc_local node, config
      if node.is_os? [ 'debian', 'ubuntu' ], true
        Dust.print_msg "configuring custom startup script\n"

        rc = ''
        config.each do |cmd|
          Dust.print_msg "adding command: #{cmd}", 2
          rc += "#{cmd}\n"
          Dust.print_ok
        end
        rc += "\nexit 0\n"

        node.write '/etc/rc.local', rc
        node.chown 'root:root', '/etc/rc.local'
        node.chmod '755', '/etc/rc.local'
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

