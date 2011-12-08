require 'erb'

module Dust
  class Deploy
    private
    def nginx node, sites
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      # abort if nginx cannot be installed
      return unless node.install_package('nginx')

      node.scp("#{template_path}/nginx.conf", '/etc/nginx/nginx.conf')

      # remove old sites that may be present
      Dust.print_msg 'deleting old sites in /etc/nginx/sites-*'
      node.rm '/etc/nginx/sites-*/*', true
      Dust.print_ok

      sites.each do |state, site|
        file = "#{template_path}/sites/#{site}"

        # if this site is just a regular file, copy it to sites-available
        if File.exists? file
          node.scp file, "/etc/nginx/sites-available/#{site}"

        # if this site is an erb template, render it and deploy
        elsif File.exists? "#{file}.erb"
          template = ERB.new( File.read("#{file}.erb"), nil, '%<>')
          node.write "/etc/nginx/sites-available/#{site}", template.result(binding)

        # skip to next site if template wasn't found
        else
          Dust.print_failed "couldn't find template for #{site}", 2
          next
        end

        # symlink to sites-enabled if this is listed as an enabled site
        if state == 'sites-enabled'
          Dust.print_msg "enabling #{site}", 2
          Dust.print_result( node.exec("cd /etc/nginx/sites-enabled && ln -s ../sites-available/#{site} #{site}")[:exit_code] )
        end
      end

      # check configuration and restart nginx
      Dust.print_msg 'checking nginx configuration'
      if node.exec('/etc/init.d/nginx configtest')[:exit_code] == 0
        Dust.print_ok
        node.restart_service('nginx') if options.restart?
      else
        Dust.print_failed
      end
    end
  end
end

