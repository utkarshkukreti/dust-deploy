dust - a ssh/facter only server deployment tool
=============

dust is a deployment tool, kinda like sprinkle. but cooler (at least for me).
it's for those, who would like to maintain their servers with a tool like puppet or chef, but are scared by the thought of having configuration files, credentials and other stuff centrally on a server reachable via the internet.

although the tool is not as versatile and elite as puppet, it's still cool for most use cases, and easily extendable.


installing
------------

installation is quite simple. just 

    # gem install dust-deploy


using
------------

let's start by creating a new directory skeleton

    $ dust new mynetwork
      - spawning new dust directory skeleton into 'mynetwork.dust' [ ok ]

this will create a directory called mynetwork.dust, the nodes, templates and recipes subdirectories and will copy over example templates and node configurations. hop into your new dust directory and see what's going on:

    $ cd mynetwork.dust

dust uses simple .yaml files for configuring your nodes.
let's start by adding a simple host:

    $ vi nodes/yourhost.yaml

and put in basic information:

    # the hostname (fqdn, or set the domain parameter as well, ip also works)
    # you don't need a password if you connect using ssh keys
    hostname: yourhost.example.com
    password: supersecretphrase

    # these are the default values, you have to put them in case you need something else.
    # be aware: sudo usage is not yet supported, but ssh keys are!
    port: 22
    user: root

    # because this alone won't tell dust what to do, let's for example install some useful packages
    recipes:
      packages: [ 'vim', 'git-core', 'rsync' ]


you can then save the file, and tell dust to get to work:

    $ dust deploy

    [ yourhost.example.com ]

    |packages|
     - checking if vim is installed [ ok ]
     - checking if git-core is installed [ failed ]
       - installing git-core [ ok ]
     - checking if rsync is installed [ ok ]

you should see dust connecting to the node, checking if the requested packages are installed, and if not, install them.
dust works with aptitude, yum and emerge systems at the moment (testet with ubuntu, debian, gentoo, scientificlinux, centos).
feel free to contribute to dust, so that your system is also supported. contribution is easy! just send me a github pull request. You can find the repository here: https://github.com/kechagia/dust-deploy


inheritance
------------

because sometimes you will have similar configuration files for multiple systems, you can create templates.
i usually start filenames of templates with an underscore, but that's not a must.

    $ vi nodes/_default.yaml

this template defines some general settings, usually used by most hosts

    domain: example.com
    port: 22
    user: root


and another one:

    $ vi nodes/_debian.yaml

in this template, i put in some debian specific settings

    # you can add custom fields like "group"
    # and filter on which hosts to deploy later
    group: debian
    
    recipes:
      locale: en_US.UTF-8
      debsecan: default
      repositories:
        default:
          url: "http://ftp.de.debian.org/debian/"
          components: "main contrib non-free"
    

you can then inherit these templates in your yourhost.yaml:

    hostname: yourhost
    inherits: [ _default, _debian ]

    recipes:
      packages: [ 'vim', 'git-core', 'rsync' ]


running dust now, will use the inherited settings as well.
you can also overwrite settings in the template with the ones in yourhost.yaml

**NOTE:** hashes will be deep merged with inherited hashes, other types will be overwritten!

    $ dust deploy

    [ yourhost ]

    |repositories|
     - determining whether node uses apt [ ok ]
     - deleting old repositories [ ok ]

     - deploying default repository [ ok ]

    |packages|
     - checking if vim is installed [ ok ]
     - checking if git-core is installed [ ok ]
     - checking if rsync is installed [ ok ]

    |locale|
     - setting locale to 'en_US.UTF-8' [ ok ]

    |debsecan|
     - checking if debsecan is installed [ ok ]
     - configuring debsecan [ ok ]



filters and proxy
------------

because that's not awesome enough, you can also filter your hosts using the --filter flag

     $ dust deploy --filter hostname:myhost-1,otherhost

     $ dust deploy --filter group:debian


and even more, it supports socks proxys, so you can maintain your whole infrastructure without setting up a vpn from the outside via ssh

     $ ssh user@gateway.yourcompany.net -D 1080

     $ dust deploy --proxy localhost:1080



using recipes (and their templates)
------------

dust comes with a set of predifined, (almost) ready to use recipes managing a lot of stuff for you, including the following:

-   ssh authorized keys
-   email aliases file
-   /etc/hosts
-   /etc/motd
-   /etc/resolv.conf
-   install basic system tools and pushing .configuration files for root
-   iptables firewall
-   debian/ubuntu debsecan security notifications
-   debian/ubuntu repositories
-   duplicity backups
-   mysql server configuration
-   postgresql server configuration (including corosync scripts)
-   nginx configuration
-   zabbix agent
-   debian/ubuntu unattended upgrades
-   newrelic system monitoring daemon


writing your own recipes
------------

because the above recipes will probably not in all cases fulfill your needs, it's pretty easy to write your own recipes. You can either file them in using a git pull request (if you think it's a generic one which others might use as well), or place them locally in the "recipes" folder in your mynetwork.dust directory.

dust comes with a set of predefined functions to perform system tasks, which you can (and should!) use.

### the server.rb methods you can (and should!) use

almost all functions understand the quiet=true and indend=integer arguments

#### exec command
#### write target, text, quiet=false, indent=1
#### append target, text, quiet=false, indent=1
#### scp source, destination, quiet=false, indent=1
#### symlink source, destination, quiet=false, indent=1
#### chmod mode, file, quiet=false, indent=1
#### chown user, file, quiet=false, indent=1
#### rm file, quiet=false, indent=1
#### mkdir dir, quiet=false, indent=1
#### restorecon path, quiet=false, indent=1
#### get_system_users quiet=false
#### package_installed? packages, quiet=false, indent=1
#### install_package package, quiet=false, indent=1, env=""
#### update_repos quiet=false, indent=1
#### system_update quiet=false, indent=1
#### uses_apt? quiet=false, indent=1
#### uses_rpm? quiet=false, indent=1
#### uses_emerge? quiet=false, indent=1
#### is_executable? file, quiet=false, indent=1
#### file_exists? file, quiet=false, indent=1
#### dir_exists? dir, quiet=false, indent=1
#### autostart_service service, quiet=false, indent=1
#### restart_service service, quiet=false, indent=1
#### reload_service service, quiet=false, indent=1
#### user_exists? user, quiet=false, indent=1
#### create_user user, home=nil, shell=nil, quiet=false, indent=1

#### collect_facts quiet=false, indent=1
#### is_os? os_list, quiet=false, indent=1
#### is_debian? quiet=false, indent=1
#### is_ubuntu? quiet=false, indent=1
#### is_gentoo? quiet=false, indent=1
#### is_centos? quiet=false, indent=1
#### is_scientific? quiet=false, indent=1
#### is_fedora? quiet=false, indent=1


### example recipes

The best is to have a look at dusts build-in recipes: https://github.com/kechagia/dust-deploy/tree/master/lib/dust/recipes

this is the basic skeletton of a recipe file, placed in recipes/your_task.rb

    class YourTask < Thor
      desc 'your_task:deploy', 'example task: displays a message and does basically nothing'
      def deploy node, ingredients, options

        ::Dust.print_msg 'this is a test example. welcome! output of uname -a below:'
        puts node.exec('uname -a')[:stdout]

        node.uses_apt?

        node.restart_service 'your-service' if options.restart?
      end

      desc 'your_task:status', 'example status: displays the status of this recipe (optional)'
      def status, node, ingredients, options
        ::Dust.print_msg "displaying status of this example recipe!"
      end
    end


contributing
------------

you have a cool contribution or bugfix? yippie! just file in a pull-request!

