module Dust
  class Deploy
    private

    # sets the system locale
    def pacemaker node, locale
      template_path = "./templates/#{ File.basename(__FILE__).chomp( File.extname(__FILE__) ) }"

      return unless node.package_installed? 'pacemaker'
      return unless node.package_installed? 'postgresql-server'

      node.scp "#{template_path}/pacemaker.sh", '/var/lib/postgresql/pacemaker.sh'
    end
  end
end

