# Linux Server Setup
This script aimed goal is to set up a complete web server environment.

## Requirement
Debian or Ubuntu fresh install. Other Linux distribution may be added.

## Installation

### First needed packages
yq to parse settings that is stored as YAML

### Get it

	curl -o ServerSetup.tar -L https://github.com/TirsvadCLI/Linux.ServerSetup/tarball/master
	mkdir -p ServerSetup && tar xpvf ServerSetup.tar -C "ServerSetup" --strip-components=1
	cd ServerSetup
	./install.sh
	
## Tools
In the folder tools you can find

### Backup letsencrypt certificate
It will backup your certificate and store it under conf/letsencrypt
	
	bash backup_letsencrypt_cert.sh

## Features
* Create a privileged user
  * option add ssh-key
* sshd
  * option ssh-key for passwordless connection
  * option disable root login
* Setting hostname
* Update system software
* Nginx webserver (optional)
	* Letsencrypt certificate

### TODO
* Optional database Postgresql and Mysql
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
