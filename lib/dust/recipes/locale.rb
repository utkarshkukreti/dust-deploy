module Dust
  class Deploy
    private

    # sets the system locale
    def locale node, locale
      return unless node['os'] == 'debian' or node['os'] == 'ubuntu'
      node.write '/etc/default/locale', "LANGUAGE=#{locale}\nLANG=#{locale}\nLC_ALL=#{locale}\n"
    end
  end
end

