module Dust
  class Deploy
    private
    def aliases node, ingredients
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless node.package_installed?('postfix')
      node.scp "#{template_path}/aliases", '/etc/aliases'

      Dust.print_msg 'running newaliases', 1
      Dust.print_result node.exec('newaliases')[:exit_code]
    end
  end
end

