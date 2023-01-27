#!/bin/bash

################################################################################
# Privamy hostname.
################################################################################
PRIMARY_HOSTNAME="www.examble.com"

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
SERVERIP=161.97.108.95
export SSHPASS='<clear password>'
SSHPORT=10233 # after hardness of server

