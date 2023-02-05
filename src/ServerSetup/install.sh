#!/bin/bash
IFS=$'\n\t'

# Setting some path
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r DIR_CONF="$( cd "$DIR/conf" && pwd )"
declare -r DIR_TOOLS="$( cd "$DIR/tools" && pwd )"

[ ! -d "$DIR/log" ] && mkdir "$DIR/log"
rm $DIR/log/*.*
declare -r FILE_LOG="$( cd "$DIR/log" && pwd )/$$.log"

exec 3>&1 1>>${FILE_LOG} 2>&1

printf "################################################################################\n" 1>&3
printf "#                            Linux Server Setup                                #\n" 1>&3
printf "#                         SS => Server Side action                             #\n" 1>&3
printf "################################################################################\n" 1>&3

. $DIR/vendor/Linux.Distribution/src/Distribution/distribution.sh
. $DIR_TOOLS/functions.sh
. $DIR_TOOLS/precheck.sh

rm -fr $DIR/temp/
mkdir -p $DIR/temp/etc/dovecot/conf.d
mkdir $DIR/temp/etc/nginx
mkdir $DIR/temp/etc/postfix
mkdir $DIR/temp/etc/ssh

if [ ! -f "$DIR_CONF/settings.sh" ]; then
    infoscreen "Loading" "Default configuration file"
    . $DIR_CONF/default.settings.sh
    infoscreendone
else
    infoscreen "Loading" "Custom configuration file"
    . $DIR_CONF/settings.sh
    infoscreendone
fi

[ ${NGINXSETUP:-0} ] && . $DIR/vendor/Linux.NginxSetup/src/NginxSetup/setup.sh

if [ ! ${SERVER_REMOTE_SETUP:-} ]; then
    # Need root access if script is running at server

    # check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root or runned localy with shh to server"
        exit
    fi    
fi

################################################################################
# Alias for server connection after hardness server
################################################################################
serverrootcmd() {
    [ ${SERVER_REMOTE_SETUP:-} ] && ssh -p $SSHPORT root@$SERVERIP $@ || $@
}

serverusercmd() {
    [ ${SERVER_REMOTE_SETUP:-} ] && ssh -p $SSHPORT $USERNAME@$SERVERIP $@ || su $USERNAME $@
}

################################################################################
# Prepare
################################################################################
prepare () {
    printf "\n\nPrepare ...\n"
    # We need sshpass
    if ! (which sshpass >/dev/null)
    then
        if ! (sudo apt-get install sshpass)
        then
            echo "sshpass need to be installed"
            exit 1
        fi
    fi

    # Delete old known host
    ssh-keygen -f "$LOCAL_USER_HOME_DIR/.ssh/known_hosts" -R "$SERVERIP"
    ssh-keygen -f "$LOCAL_USER_HOME_DIR/.ssh/known_hosts" -R "[$SERVERIP]:$SSHPORT"

    # Get passwordless root access
    sshpass -p $SSHPASS ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$SERVERIP

    # Update and Upgrade
    infoscreen "SS install" "Update and upgrade OS"
    ssh root@$SERVERIP "apt-get update && apt-get -y upgrade"
    infoscreenstatus $?
    ssh root@$SERVERIP "apt-get -y install sudo" # TODO PackageManager
    ssh root@$SERVERIP "hostnamectl set-hostname $PRIMARY_HOSTNAME"
}

################################################################################
# Create a superuser
################################################################################
create_user() {
    if [[ $EUID -eq 0 ]]; then
        return 1;
    fi
    infoscreen "SS Setup" "Create user \"$USERNAME\""
    # Create a user
    ssh root@$SERVERIP "useradd -m -p $USERPASSWORD_ENCRYPTED -s /bin/bash $USERNAME"
    ssh root@$SERVERIP "usermod -a -G sudo $USERNAME"

    # Passwordless user access
    sshpass -e ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub $USERNAME@$SERVERIP
    infoscreendone
}

################################################################################
# Hardness Server
################################################################################
hardness_server() {
    infoscreen "SS Setup" "Hardness server (only key access / no password)"
    # Change sshd_config file and send to server
    sed "s/<sshport>/$SSHPORT/g" $DIR_CONF/ssh/sshd_config > $DIR/temp/etc/ssh/sshd_config
    scp $DIR/temp/etc/ssh/sshd_config root@$SERVERIP:/etc/ssh
    ssh root@$SERVERIP "systemctl restart ssh.service"
    infoscreendone
    infoscreen "SS Setup" "Hardness server firewall nftables"
    serverrootcmd "nft flush ruleset"
    serverrootcmd "nft add table inet filter"
    serverrootcmd "nft add chain inet filter input { type filter hook input priority 0 \; policy accept\;}"
    # allow established/related connections
    serverrootcmd "nft add rule inet filter input ct state established,related accept"
    # early drop of invalid connections
    serverrootcmd "nft add rule inet filter input ct state invalid drop"
    # allow from loopback
    serverrootcmd "nft add rule inet filter input iifname lo accept"
    serverrootcmd "nft add rule inet filter input iif != \"lo\" ip daddr 127.0.0.0/8 drop"
    # allow icmp
    serverrootcmd "nft add rule inet filter input ip protocol icmp limit rate 4/second accept"
    serverrootcmd "nft add rule inet filter input ip6 nexthdr icmpv6 limit rate 4/second accept"
    serverrootcmd "nft add rule inet filter input tcp dport $SSHPORT accept"
    serverrootcmd "nft add chain inet filter forward { type filter hook forward priority 0 \; policy accept\; }"
    serverrootcmd "nft add chain inet filter output { type filter hook output priority 0 \; policy accept\; }"
    serverrootcmd "nft add chain inet filter input '{ policy drop; }'"
    infoscreendone
}

################################################################################
# Nginx
################################################################################
install_nginx() {
    infoscreen "SS Install" "Nginx"
    nginxsetup_remote 1 serverrootcmd
    nginxsetup_install
    [ ! -z $NGINX_DOMAIN_NAMES ] && nginxsetup_add_domain $NGINX_DOMAIN_NAMES
    # serverrootcmd "nft add rule inet filter input tcp dport 80 accept"
    # serverrootcmd "nft add rule inet filter input tcp dport 443 accept"
    infoscreendone
}

################################################################################
# Cerbot
################################################################################
install_certbot() {
    infoscreen "SS Install" "Certbot"
    serverrootcmd "apt-get -y install certbot"
    serverrootcmd "apt-get -y install python3-certbot-nginx"
    if [[ -d "$DIR_CONF/letsencrypt/live" ]]; then
        scp -r -P $SSHPORT $DIR_CONF/letsencrypt/* root@$SERVERIP:/etc/letsencrypt/
    fi
    (2>/dev/null crontab -l ; echo "@daily certbot renew --quiet && systemctl reload postfix dovecot nginx") | crontab -
    infoscreendone
}

################################################################################
# PostgreSQL 
################################################################################
install_postgresql() {
    infoscreen "SS Install" "PostgreSQL"
    serverrootcmd "apt-get -y install postgresql postgresql-contrib"
    serverrootcmd "systemctl start postgresql"
    serverrootcmd "systemctl enable postgresql"
    infoscreendone
}

################################################################################
# Postfix
################################################################################
install_postfix() {
	infoscreen "SS Install" "Postfix"
	# Get a certificate using certbot
	[ -d $DIR/temp/etc/nginx/sites-available ] || mkdir -p $DIR/temp/etc/nginx/sites-available
	cp $DIR_CONF/nginx/sites-available/mail_server.default $DIR/temp/etc/nginx/sites-available/$POSTFIX_MAIL_NAME
	sed -i "s/<POSTFIX_MAIL_NAME>/$POSTFIX_MAIL_NAME/g" $DIR/temp/etc/nginx/sites-available/$POSTFIX_MAIL_NAME
	scp -P $SSHPORT $DIR/temp/etc/nginx/sites-available/$POSTFIX_MAIL_NAME root@$SERVERIP:/etc/nginx/sites-available/$POSTFIX_MAIL_NAME
	serverrootcmd "ln -s /etc/nginx/sites-available/$POSTFIX_MAIL_NAME /etc/nginx/sites-enabled/"
	serverrootcmd "systemctl reload nginx"
	if [[ ! -d $DIR_CONF/letsencrypt/live/$POSTFIX_MAIL_NAME ]]; then
			# serverrootcmd "certbot certonly -a nginx --agree-tos --no-eff-email --staple-ocsp --email $CERTBOT_EMAIL -d $POSTFIX_MAIL_NAME"
			echo "TODO"
	fi
	# install postfix
	serverrootcmd "echo \"postfix	postfix/mailname string $POSTFIX_MAIL_NAME\" | debconf-set-selections"
	serverrootcmd "echo \"postfix postfix/main_mailer_type string 'Internet Site'\" | debconf-set-selections"
	serverrootcmd "DEBIAN_FRONTEND=noninteractive apt-get -y install postfix"
	infoscreendone

	infoscreen "SS Config" "Postfix"
	# nft accept port 25, 465,587 so Postfix can receive emails from other SMTP servers
	serverrootcmd "nft add rule inet filter input tcp dport 25 accept"
	serverrootcmd "nft add rule inet filter input tcp dport 465 accept"
	serverrootcmd "nft add rule inet filter input tcp dport 587 accept"
	serverrootcmd "nft add rule inet filter output tcp dport 25 accept"
	serverrootcmd "nft add rule inet filter output tcp dport 465 accept"
	serverrootcmd "nft add rule inet filter output tcp dport 587 accept"
	# nft accept imaps
	serverrootcmd "nft add rule inet filter input tcp dport 143 accept"
	serverrootcmd "nft add rule inet filter input tcp dport 993 accept"
	# Increase Attachment Size Limit 50mb instead of 10mb
	serverrootcmd "postconf -e message_size_limit=$POSTFIX_MAILBOX_SIZE_LIMIT"
	serverrootcmd "systemctl reload postfix"
	infoscreendone
}

################################################################################
# Dovecot
################################################################################
install_dovecot() {
    infoscreen "SS Install" "Dovecot"
    serverrootcmd "apt-get -y install dovecot-core dovecot-imapd dovecot-lmtpd"
    infoscreendone
    
    infoscreen "SS Config" "Dovecot"
    serverrootcmd "adduser dovecot mail"
    sed "s/<POSTFIX_MAIL_NAME>/$POSTFIX_MAIL_NAME/g" $DIR_CONF/dovecot/conf.d/10-ssl.conf > $DIR/temp/etc/dovecot/conf.d/10-ssl.conf
    cp $DIR_CONF/dovecot/dovecot.conf $DIR/temp/etc/dovecot/
    cp $DIR_CONF/dovecot/conf.d/10-auth.conf $DIR/temp/etc/dovecot/conf.d/
    cp $DIR_CONF/dovecot/conf.d/10-mail.conf $DIR/temp/etc/dovecot/conf.d/
    cp $DIR_CONF/dovecot/conf.d/10-master.conf $DIR/temp/etc/dovecot/conf.d/
    scp -r -P $SSHPORT $DIR/temp/etc/dovecot root@$SERVERIP:/etc/
    # serverrootcmd "systemctl restart dovecot" #TODO
    infoscreendone
}

################################################################################
# Postfix admin
################################################################################
install_postfix_admin() {
    infoscreen "SS Config" "Dovecot"
    serverrootcmd "mkdir -p /srv/www/postfixadmin"
    serverrootcmd "wget https://github.com/postfixadmin/postfixadmin/archive/$POSTFIX_ADMIN_VER.tar.gz"
    serverrootcmd "tar -xf $POSTFIX_ADMIN_VER.tar.gz -C /srv/www/"
    serverrootcmd "mv /srv/www/postfixadmin-$POSTFIX_ADMIN_VER /srv/www/postfixadmin"
    serverrootcmd "mkdir -p /srv/www/postfixadmin/templates_c"
    serverrootcmd "apt-get -y install acl"
    serverrootcmd "setfacl -R -m u:www-data:rwx /srv/www/postfixadmin/templates_c/"
    serverrootcmd "setfacl -R -m u:www-data:rx /etc/letsencrypt/live/ /etc/letsencrypt/archive/"
    
    serverrootcmd "su postgres <<EOF
    psql -c \"CREATE DATABASE postfixadmin;\"
    psql -c \"CREATE USER postfixadmin WITH PASSWORD $POSTFIX_ADMIN_PASSWORD;\"
    psql -c \"ALTER DATABASE postfixadmin OWNER TO postfixadmin;\"
    psql -c \"GRANT ALL PRIVILEGES ON DATABASE postfixadmin TO postfixadmin;\"
    EOF"

    infoscreendone
}

################################################################################
# 
################################################################################

prepare
create_user
hardness_server
[ ${NGINXSETUP:-0} ] && install_nginx || printf "\nFailed to setup nginx\n"
# install_certbot
# install_postgresql
# install_postfix
# install_dovecot
# install_postfix_admin

# serverrootcmd "nft list ruleset > /etc/nftables.conf"
# serverrootcmd "systemctl enable nftables.service"
# serverrootcmd "systemctl restart nftables.service"

unset SSHPASS
printf "################################################################################\n" 1>&3
printf "#                                    Finish                                    #\n" 1>&3
printf "################################################################################\n" 1>&3
