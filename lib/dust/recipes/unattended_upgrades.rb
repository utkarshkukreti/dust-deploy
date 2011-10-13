module Dust
  class Deploy

    private
    def unattended_upgrades node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless node.is_debian?
      node.install_package 'unattended-upgrades'
      node.scp "#{template_path}/02periodic", '/etc/apt/apt.conf.d/02periodic'
    end
  end
end

