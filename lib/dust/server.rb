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
  
    def write target, text, quiet=false, indent=1
      Dust.print_msg("deploying #{File.basename(target)}", indent) unless quiet

      # escape $ signs and \ at the end of line
      text.gsub!('$','\$')
      text.gsub!(/\\$/, '\\\\\\')

      if exec("cat << EOF > #{target}\n#{text}\nEOF")[:exit_code] != 0
        return Dust.print_result(false, quiet)
      end

      Dust.print_ok unless quiet
      restorecon(target, quiet, indent) # restore SELinux labels
    end

    def append target, text, quiet=false, indent=1
      Dust.print_msg("appending to #{File.basename(target)}", indent) unless quiet
      Dust.print_result( exec("cat << EOF >> #{target}\n#{text}\nEOF")[:exit_code], quiet )
    end
 
    def scp source, destination, quiet=false, indent=1
      Dust.print_msg("deploying #{File.basename(source)}", indent) unless quiet
      @ssh.scp.upload!(source, destination)
      Dust.print_result(true, quiet)
      restorecon(destination, quiet, indent) # restore SELinux labels
    end
  
    def symlink source, destination, quiet=false, indent=1
      Dust.print_msg("symlinking #{File.basename(source)} to '#{destination}'", indent) unless quiet
      if exec("ln -s #{source} #{destination}")[:exit_code] != 0
        return Dust.print_result(false, quiet)
      end

      Dust.print_ok unless quiet
      restorecon(destination, quiet, indent) # restore SELinux labels
    end
  
    def chmod mode, file, quiet=false, indent=1
      Dust.print_msg("setting mode of #{File.basename(file)} to #{mode}", indent) unless quiet
      Dust.print_result( exec("chmod -R #{mode} #{file}")[:exit_code], quiet )
    end

    def chown user, file, quiet=false, indent=1
      Dust.print_msg("setting owner of #{File.basename(file)} to #{user}", indent) unless quiet
      Dust.print_result( exec("chown -R #{user} #{file}")[:exit_code], quiet )
    end

    def rm file, quiet=false, indent=1
      Dust.print_msg("deleting #{file}", indent) unless quiet
      Dust.print_result( exec("rm -rf #{file}")[:exit_code], quiet)
    end

    def mkdir dir, quiet=false, indent=1
      return true if dir_exists? dir, true
      Dust.print_msg("creating directory #{dir}", indent) unless quiet
      if exec("mkdir -p #{dir}")[:exit_code] != 0
        return Dust.print_result(false, quiet)
      end

      Dust.print_ok unless quiet
      restorecon(dir, quiet, indent) # restore SELinux labels
    end

    # check if restorecon (selinux) is available
    # if so, run it on "path" recursively
    def restorecon path, quiet=false, indent=1

      # if restorecon is not installed, just return true
      ret = exec('which restorecon')
      return true unless ret[:exit_code] == 0

      Dust.print_msg("restoring selinux labels for #{path}", indent) unless quiet
      Dust.print_result( exec("#{ret[:stdout].chomp} -R #{path}")[:exit_code], quiet )
    end
 
    def get_system_users quiet=false
      Dust.print_msg("getting all system users", indent) unless quiet
      ret = exec('getent passwd |cut -d: -f1')
      Dust.print_result ret[:exit_code]

      users = Array.new
      ret[:stdout].each do |user|
        users.push user.chomp
      end
      users
    end

    # checks if one of the packages is installed
    def package_installed? packages, quiet=false, indent=1
      packages = [ packages ] if packages.class == String

      Dust.print_msg("checking if #{packages.join(' or ')} is installed", indent) unless quiet

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
 
    def install_package package, quiet=false, indent=1, env=""
      return true if package_installed? package, quiet, indent

      Dust.print_msg("installing #{package}", indent + 1) unless quiet
      if uses_apt? true
        Dust.print_result exec("DEBIAN_FRONTEND=noninteractive aptitude install -y #{package}")[:exit_code], quiet
      elsif uses_emerge? true
        Dust.print_result exec("#{env} emerge #{package}")[:exit_code], quiet
      elsif uses_rpm? true
        Dust.print_result exec("yum install -y #{package}; rpm -q #{package}")[:exit_code], quiet
      else
        Dust.print_result false, quiet
      end
    end

    def update_repos quiet=false, indent=1
      Dust.print_msg('updating system repositories', indent) unless quiet
      if uses_apt? true
        Dust.print_result exec('DEBIAN_FRONTEND=noninteractive aptitude update')[:exit_code], quiet
      elsif uses_emerge? true
        Dust.print_result exec('emerge --sync')[:exit_code], quiet
      elsif uses_rpm? true
        Dust.print_result exec('yum check-update')[:exit_code], quiet
      else
        Dust.print_result false, quiet
      end

    end

    def system_update quiet=false, indent=1
      Dust.print_msg('installing system updates', indent) unless quiet

      if uses_apt? true
        Dust.print_result exec('DEBIAN_FRONTEND=noninteractive aptitude full-upgrade -y')[:exit_code], quiet
      elsif uses_emerge? true
        Dust.print_result exec('emerge -uND @world')[:exit_code], quiet
      elsif uses_rpm? true
        Dust.print_result exec('yum upgrade -y')[:exit_code], quiet
      else
        Dust.print_result false, quiet
      end
    end

    # determining the system packet manager has to be done without facter
    # because it's used to find out whether facter is installed / install facter
    def uses_apt? quiet=false, indent=1
      Dust.print_msg("determining whether node uses apt", indent) unless quiet
      Dust.print_result exec('test -e /etc/debian_version')[:exit_code] == 0, quiet
    end

    def uses_rpm? quiet=false, indent=1
      Dust.print_msg("determining whether node uses rpm", indent) unless quiet
      Dust.print_result exec('test -e /etc/redhat-release')[:exit_code] == 0, quiet
    end

    def uses_emerge? quiet=false, indent=1
      Dust.print_msg("determining whether node uses emerge", indent) unless quiet
      Dust.print_result exec('test -e /etc/gentoo-release')[:exit_code] == 0, quiet
    end
  
    def is_os? os_list, quiet=false, indent=1
      Dust.print_msg("checking if this machine runs #{os_list.join(' or ')}", indent) unless quiet
      os_list.each do |os|
        return Dust.print_result(true, quiet) if @attr['operatingsystem'].downcase == os.downcase
      end
      Dust.print_result(false, quiet)
    end
  
    def is_debian? quiet=false, indent=1
      is_os? [ 'debian' ], quiet, indent
    end
  
    def is_ubuntu? quiet=false, indent=1
      is_os? [ 'ubuntu' ], quiet, indent
    end
  
    def is_gentoo? quiet=false, indent=1
      is_os? [ 'gentoo' ], quiet, indent
    end
  
    def is_centos? quiet=false, indent=1
      is_os? [ 'centos' ], quiet, indent
    end
  
    def is_scientific? quiet=false, indent=1
      is_os? [ 'scientific' ], quiet, indent
    end
  
    def is_executable? file, quiet=false, indent=1
      Dust.print_msg("checking if file #{file} exists and is executeable", indent) unless quiet
      Dust.print_result( exec("test -x $(which #{file})")[:exit_code], quiet )
    end
  
    def file_exists? file, quiet=false, indent=1
      Dust.print_msg("checking if file #{file} exists", indent) unless quiet
      Dust.print_result( exec("test -e #{file}")[:exit_code], quiet )
    end

    def dir_exists? dir, quiet=false, indent=1
      Dust.print_msg("checking if directory #{dir} exists", indent) unless quiet
      Dust.print_result( exec("test -d #{dir}")[:exit_code], quiet )
    end
  
    def restart_service service, quiet=false, indent=1
      Dust.print_msg("restarting #{service}", indent) unless quiet 
      Dust.print_result( exec("/etc/init.d/#{service} restart")[:exit_code], quiet )
    end
  
    def reload_service service, quiet=false, indent=1
      Dust.print_msg("reloading #{service}", indent) unless quiet
      Dust.print_result( exec("/etc/init.d/#{service} reload")[:exit_code], quiet )
    end
  
    def qm_list name, quiet=false, indent=1
      if name
        Dust.print_msg("looking for a vm with name #{name}", indent) unless quiet
        ret = exec("qm list |grep #{name}")
      else
        Dust.print_msg("looking for vms", indent) unless quiet
        ret = exec('qm list |grep -v VMID')
      end 
  
      if Dust.print_result(ret[:exit_code], quiet)
        return "\t#{ret[:stdout].gsub(/\n/, "\n\t")}"
      end
  
      return ''
    end

    # check whether a user exists on this node
    def user_exists? user, quiet=false, indent=1
      Dust.print_msg "checking if user #{user} exists", indent unless quiet
      Dust.print_result( exec("id #{user}")[:exit_code], quiet )
    end

    # create a user
    def create_user user, home=nil, shell=nil, quiet=false, indent=1
      return true if user_exists? user, quiet, indent

      Dust.print_msg "creating user #{user}", indent + 1 unless quiet
      cmd = "useradd #{user} -m"
      cmd += " -d #{home}" if home
      cmd += " -s #{home}" if shell
      Dust.print_result( exec(cmd)[:exit_code], quiet ) 
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
