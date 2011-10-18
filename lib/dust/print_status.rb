module Dust
  # colors for terminal
  def self.red;      "\033[1;31m"; end
  def self.green;    "\033[1;32m"; end
  def self.yellow;   "\033[1;33m"; end
  def self.blue;     "\033[1;34m"; end
  def self.pink;     "\033[1;35m"; end
  def self.turquois; "\033[1;36m"; end
  def self.grey;     "\033[1;37m"; end
  def self.black;    "\033[1;38m"; end
  def self.none;     "\033[0m"; end

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

  def self.print_ok string="", level=0
    print_msg "#{string} #{blue}[ ok ]#{none}\n", level
  end

  def self.print_failed string="", level=0
    print_msg "#{string} #{red}[ failed ]#{none}\n", level
  end

  def self.print_warning string="", level=0
    print_msg "#{string} #{yellow}[ warning ]#{none}\n", level
  end

  def self.print_hostname hostname, level=0
    print_msg "\n[ #{blue}#{hostname}#{none} ]\n\n", level
  end

  def self.print_recipe recipe, level=0
    print_msg "#{green}|#{recipe}|#{none}\n", level
  end

  # indent according to level
  # level 0
  #  - level 1
  #    - level 2
  def self.print_msg string, level=1
    if level == 0
      print string
    else
      print ' ' + '  ' * (level - 1) + '- ' + string
    end
  end

end
