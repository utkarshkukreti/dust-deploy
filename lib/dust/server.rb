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
      if @attr.has_key?('domain')
        @attr['fqdn'] = "#{@attr['hostname']}.#{@attr['domain']}" 
      else
        @attr['fqdn'] = @attr['hostname']
      end
  
      @attr['user'] = 'root' unless @attr.has_key?('user')
      @attr['port'] = 22 unless @attr.has_key?('port')
      @attr['password'] = '' unless @attr.has_key?('password')
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
        error_message = "coudln't connect to #{@attr['fqdn']}"
        error_message += " (via socks5 proxy #{@attr['proxy']})" if proxy
        Dust.print_failed error_message
        return false
      end 
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
      Dust.print_result( exec("echo '#{text}' > #{target}")[:exit_code], quiet )
    end
  
    def scp source, destination, quiet=false
      print " - deploying #{File.basename(source)}" unless quiet
      @ssh.scp.upload!(source, destination)
      Dust.print_result(true, quiet)
    end
  
    def symlink source, destination, quiet=false
      print " - deploying #{File.basename(source)}" unless quiet
      Dust.print_result( exec("ln -s #{source} #{destination}")[:exit_code], quiet )
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
      print " - deleting #{file}"
      Dust.print_result( exec("rm -rf #{file}")[:exit_code], quiet)
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
 
    def install package, env="", quiet=false
      print "   - installing #{package}" unless quiet
  
      case discover_os(true)
      when "gentoo"
        Dust.print_result( exec("#{env} emerge #{package}")[:exit_code], quiet )
      when "debian"
        Dust.print_result( exec("#{env} aptitude install -y #{package}")[:exit_code], quiet )
      when "ubuntu"
        Dust.print_result( exec("#{env} aptitude install -y #{package}")[:exit_code], quiet )
      when "centos"
        Dust.print_result( exec("#{env} yum install -y #{package}; rpm -q #{package}")[:exit_code], quiet )
      else
        Dust.print_result(false, quiet)
      end
    end

    def system_update quiet=false
      print " - installing system updates"

      case discover_os(true)
      when "gentoo"
        Dust.print_result( exec("emerge -uND @world")[:exit_code], quiet )
      when "debian"
        Dust.print_result( exec("aptitude full-upgrade -y")[:exit_code], quiet )
      when "ubuntu"
        Dust.print_result( exec("aptitude full-upgrade -y")[:exit_code], quiet )
      when "centos"
        Dust.print_result( exec("yum upgrade -y")[:exit_code], quiet )
      else
        Dust.print_result(false, quiet)
      end
    end
  
    def discover_os quiet=false
      print " - determining os: " unless quiet
      os = 'debian' if exec('test -e /etc/debian_version -a ! -e /etc/dpkg/origins/ubuntu')[:exit_code] == 0
      os = 'ubuntu' if exec('test -e /etc/dpkg/origins/ubuntu')[:exit_code] == 0
      os = 'gentoo' if exec('test -e /etc/gentoo-release')[:exit_code] == 0
      os = 'centos' if exec('test -e /etc/redhat-release')[:exit_code] == 0
   
      if os
        print os unless quiet
        Dust.print_result(true, quiet)
      else
        os = ' unknown' unless quiet
        Dust.print_result(false, quiet)
      end
      os
    end
  
    def is_os? os_list, quiet=false
      print " - checking if this machine runs either #{os_list.join(' or ')}" unless quiet
      os_list.each do |os|
        return Dust.print_result(true, quiet) if discover_os(true) == os 
      end
      Dust.print_result(false, quiet)
    end
  
    def is_debian? quiet=false
      print " - checking if this machine runs debian" unless quiet
      Dust.print_result( discover_os(true) == "debian", quiet )
    end
  
    def is_ubuntu? quiet=false
      print " - checking if this machine runs ubuntu" unless quiet
      Dust.print_result( discover_os(true) == "ubuntu", quiet )
    end
  
    def is_gentoo? quiet=false
      print " - checking if this machine runs gentoo" unless quiet
      Dust.print_result( discover_os(true) == "gentoo", quiet )
    end
  
    def is_centos? quiet=false
      print " - checking if this machine runs centos" unless quiet
      Dust.print_result( discover_os(true) == "centos", quiet )
    end
  
    def is_executable? file, quiet=false
      print " - checking if #{file} is installed" unless quiet
      Dust.print_result( exec("test -x $(which #{file})")[:exit_code], quiet )
    end
  
    def file_exists? file, quiet=false
      print " - checking if #{file} is installed" unless quiet
      Dust.print_result( exec("test -e #{file}")[:exit_code], quiet )
    end
  
    # checks if one of the packages is installed
    def package_installed? packages, quiet=false
      packages = [ packages ] if packages.class == String
  
      print " - checking if #{packages.join(' or ')} is installed" unless quiet
  
      os = discover_os(true)
      packages.each do |package|
        case os
        when "gentoo"
          return Dust.print_result(true, quiet) unless exec("qlist -I #{package}")[:stdout].empty?
        when "debian"
          return Dust.print_result(true, quiet) unless exec("dpkg -s #{package} |grep 'install ok'")[:stdout].empty?
        when "ubuntu"
          return Dust.print_result(true, quiet) unless exec("dpkg -s #{package} |grep 'install ok'")[:stdout].empty?
        when "centos"
          return Dust.print_result(true, quiet) if exec("rpm -q #{package}")[:exit_code] == 0
        end
      end
  
      Dust.print_result(false, quiet)
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
