require 'erb'

class Motd < Thor
  desc 'motd:deploy', 'creates message of the day'
  def deploy node, ingredients, options
    template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

    # configure node using erb template
    template = ERB.new File.read("#{template_path}/motd.erb"), nil, '%<>'
    node.write '/etc/motd', template.result(binding)
  end
end
