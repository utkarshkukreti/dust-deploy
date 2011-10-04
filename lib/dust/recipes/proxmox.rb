class Deploy::Proxmox < Thor
  namespace :proxmox

  method_options :search => :string

  desc "#{namespace}:qm_list [--search M]", "lists all virtual machines, or searches for virtual machine M"
  def qm_list
    servers = invoke 'deploy:start', [ 'group' => 'proxmox' ]

    result = String.new

    servers.each do | server |
      puts "#{@@green}#{server.attr['hostname']}#{@@none}:"    
      next unless server.is_debian?
      next unless server.package_installed?( ['proxmox-ve-2.6.35', 'proxmox-ve-2.6.32' ] )

      result += server.qm_list options[:search]

      server.disconnect
      puts
    end

    unless result.empty?
      puts "HOST\t      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID"
      puts result
    end

  end
end

