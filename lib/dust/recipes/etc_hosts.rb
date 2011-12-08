class EtcHosts < Thor
  desc 'etc_hosts:deploy', 'deploys /etc/hosts'
  def deploy node, daemon, options
    template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

    return unless node.package_installed?('dnsmasq')
    node.scp("#{template_path}/hosts", '/etc/hosts')

    # restart dns service
    node.restart_service daemon if options.restart?
  end
end

