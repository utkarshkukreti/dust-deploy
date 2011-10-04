require 'rubygems'
require 'yaml'
  
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
end
