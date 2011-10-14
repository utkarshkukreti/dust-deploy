module Dust
  class Deploy
    private

    # sets the system locale
    def locale node, locale
      if node['os'] == 'debian' or node['os'] == 'ubuntu'
        node.write '/etc/default/locale', "LANGUAGE=#{locale}\nLANG=#{locale}\nLC_ALL=#{locale}\n"
      elsif node['os'] == 'centos'
        node.write '/etc/sysconfig/i18n', "LANG=\"#{locale}\"\nLC_ALL=\"#{locale}\"\nSYSFONT=\"latarcyrheb-sun16\"\n"
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

