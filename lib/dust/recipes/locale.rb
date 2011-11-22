module Dust
  class Deploy
    private

    # sets the system locale
    def locale node, locale
      if node.uses_apt? true
        Dust.print_msg "setting locale to '#{locale}'"
        node.write '/etc/default/locale', "LANGUAGE=#{locale}\nLANG=#{locale}\nLC_ALL=#{locale}\nLC_CTYPE=#{locale}\n", true
        Dust.print_ok
      elsif node.uses_rpm? true
        Dust.print_msg "setting locale to '#{locale}'"
        node.write '/etc/sysconfig/i18n', "LANG=\"#{locale}\"\nLC_ALL=\"#{locale}\"\nSYSFONT=\"latarcyrheb-sun16\"\n", true
        Dust.print_ok
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

