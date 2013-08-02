name             'tickr'
maintainer       'Robby Grossman'
maintainer_email 'robby@freerobby.com'
license          'All rights reserved'
description      'Installs/Configures tickr'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.66'

depends 'application'
depends 'apt'
depends 'build-essential'
depends 'git'
depends 'mysql'
depends 'nginx'
depends 'unicorn'
