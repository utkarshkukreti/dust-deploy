class Packages < Thor
  desc 'packages:deploy', 'installs packages'
  def deploy node, packages, options
    packages.each do |package| 
      node.install_package package
    end
  end
end

