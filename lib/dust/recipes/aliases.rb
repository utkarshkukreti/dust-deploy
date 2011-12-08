class Aliases < Thor
  desc 'aliases:deploy', 'installs email aliases'
  def deploy node, ingredients
    template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

    return unless node.package_installed? 'postfix'
    node.scp "#{template_path}/aliases", '/etc/aliases'

    ::Dust.print_msg 'running newaliases', 1
    ::Dust.print_result node.exec('newaliases')[:exit_code]
  end
end

