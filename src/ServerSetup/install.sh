#!/bin/bash
IFS=$'\n\t'

# Setting path structure and file
declare -r TCLI_SERVERSETUP_PATH_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r TCLI_SERVERSETUP_PATH_INC="$TCLI_SERVERSETUP_PATH_ROOT/inc"

. $TCLI_SERVERSETUP_PATH_INC/inc.sh

[ ! -d "$TCLI_SERVERSETUP_PATH_LOG" ] && mkdir "$TCLI_SERVERSETUP_PATH_LOG" || rm -f $TCLI_SERVERSETUP_PATH_LOG/*.*

declare -r TCLI_SERVERSETUP_FILE_LOG="$( cd "$TCLI_SERVERSETUP_PATH_LOG" && pwd )/$$.log"

exec 3>&1 4>&2
exec 1>$TCLI_SERVERSETUP_FILE_LOG 2>&1

printf "\n################################################################################\n" >&3
printf "#                            Linux Server Setup                                #\n" >&3
printf "#                         SS => Server Side action                             #\n" >&3
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
# Certbot
TCLI_SERVERSETUP_CERTBOT_EMAIL=$(yq eval ".Server.certbotEmail" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_SERVERSETUP_CERTBOT_EMAIL = null ] && TCLI_SERVERSETUP_CERTBOT_EMAIL="admin@"
# Vendor TCLI_NGINXSETUP vars
TCLI_SERVERSETUP_NGINX_SETUP=$(yq eval ".NginxSetup.install" < $TCLI_SERVERSETUP_FILE_CONF)
TCLI_NGINXSETUP_PATH_CONF=$TCLI_SERVERSETUP_PATH_CONF
TCLI_NGINXSETUP_PATH_TEMP=$TCLI_SERVERSETUP_PATH_TEMP
TCLI_NGINXSETUP_PATH_WWW_BASE=$(yq eval ".NginxSetup.Paths.wwwBase" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_NGINXSETUP_PATH_WWW_BASE = null ] && TCLI_NGINXSETUP_PATH_WWW_BASE="/srv/www/"
TCLI_NGINXSETUP_PATH_SITES_AVAILABLE=$(yq eval ".NginxSetup.Paths.sitesAvailable" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE = null ] && TCLI_NGINXSETUP_PATH_SITES_AVAILABLE="/etc/nginx/sites-available/"
TCLI_NGINXSETUP_PATH_SITES_ENABLED=$(yq eval ".NginxSetup.Paths.sitesEnabled" < $TCLI_SERVERSETUP_FILE_CONF); [ $TCLI_NGINXSETUP_PATH_SITES_ENABLED = null ] && TCLI_NGINXSETUP_PATH_SITES_ENABLED="/etc/nginx/sites-enabled/"
[ ${TCLI_SERVERSETUP_NGINX_SETUP:-0} ] && . $TCLI_SERVERSETUP_PATH_VENDOR/Linux.NginxSetup/src/NginxSetup/setup.sh

if [ "$(yq eval ".Server.RemoteSetup" < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ]; then
	# Need root access if script is running on server we working on.
	[[ $EUID -ne 0 ]] && infoscreenfailed "This script must be run as root or runned localy with shh to server"
else
	TCLI_SERVERSETUP_SERVERIP=$(yq eval ".Server.RemoteSetup.ip" < $TCLI_SERVERSETUP_FILE_CONF)
	nc -z -v -w5 $TCLI_SERVERSETUP_SERVERIP $TCLI_SERVERSETUP_SSHPORT || infoscreenfailed "Couldn't reach server at" "$TCLI_SERVERSETUP_SERVERIP : $TCLI_SERVERSETUP_SSHPORT" >&3
	TCLI_SERVERSETUP_ROMOTE_SERVER=1
	# TCLI_PKGS need this also
	TCLI_PACKMANAGER_REMOTE_SERVER=1
	TCLI_PACKMANAGER_REMOTE_SERVER_IP=$TCLI_SERVERSETUP_SERVERIP
	TCLI_PACKMANAGER_REMOTE_SERVER_PORT=$TCLI_SERVERSETUP_SSHPORT
fi
if [ -z ${SSHPASS} ]; then
	export SSHPASS=$(yq eval ".Server.RemoteSetup.sshRootPass" < $TCLI_SERVERSETUP_FILE_CONF)
fi
infoscreendone

################################################################################
# Alias for server connection after hardness server
################################################################################
tcli_serversetup_serverrootCmd() {
	[ ${TCLI_SERVERSETUP_SERVERIP:-} ] && ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP $@ # || $@
	# echo "ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS root@$TCLI_SERVERSETUP_SERVERIP $@"
}

tcli_serversetup_serverusercmd() {
	[ ${TCLI_SERVERSETUP_SERVERIP:-} ] && ssh -p $TCLI_SERVERSETUP_SSHPORT_HARDNESS $USERNAME@$TCLI_SERVERSETUP_SERVERIP $@ #|| su $USERNAME $@
}

################################################################################
# Prepare
################################################################################
tcli_serversetup_prepare () {
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
	infoscreen "SS install" "Update and upgrade OS"
	tcli_packageManager_system_update
	tcli_packageManager_system_upgrade
	case $DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install "sudo"
		;;
	"Ubuntu")
		tcli_packageManager_install "sudo"
		;;
	esac		
	ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "hostnamectl set-hostname $primaryHostname"
	infoscreendone
}

################################################################################
# Create a superuser
################################################################################
tcli_serversetup_create_user() {
	if [[ $EUID -eq 0 ]]; then
			return 1;
	fi
	local i=0
	until [ $i -lt 0 ]; do
		local s=$(yq eval ".Server.Users[$i]" < $TCLI_SERVERSETUP_FILE_CONF)
		if [ ! "$s" = null ]; then
			local username=$(yq eval ".Server.Users[$i].name" < $TCLI_SERVERSETUP_FILE_CONF)
			infoscreen "SS Setup" "Create user \"$username\""
			local passwordEncrypted=$(yq eval ".Server.Users[$i].passwordEncrypted" < $TCLI_SERVERSETUP_FILE_CONF)
			local superuser=$(yq eval ".Server.Users[$i].superuser" < $TCLI_SERVERSETUP_FILE_CONF)
			# validation
			[[ "$passwordEncrypted" = null || "$username" = null ]] && infoscreenwarn
			# create user
			if [ ! $(ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "id -u $username") &>/dev/null ]; then
				ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "useradd -m -p $passwordEncrypted -s /bin/bash $username"
				ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "usermod -a -G sudo $username"
				sshpass -e ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub $username@$TCLI_SERVERSETUP_SERVERIP
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

################################################################################
# Hardness Server part1
################################################################################
tcli_serversetup_hardness_server() {
	infoscreen "SS Setup" "Hardness server (only key access / no password)"
	# # Change sshd_config file and send to server
	sed "s/<sshport>/$TCLI_SERVERSETUP_SSHPORT_HARDNESS/g" $TCLI_SERVERSETUP_PATH_CONF/ssh/sshd_config > $TCLI_SERVERSETUP_PATH_TEMP/etc/ssh/sshd_config
	scp -P $TCLI_SERVERSETUP_SSHPORT $TCLI_SERVERSETUP_PATH_TEMP/etc/ssh/sshd_config root@$TCLI_SERVERSETUP_SERVERIP:/etc/ssh
	ssh -p $TCLI_SERVERSETUP_SSHPORT root@$TCLI_SERVERSETUP_SERVERIP "systemctl restart ssh.service"
	TCLI_PACKMANAGER_REMOTE_SERVER_PORT=$TCLI_SERVERSETUP_SSHPORT_HARDNESS
	infoscreendone
}

################################################################################
# Hardness Server part2 firewall
################################################################################
tcli_serversetup_hardness_server_firewall() {
	infoscreen "SS Setup" "Hardness server firewall nftables"
	tcli_serversetup_serverrootCmd "nft flush ruleset"
	tcli_serversetup_serverrootCmd "nft add table inet filter"
	tcli_serversetup_serverrootCmd "nft add chain inet filter input { type filter hook input priority 0 \; policy accept\;}"
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

################################################################################
# Cerbot
################################################################################
tcli_serversetup_cerbot_install() {
	infoscreen "SS Install" "Certbot"
	case $DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install "certbot"
		tcli_packageManager_install "python3-certbot-nginx"
		;;
	"Ubuntu")
		tcli_packageManager_install "certbot"
		tcli_packageManager_install "python3-certbot-nginx"
		;;
	esac		
	if [[ -f "$TCLI_SERVERSETUP_PATH_CONF/letsencrypt/$TCLI_SERVERSETUP_FILE_CERT_BACKUP" ]]; then
		scp -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS $TCLI_SERVERSETUP_PATH_CONF/letsencrypt/$TCLI_SERVERSETUP_FILE_CERT_BACKUP root@$TCLI_SERVERSETUP_SERVERIP:~/
		tcli_serversetup_serverrootCmd "tar -xvf ~/$TCLI_SERVERSETUP_FILE_CERT_BACKUP -C /"
	fi
	(crontab -l 2>/dev/null; echo "@daily certbot renew --quiet && systemctl reload postfix dovecot nginx") | tcli_serversetup_serverrootCmd "crontab -"
	infoscreendone
}

# param
#		<hostname>
tcli_serversetup_cerbot_add_certificate() {
		if tcli_serversetup_serverrootCmd "ls /etc/letsencrypt/live/$1"; then
			echo "Reinstalling certificate for $1"
			tcli_serversetup_serverrootCmd "certbot --reinstall --agree-tos --no-eff-email --email $TCLI_SERVERSETUP_CERTBOT_EMAIL --nginx -d $1"
		else
			echo "Creating certificate for $1"
			tcli_serversetup_serverrootCmd "certbot certonly -a nginx --agree-tos --no-eff-email --staple-ocsp --email $TCLI_SERVERSETUP_CERTBOT_EMAIL -d $1"
		fi
}

################################################################################
# Nginx
################################################################################
tcli_serversetup_nginx_install() {
	infoscreen "SS Install" "Nginx"
	tcli_nginxsetup_remote $TCLI_SERVERSETUP_SERVERIP $TCLI_SERVERSETUP_SSHPORT_HARDNESS
	tcli_nginxsetup_install
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 80 accept"
	tcli_serversetup_serverrootCmd "nft add rule inet filter input tcp dport 443 accept"

	if [[ -f "$TCLI_SERVERSETUP_PATH_CONF/nginx/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP" ]]; then
		scp -P $TCLI_SERVERSETUP_SSHPORT_HARDNESS $TCLI_SERVERSETUP_PATH_CONF/letsencrypt/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP root@$TCLI_SERVERSETUP_SERVERIP:~/
		tcli_serversetup_serverrootCmd "tar -xvf ~/$TCLI_SERVERSETUP_FILE_NGINX_SITES_CONF_BACKUP -C /"
	fi	

	declare -i c=$(yq e '.NginxSetup.WebSites | length' < $TCLI_SERVERSETUP_FILE_CONF)
	for (( i=0; i < $c; i++ )); do
		declare s=$(yq eval ".NginxSetup.WebSites[$i]" < $TCLI_SERVERSETUP_FILE_CONF)
		declare domainName=$(yq eval ".NginxSetup.WebSites[$i].domainName" < $TCLI_SERVERSETUP_FILE_CONF)
		declare siteType=$(yq eval ".NginxSetup.WebSites[$i].siteType" < $TCLI_SERVERSETUP_FILE_CONF)
		printf "\n\n$i setting up website $domainName as a $siteType\n\n"
		tcli_nginxsetup_add_domain $domainName $siteType
		tcli_serversetup_cerbot_add_certificate $domainName
	done
	infoscreendone
}

################################################################################
# PostgreSQL 
################################################################################
install_postgresql() {
	infoscreen "SS Install" "PostgreSQL"
	case $DISTRIBUTION_ID in
	"Debian GNU/Linux")
		tcli_packageManager_install "postgresql postgresql-contrib"
		tcli_serversetup_serverrootCmd "systemctl start postgresql"
		tcli_serversetup_serverrootCmd "systemctl enable postgresql"
		;;
	"Ubuntu")
		tcli_packageManager_install "postgresql postgresql-contrib"
		tcli_serversetup_serverrootCmd "systemctl start postgresql"
		tcli_serversetup_serverrootCmd "systemctl enable postgresql"
		;;
	esac	
	infoscreendone
}

tcli_serversetup_prepare
tcli_serversetup_create_user
tcli_serversetup_hardness_server
tcli_serversetup_hardness_server_firewall
tcli_serversetup_cerbot_install
[ $TCLI_SERVERSETUP_NGINX_SETUP ] && tcli_serversetup_nginx_install
[ "$(yq eval ".PostgreSql.install" < $TCLI_SERVERSETUP_FILE_CONF)" == "null" ] || install_postgresql
