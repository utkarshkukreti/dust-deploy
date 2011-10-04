require 'dust/version'
require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require 'net/ssh/proxy/socks5'
require 'yaml'


# colors for terminal
@@red   = "\033[1;31m"
@@blue   = "\033[1;34m"
@@green  = "\033[1;32m"
@@yellow = "\033[1;33m"
@@none   = "\033[0m"

$stdout.sync = true # autoflush


module Dust
  class Dust
    attr_reader :all, :selected,
                :proxy

    def initialize yaml
      @all = YAML.load_file(yaml)

      # select all servers by default
      @selected = select('group' => 'all')
    end

    def socks5 proxy={}
      if proxy.class == Hash
        host = proxy[:host] ? proxy[:host] : 'localhost'
        port = proxy[:port] ? proxy[:port] : 1080
        @proxy = "#{host}:#{port}"
      elsif proxy.class == String
        @proxy = proxy
      else
        puts "setting proxy failed."
        return false
      end
    end

    def select filter
      # store group and remove group from filter hash
      # default to 'all' if no group is given
      group = filter.delete('group')
      group = 'all' unless group

      # select wanted group
      if @all.has_key?(group)
        @selected = @all[group].values
      else
        puts "server group '#{group}' not found."
        @selected.reject! { |x| true } # delete all entries
      end

      # remove items if other filter arguments don't match
      filter.each do |k, v|
        next unless v # skip empty filters

        # allow multiple filters of the same type, divided by ','
        # e.g. --filter environment:staging,production
        @selected.reject! { |s| !v.split(',').include? s[k] }
      end

      if @selected.empty?
        puts "no hosts found matching selection"
        return false
      end

      @selected
    end

    def each &block
      @selected.each do |server|
        begin
          # set global proxy (proxy given in yaml file will be overwritten)
          server['proxy'] = @proxy if @proxy
          s = Server.new(server)
        rescue NameError
          puts "#{@@red}ERROR:#{@@none} couldn't connect to #{server['hostname']}!\n\n"
          next
        end

        yield s
      end
    end

    def first
      server = @selected.first
      begin
        # set global proxy (proxy given in yaml file will be overwritten)
        server['proxy'] = @proxy if @proxy
        s = Server.new(server)
      rescue NameError
        puts "#{@@red}ERROR:#{@@none} couldn't connect to #{server['hostname']}!\n\n"
      end
    end
  end

class Server
  attr_reader :attr, :ssh

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

    # connect to proxy if given
    @proxy = @attr.has_key?('proxy') ? Net::SSH::Proxy::SOCKS5.new( @attr['proxy'].split(':')[0],
                                                                    @attr['proxy'].split(':')[1] ) : nil

    @ssh = Net::SSH.start(@attr['fqdn'], @attr['user'], {
                            :password => @attr['password'],
                            :port => @attr['port'],
                            :proxy => @proxy } )
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
    Net::SFTP.start(@attr['fqdn'], @attr['user'], { 
                      :password => @attr['password'],
                      :port => @attr['port'],
                      :proxy => @proxy } ) do |sftp|

      sftp.file.open(target, 'w') do |f|
        f.puts text
      end
    end
    print_result(true, quiet)
  end

  def scp source, destination, quiet=false
    print " - deploying #{File.basename(source)}" unless quiet
    @ssh.scp.upload!(source, destination)
    print_result(true, quiet)
  end

  def symlink source, destination, quiet=false
    print " - deploying #{File.basename(source)}" unless quiet
    print_result( exec("ln -s #{source} #{destination}")[:exit_code], quiet )
  end

  def chmod mode, file, quiet=false
    print " - setting mode of #{File.basename(file)} to #{mode}" unless quiet
    print_result( exec("chmod #{mode} #{file}")[:exit_code], quiet )
  end

  def install package, env="", quiet=false
    print "   - installing #{package}" unless quiet

    case discover_os(true)
    when "gentoo"
      print_result( exec("#{env} emerge #{package}")[:exit_code], quiet )
    when "debian"
      print_result( exec("#{env} aptitude install -y #{package}")[:exit_code], quiet )
    when "centos"
      print_result( exec("#{env} yum install -y #{package}")[:exit_code], quiet )
    else
      print_result(false, quiet)
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
      print_result(true, quiet)
    else
      os = ' unknown' unless quiet
      print_result(false, quiet)
    end
    os
  end

  def is_os? os_list, quiet=false
    print " - checking if this machine runs either #{os_list.join(' or ')}" unless quiet
    os_list.each do |os|
      return print_result(true, quiet) if discover_os(true) == os 
    end
    print_result(false, quiet)
  end

  def is_debian? quiet=false
    print " - checking if this machine runs debian" unless quiet
    print_result( discover_os(true) == "debian", quiet )
  end

  def is_ubuntu? quiet=false
    print " - checking if this machine runs ubuntu" unless quiet
    print_result( discover_os(true) == "ubuntu", quiet )
  end

  def is_gentoo? quiet=false
    print " - checking if this machine runs gentoo" unless quiet
    print_result( discover_os(true) == "gentoo", quiet )
  end

  def is_centos? quiet=false
    print " - checking if this machine runs centos" unless quiet
    print_result( discover_os(true) == "centos", quiet )
  end

  def is_executable? file, quiet=false
    print " - checking if #{file} is installed" unless quiet
    print_result( exec("test -x $(which #{file})")[:exit_code], quiet )
  end

  def file_exists? file, quiet=false
    print " - checking if #{file} is installed" unless quiet
    print_result( exec("test -e #{file}")[:exit_code], quiet )
  end

  # checks if one of the packages is installed
  def package_installed? packages, quiet=false
    packages = [ packages ] if packages.class == String

    print " - checking if #{packages.join(' or ')} is installed" unless quiet

    os = discover_os(true)
    packages.each do |package|
      case os
      when "gentoo"
        return print_result(true, quiet) unless exec("qlist -I #{package}")[:stdout].empty?
      when "debian"
        return print_result(true, quiet) unless exec("dpkg -s #{package} |grep 'install ok'")[:stdout].empty?
      when "ubuntu"
        return print_result(true, quiet) unless exec("dpkg -s #{package} |grep 'install ok'")[:stdout].empty?
      when "centos"
        return print_result(true, quiet) if exec("rpm -q #{package}")[:exit_code]
      end
    end

    print_result(false, quiet)
  end

  def restart_service service, quiet=false
    print " - restarting #{service}" unless quiet 
    print_result( exec("/etc/init.d/#{service} restart")[:exit_code], quiet )
  end

  def reload_service service, quiet=false
    print " - reloading #{service}" unless quiet
    print_result( exec("/etc/init.d/#{service} reload")[:exit_code], quiet )
  end

  def qm_list name, quiet=false
    if name
      print " - looking for a vm with name #{name}" unless quiet
      ret = exec("qm list |grep #{name}")
    else
      print " - looking for vms" unless quiet
      ret = exec('qm list |grep -v VMID')
    end 

    if print_result(ret[:exit_code], quiet)
      line = ret[:stdout].gsub(/\n/, "\n\t")
      return "#{@@green}#{@attr['hostname']}#{@@none}\t#{line}\n"
    end

    return ''
  end

  def print_result ret, quiet=false
    if ret == 0 or ret == true
      puts " #{@@blue}[ ok ]#{@@none}" unless quiet
      return true
    else
      puts " #{@@red}[ failed ]#{@@none}" unless quiet
      return false
    end
  end

  def print_warning string
    puts "#{string} #{@@yellow}[ warning ]#{@@none}"
  end
end

end
