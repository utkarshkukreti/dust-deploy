require 'rubygems'
require 'yaml'
  
module Dust
  class Dust
    attr_reader :all, :selected,
                :proxy, :global
  
    def initialize yaml
      @all = YAML.load_file(yaml)

      # get global configuration, valid for all servers
      @global = @all.delete('global')
 
      # select all servers by default
      @selected = select('group' => 'all')
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
  
    def each connect=true, &block
      @selected.each do |server|
        if connect
          s = connect server
          next unless s
          yield s
        else
          yield server
        end
      end
    end
  
    def first
      connect @selected.first
    end

    def connect server
      begin
        # overwrite global attributes with attributes for this server
        server = @global.merge(server)

        # set proxy from command-line (if given)
        server['proxy'] = @proxy if @proxy

        return Server.new(server)
      rescue NameError
        puts "#{@@red}ERROR:#{@@none} couldn't connect to #{server['hostname']}!\n\n"
        return false
      end
    end
  end
end
