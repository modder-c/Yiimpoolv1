#!/usr/bin/env bash
#########################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by Afiniel for Yiimpool use...
# This script is intended to be run like this:
#
# curl https://raw.githubusercontent.com/afiniel/yiimp_install_script/master/install.sh | bash
#
#########################################################

if [ -z "${TAG}" ]; then
	TAG=v2.3.4
fi

echo 'VERSION='"${TAG}"'' | sudo -E tee /etc/yiimpoolversion.conf >/dev/null 2>&1