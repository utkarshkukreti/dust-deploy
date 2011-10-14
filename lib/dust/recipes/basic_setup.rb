module Dust
  class Deploy
    private
    def basic_setup node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # install some basic packages
      node.install_package 'screen'
      node.install_package 'rsync'
      node.install_package 'psmisc' if node.uses_apt?

      if node.uses_rpm? true
        node.install_package 'vim-enhanced'
      else
        node.install_package 'vim'
      end

      if node.uses_apt? true
        node.install_package 'git-core'
      else
        node.install_package 'git'
      end

      # deploy basic configuration for root user
      Dir["#{template_path}/.*"].each do |file|
        next unless File.file?(file)
        node.scp file, "/root/#{File.basename(file)}"
      end

    end
  end
end

