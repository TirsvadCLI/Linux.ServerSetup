# Linux Server Setup
This script aimed goal is to set up a complete web server environment.

## Requirement
Debian or Ubuntu fresh install. Other Linux distribution may be added.

## Installation
### Get it

    $ wget --no-check-certificate https://github.com/TirsvadCLI/Linux.ServerSetup/tarball/master
    $ tar xpvf master -C "ServerSetup" --strip-components=1

## Features
* Create a privileged user
  * option add ssh-key
* sshd
  * option ssh-key for passwordless connection
  * option disable root login
* Setting hostname
* Update system software

### TODO
* Optional database Postgresql and Mysql
* Optional webserver NGINX
  * Default use SSL certificate (letsencrypt)
* Firewall
  * Automatic configure based on choices made
1. Optional web application envoriment
  * .net
  * django
  * weblate
  * pgadmin
2. Optional e-mail server
  * spam filter
  * anti virus
  * easy add email via web tool

### Development
Want to contribute? Great!\
Find us [here](https://github.com/TirsvadCLI/Linux.ServerSetup/)
