require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/ssh/proxy/socks5'
  
module Dust
  class Server
    attr_reader :ssh
  
    def initialize attr
      @attr = attr
  
      # store fully qualified domain name
      @attr['fqdn'] = @attr['hostname']
      @attr['fqdn'] += '.' + @attr['domain'] if @attr['domain']
  
      @attr['user'] ||= 'root'
      @attr['port'] ||= 22
      @attr['password'] ||= ''
    end

    def connect 
      Dust.print_hostname @attr['hostname']
      begin
        # connect to proxy if given
        proxy = @attr.has_key?('proxy') ? Net::SSH::Proxy::SOCKS5.new( @attr['proxy'].split(':')[0],
                                                                        @attr['proxy'].split(':')[1] ) : nil
 
        @ssh = Net::SSH.start(@attr['fqdn'], @attr['user'],
                              { :password => @attr['password'],
                                :port => @attr['port'],
                                :proxy => proxy } )
      rescue Exception
        error_message = " - coudln't connect to #{@attr['fqdn']}"
        error_message += " (via socks5 proxy #{@attr['proxy']})" if proxy
        Dust.print_failed error_message
        return false
      end

      # collect system facts using puppets facter
      install_package('facter') unless package_installed?('facter', true)
      @attr.merge! YAML.load( exec('facter -y')[:stdout] )

      true
    end
  
    def disconnect
      @ssh.close
    end
  
    def exec command
      stdout = ""
      stderr = ""
      exit_code = nil
      exit_signal = nil
  
      @ssh.open_channel do |channel|
        channel.exec(command) do |ch, success|
          unless success
            abort "FAILED: couldn't execute command (ssh.channel.exec)"
          end
          channel.on_data do |ch, data|
            stdout += data
          end
  
          channel.on_extended_data do |ch, type, data|
            stderr += data
          end
  
          channel.on_request("exit-status") do |ch, data|
            exit_code = data.read_long
          end
  
          channel.on_request("exit-signal") do |ch, data|
            exit_signal = data.read_long
          end
        end
      end
  
      @ssh.loop
  
      { :stdout => stdout, :stderr => stderr, :exit_code => exit_code, :exit_signal => exit_signal }
    end
  
    def write target, text, quiet=false
      print " - deploying #{File.basename(target)}" unless quiet
      Dust.print_result( exec("cat << EOF > #{target}\n#{text}\nEOF")[:exit_code], quiet )
      restorecon(target, quiet) # restore SELinux labels
    end

    def append target, text, quiet=false
      print " - appending to #{File.basename(target)}" unless quiet
      Dust.print_result( exec("cat << EOF >> #{target}\n#{text}EOF")[:exit_code], quiet )
    end
 
    def scp source, destination, quiet=false
      print " - deploying #{File.basename(source)}" unless quiet
      @ssh.scp.upload!(source, destination)
      Dust.print_result(true, quiet)
      restorecon(destination, quiet) # restore SELinux labels
    end
  
    def symlink source, destination, quiet=false
      print " - deploying #{File.basename(source)}" unless quiet
      Dust.print_result( exec("ln -s #{source} #{destination}")[:exit_code], quiet )
      restorecon(destination, quiet) # restore SELinux labels
    end
  
    def chmod mode, file, quiet=false
      print " - setting mode of #{File.basename(file)} to #{mode}" unless quiet
      Dust.print_result( exec("chmod #{mode} #{file}")[:exit_code], quiet )
    end

    def chown user, file, quiet=false
      print " - setting owner of #{File.basename(file)} to #{user}" unless quiet
      Dust.print_result( exec("chown -R #{user} #{file}")[:exit_code], quiet )
    end

    def rm file, quiet=false
      print " - deleting #{file}" unless quiet
      Dust.print_result( exec("rm -rf #{file}")[:exit_code], quiet)
    end

    def mkdir dir, quiet=false
      print " - creating directory #{dir}" unless quiet
      Dust.print_result( exec("mkdir -p #{dir}")[:exit_code], quiet )
      restorecon(dir, quiet) # restore SELinux labels
    end

    # check if restorecon (selinux) is available
    # if so, run it on "path" recursively
    def restorecon path, quiet=false

      # if restorecon is not installed, just return true
      ret = exec('which restorecon')
      return true unless ret[:exit_code] == 0

      print " - restoring selinux labels for #{path}" unless quiet
      Dust.print_result( exec("#{ret[:stdout].chomp} -R #{path}")[:exit_code], quiet )
    end
 
    def get_system_users quiet=false
      print " - getting all system users" unless quiet
      ret = exec('getent passwd |cut -d: -f1')
      Dust.print_result ret[:exit_code], quiet

      users = Array.new
      ret[:stdout].each do |user|
        users.push user.chomp
      end
      users
    end

    # checks if one of the packages is installed
    def package_installed? packages, quiet=false
      packages = [ packages ] if packages.class == String

      print " - checking if #{packages.join(' or ')} is installed" unless quiet

      packages.each do |package|
        if uses_apt? true
          return Dust.print_result(true, quiet) unless exec("dpkg -s #{package} |grep 'install ok'")[:stdout].empty?
        elsif uses_emerge? true
          return Dust.print_result(true, quiet) unless exec("qlist -I #{package}")[:stdout].empty?
        elsif uses_rpm? true
          return Dust.print_result(true, quiet) if exec("rpm -q #{package}")[:exit_code] == 0
        end
      end

      Dust.print_result(false, quiet)
    end
 
    def install_package package, env="", quiet=false
      return true if package_installed? package, quiet

      print "   - installing #{package}" unless quiet
      if uses_apt? true
        Dust.print_result exec("#{env} aptitude install -y #{package}")[:exit_code], quiet
      elsif uses_emerge? true
        Dust.print_result exec("#{env} emerge #{package}")[:exit_code], quiet
      elsif uses_rpm? true
        Dust.print_result exec("#{env} yum install -y #{package}; rpm -q #{package}")[:exit_code], quiet
      else
        Dust.print_result false, quiet
      end
    end

    def system_update quiet=false
      print " - installing system updates"

      if uses_apt? true
        Dust.print_result exec("aptitude full-upgrade -y")[:exit_code], quiet
      elsif uses_emerge? true
        Dust.print_result exec("emerge -uND @world")[:exit_code], quiet
      elsif uses_rpm? true
        Dust.print_result exec("yum upgrade -y")[:exit_code], quiet
      else
        Dust.print_result false, quiet
      end
    end

    # determining the system packet manager has to be done without facter
    # because it's used to find out whether facter is installed / install facter
    def uses_apt? quiet=false
      print " - determining whether node uses apt" unless quiet
      Dust.print_result exec('test -e /etc/debian_version')[:exit_code] == 0, quiet
    end

    def uses_rpm? quiet=false
      print " - determining whether node uses rpm" unless quiet
      Dust.print_result exec('test -e /etc/redhat-release')[:exit_code] == 0, quiet
    end

    def uses_emerge? quiet=false
      print " - determining whether node uses emerge" unless quiet
      Dust.print_result exec('test -e /etc/gentoo-release')[:exit_code] == 0, quiet
    end
  
    def is_os? os_list, quiet=false
      print " - checking if this machine runs #{os_list.join(' or ')}" unless quiet
      os_list.each do |os|
        return Dust.print_result(true, quiet) if @attr['operatingsystem'].downcase == os.downcase
      end
      Dust.print_result(false, quiet)
    end
  
    def is_debian? quiet=false
      is_os? [ 'debian' ], quiet
    end
  
    def is_ubuntu? quiet=false
      is_os? [ 'ubuntu' ], quiet
    end
  
    def is_gentoo? quiet=false
      is_os? [ 'gentoo' ], quiet
    end
  
    def is_centos? quiet=false
      is_os? [ 'centos' ], quiet
    end
  
    def is_scientific? quiet=false
      is_os? [ 'scientific' ], quiet
    end
  
    def is_executable? file, quiet=false
      print " - checking if #{file} is installed" unless quiet
      Dust.print_result( exec("test -x $(which #{file})")[:exit_code], quiet )
    end
  
    def file_exists? file, quiet=false
      print " - checking if #{file} is installed" unless quiet
      Dust.print_result( exec("test -e #{file}")[:exit_code], quiet )
    end
  
    def restart_service service, quiet=false
      print " - restarting #{service}" unless quiet 
      Dust.print_result( exec("/etc/init.d/#{service} restart")[:exit_code], quiet )
    end
  
    def reload_service service, quiet=false
      print " - reloading #{service}" unless quiet
      Dust.print_result( exec("/etc/init.d/#{service} reload")[:exit_code], quiet )
    end
  
    def qm_list name, quiet=false
      if name
        print " - looking for a vm with name #{name}" unless quiet
        ret = exec("qm list |grep #{name}")
      else
        print " - looking for vms" unless quiet
        ret = exec('qm list |grep -v VMID')
      end 
  
      if Dust.print_result(ret[:exit_code], quiet)
        return "\t#{ret[:stdout].gsub(/\n/, "\n\t")}"
      end
  
      return ''
    end


    private

    def method_missing method, *args, &block
      # make server attributes accessible via server.attribute
      if @attr[method.to_s]
        @attr[method.to_s]
   
      # and as server['attribute']
      elsif @attr[args.first]
        @attr[args.first]

      # default to super
      else
        super
      end
    end

  end
end
