require 'erb'

module Dust
  class Deploy
    private
    def mysql node, config
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless node.uses_apt?
      node.install_package 'mysql-server'

      Dust.print_msg "configuring mysql\n"

      # defaults
      config['bind_address'] ||= '127.0.0.1'
      config['port'] ||= 3306

      Dust.print_ok "listen on #{config['bind_address']}:#{config['port']}", 2

      config['innodb_file_per_table'] ||= 1

      # allocate 70% of the available ram to mysql
      # but leave max 1gb to system
      unless config['innodb_buffer_pool_size']
        Dust.print_msg 'autoconfiguring innodb buffer size', 2
        node.collect_facts true

        # get system memory (in kb)
        system_mem = convert_size node['memorysize']

        # allocate 70% of the available ram to mysql
        buffer_pool = (system_mem * 0.70).to_i / 1024

        config['innodb_buffer_pool_size'] = "#{buffer_pool}M"
        Dust.print_ok
      end

      Dust.print_ok "setting innodb buffer pool to '#{config['innodb_buffer_pool_size']}'", 2

      template = ERB.new( File.read("#{template_path}/my.cnf.erb"), nil, '%<>')
      node.write '/etc/mysql/my.cnf', template.result(binding)
      node.chmod '644', '/etc/mysql/my.cnf'

      # TODO:
      #node.service_restart 'mysql-server'
      #node.service_reload 'mysql-server'
    end

    # converts string to kilobytes (rounded)
    def convert_size s
      i, unit = s.split(' ')

      case unit.downcase
      when 'kb'
        return i.to_i
      when 'mb'
        return (i.to_f * 1024).to_i
      when 'gb'
        return (i.to_f * 1024 * 1024).to_i
      when 'tb'
        return (i.to_f * 1024 * 1024 * 1024).to_i
      else
        return false
      end
    end

  end
end

