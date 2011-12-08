class MemoryLimit < Thor
  desc 'memory_limit:deploy', 'sets up system wide memory limit per process'
  def deploy node, ingredients, options
    template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

    node.collect_facts

    # get system memory (in kb)
    system_mem = ::Dust.convert_size node['memorysize']

    # don't allow a process to use more than 90% of the system memory
    max_mem = (system_mem * 0.9).to_i

    # if the remaining 10% are more than 512mb, use system_mem - 512mb as max instead
    threshold = ::Dust.convert_size '512 MB'
    max_mem = system_mem - threshold if max_mem > threshold

    ::Dust.print_msg "setting max memory for a process to #{max_mem} kb"
    node.write '/etc/security/limits.d/00-memory-limit', "*          hard    as        #{max_mem}", true
    ::Dust.print_ok

  end
end
