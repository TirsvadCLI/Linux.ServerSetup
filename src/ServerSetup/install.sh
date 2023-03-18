#!/bin/bash

## @file
## @author Jens Tirsvad Nielsen
## @brief Setup a secure server
## @details
## **Server Setup**
##
## With support for
## - webserver nginx with encryption (ssl)
## - Email server postfix with gui postfix admin
## - Database server postgresql
##
## @todo
## - Add streaming server
## - More configuration for email server

declare IFS=$'\n\t'

# Setting path structure and file
declare -r TCLI_SERVERSETUP_PATH_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r TCLI_SERVERSETUP_PATH_INC="$TCLI_SERVERSETUP_PATH_ROOT/inc"

. $TCLI_SERVERSETUP_PATH_INC/inc.sh
. $TCLI_SERVERSETUP_PATH_INC/versionCompare.sh

[ ! -d $TCLI_SERVERSETUP_PATH_LOG ] && mkdir $TCLI_SERVERSETUP_PATH_LOG || rm -f $TCLI_SERVERSETUP_PATH_LOG/*
rm -rf $TCLI_SERVERSETUP_PATH_TEMP/*

declare -r TCLI_SERVERSETUP_FILE_LOG="$( cd "$TCLI_SERVERSETUP_PATH_LOG" && pwd )/install.log"

exec 3>&1 4>&2
exec 1>$TCLI_SERVERSETUP_FILE_LOG  2>&1

printf "\n################################################################################\n" >&3
printf "#                            Linux Server Setup                                #\n" >&3
printf "################################################################################\n" >&3
. $TCLI_SERVERSETUP_PATH_VENDOR/Linux.Distribution/src/Distribution/distribution.sh
. $TCLI_SERVERSETUP_PATH_VENDOR/Linux.PackageManager/src/PackageManager/PackageManager.sh
. $TCLI_SERVERSETUP_PATH_INC/functions.sh

infoscreen "Loading" "Setting configuration"

[ -f "$TCLI_SERVERSETUP_PATH_CONF/settings.yaml" ] && TCLI_SERVERSETUP_FILE_CONF=$TCLI_SERVERSETUP_PATH_CONF/settings.yaml || TCLI_SERVERSETUP_FILE_CONF=$TCLI_SERVERSETUP_PATH_CONF/settings.default.yaml
. $TCLI_SERVERSETUP_PATH_INC/precheck.sh
TCLI_SERVERSETUP_PRIMARYHOSTANME=$(yq eval ".primaryHostname" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_PRIMARYHOSTANME = null ] && infoscreenwarn "$TCLI_SERVERSETUP_FILE_CONF missing configuration of primaryHostname"
TCLI_SERVERSETUP_SSHPORT=$(yq eval ".Server.RemoteSetup.sshPort" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_SSHPORT = null ] && TCLI_SERVERSETUP_SSHPORT=22
TCLI_SERVERSETUP_SSHPORT_HARDNESS=$(yq eval ".Server.RemoteSetup.sshPortHardness" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_SSHPORT_HARDNESS = null ] && TCLI_SERVERSETUP_SSHPORT_HARDNESS=10233

TCLI_SERVERSETUP_CERTBOT_EMAIL=$(yq eval ".Server.certbotEmail" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_CERTBOT_EMAIL = null ] && TCLI_SERVERSETUP_CERTBOT_EMAIL="admin@"

TCLI_SERVERSETUP_NGINX_SETUP=$(yq eval ".NginxSetup.install" < $TCLI_SERVERSETUP_FILE_CONF)

if [ ${TCLI_SERVERSETUP_NGINX_SETUP:-0} ]; then
	. $TCLI_SERVERSETUP_PATH_VENDOR/Linux.NginxSetup/src/NginxSetup/setup.sh
	TCLI_NGINXSETUP_PATH_CONF=${TCLI_SERVERSETUP_PATH_CONF}
	TCLI_NGINXSETUP_PATH_TEMP=${TCLI_SERVERSETUP_PATH_TEMP}
	TCLI_NGINXSETUP_PATH_WWW_BASE=$(yq eval ".NginxSetup.Paths.wwwBase" < ${TCLI_SERVERSETUP_FILE_CONF}); [ "${TCLI_NGINXSETUP_PATH_WWW_BASE}" == "null" ] && TCLI_NGINXSETUP_PATH_WWW_BASE="/srv/www"
	TCLI_NGINXSETUP_PATH_SITES_AVAILABLE=$(yq eval ".NginxSetup.Paths.sitesAvailable" < ${TCLI_SERVERSETUP_FILE_CONF}); [ "${TCLI_NGINXSETUP_PATH_SITES_AVAILABLE}" == "null" ] && TCLI_NGINXSETUP_PATH_SITES_AVAILABLE="/etc/nginx/sites-available"
	TCLI_NGINXSETUP_PATH_SITES_ENABLED=$(yq eval ".NginxSetup.Paths.sitesEnabled" < ${TCLI_SERVERSETUP_FILE_CONF}); [ "${TCLI_NGINXSETUP_PATH_SITES_ENABLED}" == "null" ] && TCLI_NGINXSETUP_PATH_SITES_ENABLED="/etc/nginx/sites-enabled"
	tcli_nginxsetup_init
fi
if [ "$(yq eval ".Server.RemoteSetup" < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ]; then
	# Need root access if script is running on server we working on.
	[[ $EUID -ne 0 ]] && infoscreenfailed "This script must be run as root or runned localy with shh to server"
else
	TCLI_SERVERSETUP_SERVERIP=$(yq eval ".Server.RemoteSetup.ip" < $TCLI_SERVERSETUP_FILE_CONF)
	nc -z -v -w5 $TCLI_SERVERSETUP_SERVERIP $TCLI_SERVERSETUP_SSHPORT || infoscreenFailedExit "Couldn't reach server at" "$TCLI_SERVERSETUP_SERVERIP:$TCLI_SERVERSETUP_SSHPORT"
	TCLI_SERVERSETUP_ROMOTE_SERVER=1
	# TCLI_PKGS need also this
	TCLI_PACKAGEMANAGER_REMOTE_SERVER=1
	TCLI_PACKAGEMANAGER_REMOTE_SERVER_IP=$TCLI_SERVERSETUP_SERVERIP
	TCLI_PACKAGEMANAGER_REMOTE_SERVER_PORT=$TCLI_SERVERSETUP_SSHPORT
fi
if [ -z ${SSHPASS} ]; then
	export SSHPASS=$(yq eval ".Server.RemoteSetup.sshRootPass" < $TCLI_SERVERSETUP_FILE_CONF)
fi
infoscreendone

## @fn tcli_serversetup_serverrootCmd()
## @brief Connect server and an execute command as root
## @param Shell command
## @return true or false of command success
## @details
tcli_serversetup_serverrootCmd() {
	local _screendump
	TCLI_SERVERSETUP_TERMINAL_OUTPUT=$(ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP $@)
	if [ ! $? -eq 0 ]; then
		infoscreenwarn
		printf "Command executed but failed: ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP %s\n" "$*"
		return 1
	fi
	printf "Command executed: ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP %s\n" "$*"
}

## @fn tcli_serversetup_init()
tcli_serversetup_init () {
	local primaryHostname=$(yq eval ".primaryHostname" < $TCLI_SERVERSETUP_FILE_CONF)
	# Delete old known host
	ssh-keygen -f ~/.ssh/known_hosts -R "$TCLI_SERVERSETUP_SERVERIP"
	ssh-keygen -f ~/.ssh/known_hosts -R "[$TCLI_SERVERSETUP_SERVERIP]:$TCLI_SERVERSETUP_SSHPORT"
	ssh-keygen -f ~/.ssh/known_hosts -R "[$TCLI_SERVERSETUP_SERVERIP]:$TCLI_SERVERSETUP_SSHPORT_HARDNESS"

	# Get passwordless root access
	sshpass -e ssh-copy-id -p $TCLI_SERVERSETUP_SSHPORT -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$TCLI_SERVERSETUP_SERVERIP

	# Create some path
	mkdir -p $TCLI_SERVERSETUP_PATH_TEMP/etc/ssh

	# Update and Upgrade
	infoscreen "Install" "Update and upgrade OS"
	tcli_packageManager_system_update
	tcli_packageManager_system_upgrade
	case $TCLI_LINUX_DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install sudo rsync
		;;
	"Ubuntu")
		tcli_packageManager_install sudo rsync
		;;
	esac
	ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "hostnamectl set-hostname $primaryHostname"
	infoscreendone
}

## @fn tcli_serversetup_create_user()
tcli_serversetup_create_user() {
	if [[ $EUID -eq 0 ]]; then
			return 1;
	fi
	local i=0
	until [ $i -lt 0 ]; do
		local s=$(yq eval ".Server.Users[$i]" < $TCLI_SERVERSETUP_FILE_CONF)
		if [ ! "$s" = null ]; then
			local username=$(yq eval ".Server.Users[$i].name" < $TCLI_SERVERSETUP_FILE_CONF)
			infoscreen "Setup" "Create user \"$username\""
			local passwordEncrypted=$(yq eval ".Server.Users[$i].passwordEncrypted" < $TCLI_SERVERSETUP_FILE_CONF)
			local superuser=$(yq eval ".Server.Users[$i].superuser" < $TCLI_SERVERSETUP_FILE_CONF)
			# validation
			[[ "$passwordEncrypted" = null || "$username" = null ]] && infoscreenwarn
			# create user
			if [ ! $(ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "id -u $username") &>/dev/null ]; then
				ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "useradd -m -p $passwordEncrypted -s /bin/bash $username" >/dev/null
				ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "usermod -a -G sudo $username" >/dev/null
				sshpass -e ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub $username@$TCLI_SERVERSETUP_SERVERIP >/dev/null
			else
				infoscreenwarn
				printf "${FUNCNAME[0]}: WARNING user $username allready exist\n"
			fi
			((i=i+1))
			infoscreendone
		else
			i=-1
		fi
	done
}

## @fn tcli_serversetup_hardness_server()
tcli_serversetup_hardness_server() {
	infoscreen "Setup" "Hardness server (only key access / no password)"
	# # Change sshd_config file and send to server
	sed "s/<sshport>/$TCLI_SERVERSETUP_SSHPORT_HARDNESS/g" $TCLI_SERVERSETUP_PATH_CONF/ssh/sshd_config > $TCLI_SERVERSETUP_PATH_TEMP/etc/ssh/sshd_config
	scp -P $TCLI_SERVERSETUP_SSHPORT $TCLI_SERVERSETUP_PATH_TEMP/etc/ssh/sshd_config root@$TCLI_SERVERSETUP_SERVERIP:/etc/ssh
	ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "systemctl restart ssh.service"
	TCLI_PACKAGEMANAGER_REMOTE_SERVER_PORT=$TCLI_SERVERSETUP_SSHPORT_HARDNESS
	infoscreendone
}

## @fn tcli_serversetup_hardness_server_firewall()
tcli_serversetup_hardness_server_firewall() {
	infoscreen "Setup" "Hardness server firewall nftables"
	tcli_serversetup_serverrootCmd "nft flush ruleset"
	tcli_serversetup_serverrootCmd "nft add table inet filter"
	tcli_serversetup_serverrootCmd "nft add chain inet filter input '{ type filter hook input priority 0 ; policy accept;}'"
	# allow established/related connections
	tcli_serversetup_serverrootCmd "nft add rule inet filter input ct state established,related accept"
	# early drop of invalid connections
	tcli_serversetup_serverrootCmd "nft add rule inet filter input ct state invalid drop"
	# allow from loopback
	tcli_serversetup_serverrootCmd "nft add rule inet filter input iifname lo accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input iif != \"lo\" ip daddr 127.0.0.0/8 drop"
	# allow icmp
	tcli_serversetup_serverrootCmd "nft add rule inet filter input ip protocol icmp limit rate 4/second accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input ip6 nexthdr icmpv6 limit rate 4/second accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport $TCLI_SERVERSETUP_SSHPORT_HARDNESS accept"
	tcli_serversetup_serverrootCmd "nft add chain inet filter forward { type filter hook forward priority 0 \; policy accept\; }"
	tcli_serversetup_serverrootCmd "nft add chain inet filter output { type filter hook output priority 0 \; policy accept\; }"
	tcli_serversetup_serverrootCmd "nft add chain inet filter input '{ policy drop; }'"
	infoscreendone
}

## @fn tcli_serversetup_cerbot_install()
tcli_serversetup_cerbot_install() {
	infoscreen "Install" "Certbot let's encrypt"
	case $TCLI_LINUX_DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install certbot
		tcli_packageManager_install python3-certbot-nginx
		;;
	"Ubuntu")
		tcli_packageManager_install certbot
		tcli_packageManager_install python3-certbot-nginx
		;;
	esac		
	if [[ -f "${TCLI_SERVERSETUP_PATH_BACKUP}/${TCLI_SERVERSETUP_FILE_CERT_BACKUP}" ]]; then
		scp -P ${TCLI_SERVERSETUP_SSHPORT_HARDNESS} ${TCLI_SERVERSETUP_PATH_BACKUP}/${TCLI_SERVERSETUP_FILE_CERT_BACKUP} root@${TCLI_SERVERSETUP_SERVERIP}:~/
		tcli_serversetup_serverrootCmd "tar -xf ~/${TCLI_SERVERSETUP_FILE_CERT_BACKUP} -C /"
		tcli_serversetup_serverrootCmd "rm ~/${TCLI_SERVERSETUP_FILE_CERT_BACKUP}"
	fi
	(crontab -l 2>/dev/null; printf "@daily certbot renew --quiet && systemctl reload postfix dovecot nginx") | tcli_serversetup_serverrootCmd "crontab -"
	infoscreendone
}

## @fn tcli_serversetup_cerbot_add_certificate()
tcli_serversetup_cerbot_add_certificate() {
	if tcli_serversetup_serverrootCmd "certbot certificates | grep -w \"Domains: $1\""; then
		printf "Reinstalling certificate for $1"
		if [ "$2" == "standalone" ]; then
			tcli_serversetup_serverrootCmd "kill $(lsof -t -i:80)"
			tcli_serversetup_serverrootCmd "certbot --reinstall --agree-tos --no-eff-email --email $TCLI_SERVERSETUP_CERTBOT_EMAIL --standalone -d $1"
		else
			tcli_serversetup_serverrootCmd "certbot --reinstall --agree-tos --no-eff-email --email $TCLI_SERVERSETUP_CERTBOT_EMAIL --nginx -d $1"
		fi
	else
		printf "Creating certificate for $1"
		if [ "$2" == "standalone" ]; then
			tcli_serversetup_serverrootCmd "kill $(lsof -t -i:80)"
			tcli_serversetup_serverrootCmd "certbot certonly --standalone --agree-tos --no-eff-email --staple-ocsp --email $TCLI_SERVERSETUP_CERTBOT_EMAIL -d $1"
		else
			tcli_serversetup_serverrootCmd "certbot certonly -a nginx --agree-tos --no-eff-email --staple-ocsp --email $TCLI_SERVERSETUP_CERTBOT_EMAIL -d $1"
		fi
	fi
}

## @fn tcli_serversetup_nginx_install()
tcli_serversetup_nginx_install() {
	infoscreen "Install" "Nginx"
	tcli_nginxsetup_remote $TCLI_SERVERSETUP_SERVERIP $TCLI_SERVERSETUP_SSHPORT_HARDNESS
	tcli_nginxsetup_install
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 80 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 443 accept"

	if [[ -f "$TCLI_SERVERSETUP_PATH_CONF/nginx/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP" ]]; then
		scp -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS $TCLI_SERVERSETUP_PATH_CONF/letsencrypt/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP root@$TCLI_SERVERSETUP_SERVERIP:~/
		tcli_serversetup_serverrootCmd "tar -xvf ~/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP -C /"
	fi	
	mkdir -p ${TCLI_SERVERSETUP_PATH_TEMP}/etc/nginx/sites-available
	local c=$(yq e '.NginxSetup.WebSites | length' < $TCLI_SERVERSETUP_FILE_CONF)
	for (( i=0; i < $c; i++ )); do
		local _s=$(yq eval ".NginxSetup.WebSites[$i]" < $TCLI_SERVERSETUP_FILE_CONF)
		local _domainName=$(yq eval ".NginxSetup.WebSites[$i].domainName" < $TCLI_SERVERSETUP_FILE_CONF)
		local _root=$(yq eval ".NginxSetup.WebSites[$i].root" < $TCLI_SERVERSETUP_FILE_CONF)
		local _siteType=$(yq eval ".NginxSetup.WebSites[$i].siteType" < $TCLI_SERVERSETUP_FILE_CONF)
		local _siteConfFile=$(yq eval ".NginxSetup.WebSites[$i].siteConf" < $TCLI_SERVERSETUP_FILE_CONF)
		[ "$_root" == "null" ] && _root=""
		case $_siteConfFile in
			"null" | "")
				_siteConfFile=""
				;;
			*)
				[ -f ${TCLI_SERVERSETUP_FILE_CONF}/nginx/sites-available/${_siteConfFile} ] || infoscreenFailedExit "custom website conf file '${_siteConfFile}' does not exist"
				;;
		esac
		tcli_nginxsetup_add_domain "$_domainName" "$_root" "$_siteType" "$_siteConfFile"
		tcli_serversetup_cerbot_add_certificate $_domainName
	done
	infoscreendone
}

## @fn tcli_serversetup_postgresql_install()
tcli_serversetup_postgresql_install() {
	infoscreen "Install" "PostgreSQL"
	case $TCLI_LINUX_DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install postgresql postgresql-contrib
		tcli_serversetup_serverrootCmd "systemctl start postgresql"
		tcli_serversetup_serverrootCmd "systemctl enable postgresql"
		;;
	"Ubuntu")
		tcli_packageManager_install postgresql postgresql-contrib
		tcli_serversetup_serverrootCmd "systemctl start postgresql"
		tcli_serversetup_serverrootCmd "systemctl enable postgresql"
		;;
	esac
	infoscreendone
}

## @fn tcli_serversetup_postfix_install()
tcli_serversetup_postfix_install() {
	infoscreen "Install" "Postfix"
	[ "$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] && infoscreenfailed || local _postfix_hostname="$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)"
	if ! tcli_serversetup_serverrootCmd "which psql"; then
		infoscreenfailed "No" "database" "avaible for postfix"
		return 1
	fi
	if ! tcli_serversetup_serverrootCmd "which nginx"; then
		tcli_serversetup_cerbot_add_certificate "$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)" "standalone"
	else
		cp $TCLI_SERVERSETUP_PATH_CONF/nginx/sites-available/mail_server.default $TCLI_SERVERSETUP_PATH_TEMP/etc/nginx/sites-available/$_postfix_hostname
		sed -i "s/<POSTFIX_HOSTNAME>/$_postfix_hostname/g" $TCLI_SERVERSETUP_PATH_TEMP/etc/nginx/sites-available/$_postfix_hostname
		tcli_serversetup_cerbot_add_certificate "$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)"
	fi
	
	# Install
	tcli_serversetup_serverrootCmd "printf \"postfix	postfix/mailname string $_postfix_hostname\" | debconf-set-selections"
	tcli_serversetup_serverrootCmd "printf \"postfix postfix/main_mailer_type string 'Internet Site'\" | debconf-set-selections"
	case $TCLI_LINUX_DISTRIBUTION_ID in
		"Debian GNU/Linux")
			tcli_packageManager_install postfix
			;;
		"Ubuntu")
			tcli_packageManager_install postfix
			;;
	esac
	infoscreendone

	infoscreen "Config" "Postfix"
	local _mailbox_size_limit=10240000 # default value
	[ "$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] || local _mailbox_size_limit="$(yq eval '.Postfix.mailboxSizeLimit' < $TCLI_SERVERSETUP_FILE_CONF)"
	# nft accept port 25, 465,587 so Postfix can receive emails from other SMTP servers
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 25 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 465 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 587 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter output tcp dport 25 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter output tcp dport 465 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter output tcp dport 587 accept"
	# nft accept imaps
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 143 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 993 accept"
	# Increase Attachment Size Limit 50mb instead of 10mb
	tcli_serversetup_serverrootCmd "postconf -e message_size_limit=$_mailbox_size_limit"
	tcli_serversetup_serverrootCmd "systemctl reload postfix"
	infoscreendone
}

## @fn tcli_serversetup_dovocot_install()
tcli_serversetup_dovocot_install() {
	infoscreen "Install" "Dovecot"
	case $TCLI_LINUX_DISTRIBUTION_ID in
		"Debian GNU/Linux")
			tcli_packageManager_install dovecot-core dovecot-imapd dovecot-lmtpd
			;;
		"Ubuntu")
			tcli_packageManager_install dovecot-core dovecot-imapd dovecot-lmtpd
			;;
	esac
	infoscreendone

	infoscreen "Config" "Dovecot"
	mkdir -p ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/conf.d
	tcli_serversetup_serverrootCmd "adduser dovecot mail"
	local _postfix_hostname="$(yq eval '.Postfix.hostname' < $TCLI_SERVERSETUP_FILE_CONF)"
	[ ! -d ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/ ] && mkdir ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/
	sed "s/<POSTFIX_HOSTNAME>/$_postfix_hostname/g" ${TCLI_SERVERSETUP_PATH_CONF}/dovecot/conf.d/10-ssl.conf > ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/conf.d/10-ssl.conf
	cp ${TCLI_SERVERSETUP_PATH_CONF}/dovecot/dovecot.conf ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/
	cp ${TCLI_SERVERSETUP_PATH_CONF}/dovecot/conf.d/{10-auth.conf,10-mail.conf,10-master.conf} ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot/conf.d/
	scp -r -P ${TCLI_SERVERSETUP_SSHPORT_HARDNESS} ${TCLI_SERVERSETUP_PATH_TEMP}/etc/dovecot root@${TCLI_SERVERSETUP_SERVERIP}:/etc/
	infoscreendone
}

## @fn tcli_serversetup_postfixadmin_install()
tcli_serversetup_postfixadmin_install() {
	local _domainName
	local _siteType
	infoscreen "Install" "postfix admin"
	case $TCLI_LINUX_DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install acl
		;;
	"Ubuntu")
		tcli_packageManager_install acl
		;;
	esac
	# check if php exist and its version
	if ! tcli_serversetup_serverrootCmd "which php"; then
		case $TCLI_LINUX_DISTRIBUTION_ID in
		"Debian GNU/Linux")
			tcli_packageManager_install php-fpm php
			;;
		"Ubuntu")
			tcli_packageManager_install php-fpm php
			;;
		esac
	fi
	tcli_serversetup_serverrootCmd "php -r 'exit((int)version_compare(PHP_VERSION, \"7.2.0\", \"<\"));'"
	[ $? ] || infoscreenfailed "need newer version of" "PHP"

	[ "$(yq eval '.PostfixAdmin.version' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] \
		&& infoscreenfailed "Missing version for Postfix Admin in file" "settingsfile $TCLI_SERVERSETUP_FILE_CONF" \
		|| local _postfixAdmin_version="$(yq eval '.PostfixAdmin.version' < $TCLI_SERVERSETUP_FILE_CONF)"
	[ "$(yq eval '.PostfixAdmin.passwordDatabase' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] \
		&& infoscreenfailed "Missing database password for Postfix Admin in file" "settingsfile $TCLI_SERVERSETUP_FILE_CONF" \
		|| local _postfixAdmin_password="$(yq eval '.PostfixAdmin.passwordDatabase' < $TCLI_SERVERSETUP_FILE_CONF)"

	tcli_serversetup_serverrootCmd "wget https://github.com/postfixadmin/postfixadmin/archive/refs/tags/postfixadmin-$_postfixAdmin_version.tar.gz"
	tcli_serversetup_serverrootCmd "tar tzf postfixadmin-$_postfixAdmin_version.tar.gz | sed -e 's@/.*@@' | uniq"
	echo "Terminal output $TCLI_SERVERSETUP_TERMINAL_OUTPUT"

	[ ! -z $TCLI_SERVERSETUP_TERMINAL_OUTPUT ] && local _postfixadmin_root_folder=/srv/www/$TCLI_SERVERSETUP_TERMINAL_OUTPUT || infoscreenFailedExit "postfix admin retrieve folder name failed"
	tcli_serversetup_serverrootCmd "tar -xf postfixadmin-$_postfixAdmin_version.tar.gz -C /srv/www/"
	tcli_serversetup_serverrootCmd "mkdir -p ${_postfixadmin_root_folder}/templates_c"
	tcli_serversetup_serverrootCmd "setfacl -R -m u:www-data:rwx $_postfixadmin_root_folder/templates_c/"
	tcli_serversetup_serverrootCmd "setfacl -R -m u:www-data:rx /etc/letsencrypt/live/ /etc/letsencrypt/archive/"
	
	tcli_serversetup_serverrootCmd "sudo -u postgres -i psql -c 'CREATE DATABASE postfixadmin;'"
	tcli_serversetup_serverrootCmd "sudo -u postgres -i psql -c \"CREATE USER postfixadmin WITH PASSWORD '$_postfixAdmin_password';\""
	tcli_serversetup_serverrootCmd "sudo -u postgres -i psql -c 'ALTER DATABASE postfixadmin OWNER TO postfixadmin;'"
	tcli_serversetup_serverrootCmd "sudo -u postgres -i psql -c 'GRANT ALL PRIVILEGES ON DATABASE postfixadmin TO postfixadmin;'"

	local _postfixadmin_config_local_path_file="${_postfixadmin_root_folder}/config.local.php"
	echo "_postfixadmin_config_local_path_file = ${_postfixadmin_config_local_path_file}"
	tcli_serversetup_serverrootCmd "printf \"<?php\n\" > $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['configured'] = true;\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_type'] = 'pgsql';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_host'] = 'localhost';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_port'] = '5432';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_user'] = 'postfixadmin';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_password'] = '$_postfixAdmin_password';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['database_name'] = 'postfixadmin';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['encrypt'] = 'dovecot:ARGON2I';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"\$CONF['dovecotpw'] = '/usr/bin/doveadm pw -r 5';\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"if(@file_exists('/usr/bin/doveadm')) { // @ to silence openbase_dir stuff; see https://github.com/postfixadmin/postfixadmin/issues/171\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"		\$CONF['dovecotpw'] = '/usr/bin/doveadm pw -r 5'; # debian\n\" >> $_postfixadmin_config_local_path_file"
	tcli_serversetup_serverrootCmd "printf \"}\n\" >> $_postfixadmin_config_local_path_file"
	
	local _c=$(yq e '.PostfixAdmin.DomainNames | length' < $TCLI_SERVERSETUP_FILE_CONF)
	for (( i=0; i < $_c; i++ )); do
		[ "$_root" == "null" ] && _root=""
		case $_siteConfFile in
			"null" | "")
				_siteConfFile=""
				;;
			*)
				[ -f ${TCLI_SERVERSETUP_FILE_CONF}/nginx/sites-available/${_siteConfFile} ] || infoscreenFailedExit "custom website conf file '${_siteConfFile}' does not exist"
				;;
		esac

		local s=$(yq eval ".PostfixAdmin.DomainNames[$i]" < $TCLI_SERVERSETUP_FILE_CONF)
		_domainName=$(yq eval ".PostfixAdmin.DomainNames[$i].domainName" < $TCLI_SERVERSETUP_FILE_CONF)
		_root=$(yq eval ".PostfixAdmin.WebSites[$i].root" < $TCLI_SERVERSETUP_FILE_CONF)
		_siteType=postfixAdmin
		printf "\n\n$i setting up postfix admin webpage on $_domainName\n\n"
		tcli_nginxsetup_add_domain $_domainName "$_postfixadmin_root_folder" "$_siteType" "$_siteConfFile"
		tcli_serversetup_cerbot_add_certificate $_domainName
	done

	infoscreendone
}

tcli_serversetup_init
tcli_serversetup_create_user
tcli_serversetup_hardness_server
tcli_serversetup_hardness_server_firewall
tcli_serversetup_cerbot_install
[ $TCLI_SERVERSETUP_NGINX_SETUP ] && tcli_serversetup_nginx_install
[[ $(yq eval '.PostgreSql.install' < $TCLI_SERVERSETUP_FILE_CONF) == 0 || "$(yq eval '.PostgreSql.install' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ]] || tcli_serversetup_postgresql_install
[ "$(yq eval '.Postfix.install' < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] || tcli_serversetup_postfix_install
tcli_serversetup_dovocot_install
tcli_serversetup_postfixadmin_install

