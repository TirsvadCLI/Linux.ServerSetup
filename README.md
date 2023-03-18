# Linux Server Setup
This script aimed goal is to set up a complete web server environment. Script can be run from a local system with internet access to server.

## Requirement
Debian or Ubuntu fresh install. Other Linux distribution may be added.

###
We depend on following packages to be installed

yq - a lightweight and portable command-line YAML processor, se more at https://github.com/mikefarah/yq/#install

	snap install yq

## Installation

### How to get this

	curl -o ServerSetup.tar -L https://github.com/TirsvadCLI/Linux.ServerSetup/tarball/master
	mkdir -p ServerSetup && tar xpvf ServerSetup.tar -C "ServerSetup" --strip-components=1
	cd ServerSetup/src/ServerSetup
	
In configuration file you make your changes

	cp conf/settings.default.yaml conf/settings.yaml
	nano conf/settings.yaml

When you are ready to do the setup of server

	./install.sh
	
## Tools
In the tools folder you can find following scripts

### Backup server files
#### Certificate from lets encrypt
It will backup your certificate and store it under conf/letsencrypt/backup_certificate.tar.gz

	cd src/ServerSetup/tools
	bash backup_letsencrypt_cert.sh

#### Nginx sites configuration
It will backup your nginx sites configurations and store it under conf/nginx/backup_nginx_sites_configuration.tar.gz

	cd src/ServerSetup/tools
	bash backup_nginx_site_conf.sh

## Features
* Create a privileged user
  * creating ssh-key
* ssh and hardness server
  * ssh-key for passwordless connection
* Setting hostname
* Update system software
* Nginx webserver (optional)
	* Letsencrypt certificate
* Database (optional)
	* Postgresql 
* Email server (optional)
	* Postfix, dovecot and postfixadmin 

### TODO
* Optional database Mysql
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

### Development
Want to contribute? Great!\
Find us [here](https://github.com/TirsvadCLI/Linux.ServerSetup/)
