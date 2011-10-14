module Dust
  class Deploy
    private

    # sets the system locale
    def locale node, locale
      if node.is_os? ['debian', 'ubuntu'], true
        node.write '/etc/default/locale', "LANGUAGE=#{locale}\nLANG=#{locale}\nLC_ALL=#{locale}\n"
      elsif node.is_os? ['scientific', 'redhat', 'centos'], true
        node.write '/etc/sysconfig/i18n', "LANG=\"#{locale}\"\nLC_ALL=\"#{locale}\"\nSYSFONT=\"latarcyrheb-sun16\"\n"
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

