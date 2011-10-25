module Dust
  class Deploy
    private

    # configures debsecan
    def debsecan node, config
      if node.is_os? ['debian', 'ubuntu'], true
        node.install_package 'debsecan'

        Dust.print_msg 'configuring debsecan'

        # if config is simply set to "true", use defaults
        config = Hash.new unless config.class == Hash

        # setting default config variables (unless already set)
        config['report'] ||= false
        config['mailto'] ||= 'root'
        config['source'] ||= ''

        config_file = String.new

        # configures whether daily reports are sent
        config_file += "# If true, enable daily reports, sent by email.\n" +
                       "REPORT=#{config['report'].to_s}\n\n"
       
        # configures the suite
        config_file += "# For better reporting, specify the correct suite here, using the code\n" +
                       "# name (that is, \"sid\" instead of \"unstable\").\n" +
                       "SUITE=#{node['lsbdistcodename']}\n\n"

        # which user gets the reports?
        config_file += "# Mail address to which reports are sent.\n" +
                       "MAILTO=#{config['mailto']}\n\n"

        # set vulnerability source
        config_file += "# The URL from which vulnerability data is downloaded.  Empty for the\n" +
                       "# built-in default.\n" +
                       "SOURCE=#{config['source']}\n\n"

        node.write '/etc/default/debsecan', config_file, true
        Dust.print_ok
      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

