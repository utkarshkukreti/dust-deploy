module Dust
  class Deploy
    private
    def etc_hosts node, daemon
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless node.package_installed?('dnsmasq')
      node.scp("#{template_path}/hosts", '/etc/hosts')

      # restart dns service
      node.restart_service(daemon)
    end
  end
end

