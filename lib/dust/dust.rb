require 'rubygems'
require 'yaml'
  
module Dust
  class Servers
    attr_reader :all, :selected, :global
  
    def initialize yaml
      # load server configuration
      @all = YAML.load_file(yaml)

      # save global attributes
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

      # overwrite global attributes with attributes for each server
      @selected.map! do |server|
        @global.merge(server) if @global
      end

      @selected
    end
  
    def each connect=true, &block
      @selected.each do |server|
        if connect
          begin
            s = Server.new server
          rescue Exception
            next unless s
          end

          yield s
        else
          yield server
        end
      end
    end
  
    def first
      Server.new @selected.first
    end

  end
end
