#!/bin/env bash

##################################################################################
# This is the entry point for configuring the system.                            #
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox   #
# Updated by Afiniel for yiimpool use...                                         #
##################################################################################

source /etc/yiimpoolversion.conf
source /etc/functions.sh
source /etc/yiimpool.conf

# Ensure Python reads/writes files in UTF-8. If the machine
# triggers some other locale in Python, like ASCII encoding,
# Python may not be able to read/write files. This is also
# in the management daemon startup script and the cron script.

if ! locale -a | grep en_US.utf8 > /dev/null; then
# Generate locale if not exists
hide_output locale-gen en_US.UTF-8
fi

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

# Fix so line drawing characters are shown correctly in Putty on Windows. See #744.
export NCURSES_NO_UTF8_ACS=1

# Create the temporary installation directory if it doesn't already exist.
if [ ! -d $STORAGE_ROOT/yiimp/yiimp_setup ]; then
    sudo mkdir -p $STORAGE_ROOT/{wallets,yiimp/{yiimp_setup/log,site/{web,stratum,configuration,crons,log},starts}}
    sudo touch $STORAGE_ROOT/yiimp/yiimp_setup/log/installer.log
fi

if [[ "$DISTRO" == "24" || "$DISTRO" == "23" || "$DISTRO" == "22" ]]; then
    sudo chmod 755 /home/crypto-data/
fi

# Start the installation.
source menu.sh
source questions.sh
source $HOME/Yiimpoolv1/yiimp_single/.wireguard.install.cnf

if [[ ("$wireguard" == "true") ]]; then
  source wireguard.sh
fi

source system.sh
source self_ssl.sh
source db.sh
source nginx_upgrade.sh
source web.sh
bash stratum.sh
source compile_crypto.sh
#source daemon.sh

# TODO: Fix the wiregard.
# To let users start us yiimp on multi servers.´

# if [[ ("$UsingDomain" == "yes") ]]; then
# source send_mail.sh
# fi

source server_cleanup.sh
source motd.sh
source server_harden.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf

clear
term_yiimpool
print_message_yiimpool_end
exit 0
ask_reboot
