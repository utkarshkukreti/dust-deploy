module Dust
  class Deploy
    private
    def basic_setup node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # install some basic packages
      Dust.print_msg "installing basic packages\n"

      node.install_package 'screen', false, 2
      node.install_package 'rsync', false, 2
      node.install_package 'psmisc', false, 2 if node.uses_apt? true

      if node.uses_rpm? true
        node.install_package 'vim-enhanced', false, 2
      else
        node.install_package 'vim', false, 2
      end

      if node.uses_apt? true
        node.install_package 'git-core', false, 2
      else
        node.install_package 'git', false, 2
      end

      # deploy basic configuration for root user
      Dust.print_msg "deploying configuration files for root\n", 1
      Dir["#{template_path}/.*"].each do |file|
        next unless File.file?(file)
        node.scp file, "/root/#{File.basename(file)}", false, 2
      end

    end
  end
end

