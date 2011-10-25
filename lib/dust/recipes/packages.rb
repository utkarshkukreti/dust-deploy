module Dust
  class Deploy
    private
    # install packages (given as an array)
    def packages node, packages
      packages.each do |package| 
        node.install_package package
      end
    end
  end
end

