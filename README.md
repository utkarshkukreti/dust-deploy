dust - a ssh/facter only server deployment tool
=============

dust is a deployment tool, kinda like sprinkle. but cooler (at least for me).
it's for those, who would like to maintain their servers with a tool like puppet or chef, but are scared by the thought of having configuration files, credentials and other stuff centrally on a server reachable via the internet.

although the tool is not as versatile and elite as puppet, it's still cool for most use cases, and easily extendable.


installing
------------

installation is quite simple. just 
    gem install dust


using
------------

first, let's start by creating your dust directory

    $ mkdir mynetwork.dust

then, create directories you might/will need. (there's going to be an automation process in the future, e.g. using "dust new mynetwork.dust")

    $ cd mynetwork.dust
    $ mkdir templates
    $ mkdir nodes

in the nodes directory, there will be your templates and node configurations.
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

    # because this alone won't tell dust what to do, let's for example install a package
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

you should see dust connecting to the node, checking if the requestet packages are installed, and if not, install them.
dust works with aptitude, yum and emerge systems at the moment (testet with ubuntu, debian, gentoo, scientificlinux, centos).
feel free to contribute to dust, so that your system is also supportet. contribution is easy!


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




using recipes (and their templates)
------------


writing your own recipes
------------


contributing
------------

you have a cool contribution or bugfix? yippie! just file in a pull-request!

### the server.rb methods you can (and should!) use
