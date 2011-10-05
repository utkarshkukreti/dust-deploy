module Dust
  # colors for terminal
  @red   = "\033[1;31m"
  @blue   = "\033[1;34m"
  @green  = "\033[1;32m"
  @yellow = "\033[1;33m"
  @none   = "\033[0m"

  $stdout.sync = true # autoflush

  def self.print_result ret, quiet=false
    if ret == 0 or ret == true
      print_ok unless quiet
      return true
    else
      print_failed unless quiet
      return false
    end
  end

  def self.print_ok string=""
    puts "#{string} #{@blue}[ ok ]#{@none}"
  end

  def self.print_failed string=""
    puts "#{string} #{@red}[ failed ]#{@none}"
  end

  def self.print_warning string=""
    puts "#{string} #{@yellow}[ warning ]#{@none}"
  end

  def self.print_hostname server
    puts "#{@green}#{server.attr['hostname']}#{@none}:"
  end
end
