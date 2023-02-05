#!/bin/bash

################################################################################
# Privamy hostname.
################################################################################
PRIMARY_HOSTNAME="examble.com" # CHANGE ME

################################################################################
# User
################################################################################
#USERNAME='<username>'
USERNAME=$(whoami)
# How to get encrypted password
# Encrypt password for user - python3 -c 'import crypt; print(crypt.crypt("secret", "salt"))'
USERPASSWORD_ENCRYPTED='saHW9GdxihkGQ' # CHANGE ME

################################################################################
# Server
################################################################################
# TODO SERVER_REMOTE_SETUP=0 # running script at server.
SERVER_REMOTE_SETUP=1
SERVERIP=161.97.108.95
export SSHPASS='<clear password>'
SSHPORT=10233 # after hardness of server

################################################################################
# Postfix
################################################################################
POSTFIX_MAIL_NAME="mail.$PRIMARY_HOSTNAME" # CHANGE ME
#POSTFIX_MAILBOX_SIZE_LIMIT=10240000 # Default
POSTFIX_MAILBOX_SIZE_LIMIT=52428800

################################################################################
# Certbot
################################################################################
CERTBOT_EMAIL="user@$PRIMARY_HOSTNAME"

################################################################################
# Postfix admin
################################################################################
POSTFIX_ADMIN_VER='postfixadmin-3.3.13'
POSTFIX_ADMIN_PASSWORD="secret" # CHANGE ME

################################################################################
# Nginx Setup
# see more
# src/ServerSetup/vendor/Linux.NginxSetup/src/NginxSetup/conf/settings.default.sh 
################################################################################

# NGINXSETUP
# Used from other script that sources NginxSetup script
# 1 => install nginx and setup, 0=> don't install, setup homepages
NGINXSETUP=1

NGINXSETUP_CONF="$(dirname "$(realpath "${BASH_SOURCE}")")" 
NGINXSETUP_TEMP="$(realpath "${NGINXSETUP_CONF/../temp}")"
NGINXSETUP_WWW_BASE_PATH="/srv/www/"
NGINXSETUP_SITES_AVAILABLE_PATH="/etc/nginx/sites-available/"
NGINXSETUP_SITES_ENABLED_PATH="/etc/nginx/sites-enabled/"

# Domain names seperated woth a space
NGINX_DOMAIN_NAMES="test.example.com new.examle.com"
NGINX_DOMAIN_NAME_AND_ALIAS="example.com www.example.com"