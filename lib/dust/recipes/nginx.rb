require 'erb'

module Dust
  class Deploy
    private
    def nginx node, type
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # abort if nginx cannot be installed
      return unless node.install_package('nginx')

      Dir["#{template_path}/*"].each do |file|
puts file
        #node.scp("#{template_path}/nginx.conf", '/etc/nginx/nginx.conf')
      end


      Dir["#{template_path}/#{type}/sites-enabled/*"].each do |file|

        # render .erb files and write them to servers
        if File.extname(file) == '.erb'
          template = ERB.new File.read(file, nil, '%<>')

          # remote the .erb from filename
          target = File.basename(file).chomp( File.extname(file) )
          node.write "/etc/nginx/sites-available/#{target}", template.result(binding)

        # other files will just be deployed
        else
          node.scp file, "/etc/nginx/sites-enabled#{File.basename file}"
        end
      end

return

      # enable node configuration via symlink
      unless node.file_exists?('/etc/nginx/sites-enabled/proxy')
        Dust.print_msg 'symlinking proxy to sites-enabled', 2
        Dust.print_result( node.exec('cd /etc/nginx/sites-enabled && ln -s ../sites-available/proxy proxy')[:exit_code] )
      end
    end

    def check_config node
      # check configuration and restart nginx
      Dust.print_msg 'checking nginx configuration'
      if node.exec('/etc/init.d/nginx configtest')[:exit_code] == 0
        Dust.print_ok
        node.restart_service('nginx')
      else
        Dust.print_failed
      end
    end
  end
end

