module Dust
  class Deploy
    private

    # sets the system locale
    def locale node, locale
      if node.is_os? ['debian', 'ubuntu'], true
        Dust.print_msg "setting locale to '#{locale}'"
        node.write '/etc/default/locale', "LANGUAGE=#{locale}\nLANG=#{locale}\nLC_ALL=#{locale}\n", true
        Dust.print_ok
      elsif node.is_os? ['scientific', 'redhat', 'centos'], true
        Dust.print_msg "setting locale to '#{locale}'"
        node.write '/etc/sysconfig/i18n', "LANG=\"#{locale}\"\nLC_ALL=\"#{locale}\"\nSYSFONT=\"latarcyrheb-sun16\"\n", true
        Dust.print_ok
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

