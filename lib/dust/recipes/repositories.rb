module Dust
  class Deploy
    private

    # setup system as proxmox host
    def repositories node, repos
      if node.uses_apt?
        Dust.print_msg 'deleting old repositories'
        node.rm '/etc/apt/sources.list.d/*.list', true
        Dust.print_ok 

        repos.each do |name, repo|
          puts

          # if repo is present but not a hash use defaults
          repo = Hash.new unless repo.class == Hash

          # setting defaults
          repo['url'] ||= 'http://ftp.debian.org/debian/'
          repo['release'] ||= node['lsbdistcodename']
          repo['components'] ||= 'main'

          # the default repository in /etc/apt/sources.list
          if name == 'default'
            Dust.print_msg 'deploying default repository'
            Dust.print_result node.write('/etc/apt/sources.list',
              "deb #{repo['url']} #{repo['release']} #{repo['components']}\n" +
              "deb-src #{repo['url']} #{repo['release']} #{repo['components']}\n\n" +
              "deb http://security.debian.org/ #{repo['release']}/updates #{repo['components']}\n" +
              "deb-src http://security.debian.org/ #{repo['release']}/updates #{repo['components']}\n\n" +
              "deb #{repo['url']} #{repo['release']}-updates #{repo['components']}\n" +
              "deb-src #{repo['url']} #{repo['release']}-updates #{repo['components']}\n", true)
            next
          end

          # add url to sources.list
          Dust.print_msg "adding repository '#{name}' to sources"
          Dust.print_result node.write("/etc/apt/sources.list.d/#{name}.list",
                                       "deb #{repo['url']} #{repo['release']} #{repo['components']}", true)

          # add the repository key
          if repo['key']
            Dust.print_msg "adding #{name} repository key"
            Dust.print_result node.exec("wget -O- '#{repo['key']}' | apt-key add -")[:exit_code]
          end
        end

      elsif node.uses_rpm?
        Dust.print_failed 'rpm not yet supported'

      else
        Dust.print_failed 'os not supported'
      end
    end
  end
end

