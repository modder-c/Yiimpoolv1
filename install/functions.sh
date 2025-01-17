#!/bin/bash

##############################################
# YiimpPool Functions                        #
# Current Modified by Afiniel (2022-06-06)   #
# Updated by Afiniel (2024-01-17)            #
##############################################

source /etc/yiimpoolversion.conf

# Global variables
absolutepath=absolutepathserver
installtoserver=installpath
daemonname=daemonnameserver

#----------------------------------------
# Color Definitions
#----------------------------------------
ESC_SEQ="\x1b["
NC=${NC:-"\033[0m"}      # No Color
RED=$ESC_SEQ"31;01m"     # Red
GREEN=$ESC_SEQ"32;01m"   # Green
YELLOW=$ESC_SEQ"33;01m"  # Yellow
BLUE=$ESC_SEQ"34;01m"    # Blue
MAGENTA=$ESC_SEQ"35;01m" # Magenta
CYAN=$ESC_SEQ"36;01m"    # Cyan

#----------------------------------------
# Basic Utility Functions
#----------------------------------------
function spinner {
    local pid=$!
    local delay=0.35
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function hide_output {
    OUTPUT=$(mktemp)
    $@ &>$OUTPUT &
    spinner
    E=$?
    if [ $E != 0 ]; then
        echo
        echo FAILED: $@
        echo -----------------------------------------
        cat $OUTPUT
        echo -----------------------------------------
        exit $E
    fi
    rm -f $OUTPUT
}

#----------------------------------------
# Package Management Functions
#----------------------------------------
function apt_get_quiet {
    DEBIAN_FRONTEND=noninteractive hide_output sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" "$@"
}

function apt_install {
    PACKAGES=$@
    apt_get_quiet install $PACKAGES
}

function apt_update {
    sudo apt-get update
}

function apt_upgrade {
    hide_output sudo apt-get upgrade -y
}

function apt_dist_upgrade {
    hide_output sudo apt-get dist-upgrade -y
}

function apt_autoremove {
    hide_output sudo apt-get autoremove -y
}

function install_if_not_installed() {
    local package="$1"
    if ! command -v "$package" &>/dev/null; then
        echo "Installing $package..."
        apt_install "$package"
    else
        echo "$package is already installed."
    fi
}

function check_package_installed() {
    if ! dpkg -l | grep -q "^ii  $1"; then
        echo "Failed to install package: $1"
        return 1
    fi
}

#----------------------------------------
# Firewall Functions
#----------------------------------------
function ufw_allow {
    if [ -z "$DISABLE_FIREWALL" ]; then
        sudo ufw allow $1 >/dev/null
    fi
}

function restart_service {
    hide_output sudo service $1 restart
}

#----------------------------------------
# User Management Functions
#----------------------------------------
function create_user() {
    local username=$1
    local password=$2
    
    # Add user with more secure defaults
    sudo adduser ${username} --gecos "Yiimpool Admin,,,," --disabled-password
    echo "${username}:${password}" | sudo chpasswd
    
    # Add to sudo group and configure sudo access
    sudo usermod -aG sudo ${username}
    
    # Configure stronger sudo rules
    echo "# ${username} sudo configuration
${username} ALL=(ALL) NOPASSWD: /usr/bin/yiimpool
${username} ALL=(ALL) ALL" | sudo tee "/etc/sudoers.d/${username}" > /dev/null
    sudo chmod 440 "/etc/sudoers.d/${username}"
}

function setup_ssh_key() {
    local username=$1
    local ssh_key=$2
    
    sudo mkdir -p "/home/${username}/.ssh"
    sudo touch "/home/${username}/.ssh/authorized_keys"
    echo "$ssh_key" | sudo tee "/home/${username}/.ssh/authorized_keys" > /dev/null
    sudo chown -R "${username}:${username}" "/home/${username}/.ssh"
    sudo chmod 700 "/home/${username}/.ssh"
    sudo chmod 600 "/home/${username}/.ssh/authorized_keys"
}

function setup_yiimpool_command() {
    local username=$1
    
    echo '#!/bin/bash
cd ~/Yiimpoolv1/install
bash start.sh' | sudo tee /usr/bin/yiimpool > /dev/null
    sudo chmod 755 /usr/bin/yiimpool
}

function configure_storage() {
    if ! id -u $STORAGE_USER >/dev/null 2>&1; then
        sudo useradd -m $STORAGE_USER
    fi
    sudo mkdir -p $STORAGE_ROOT
    sudo chown $STORAGE_USER:$STORAGE_USER $STORAGE_ROOT
    sudo chmod 750 $STORAGE_ROOT
}

#----------------------------------------
# Network Functions
#----------------------------------------
function get_publicip_from_web_service {
    curl -$1 --fail --silent --max-time 15 icanhazip.com 2>/dev/null
}

function get_default_privateip {
    local target=8.8.8.8
    if [ "$1" == "6" ]; then 
        target=2001:4860:4860::8888
    fi

    local route=$(ip -$1 -o route get $target | grep -v unreachable)
    local address=$(echo $route | sed "s/.* src \([^ ]*\).*/\1/")

    if [[ "$1" == "6" && $address == fe80:* ]]; then
        local interface=$(echo $route | sed "s/.* dev \([^ ]*\).*/\1/")
        address=$address%$interface
    fi

    echo $address
}

#----------------------------------------
# Dialog/UI Functions
#----------------------------------------
function message_box {
    dialog --title "$1" --msgbox "$2" 0 0
}

function input_box {
    declare -n result=$4
    declare -n result_code=$4_EXITCODE
    result=$(dialog --stdout --title "$1" --inputbox "$2" 0 0 "$3")
    result_code=$?
}

function input_menu {
    declare -n result=$4
    declare -n result_code=$4_EXITCODE
    local IFS=^$'\n'
    result=$(dialog --stdout --title "$1" --menu "$2" 0 0 0 $3)
    result_code=$?
}

#----------------------------------------
# Installation Functions
#----------------------------------------
function package_compile_crypto {
    echo -e "$MAGENTA => Installing needed Package to compile crypto currency <= ${NC}"

    # Core build dependencies
    hide_output sudo apt -y install software-properties-common build-essential
    hide_output sudo apt -y install libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils git cmake libboost-all-dev zlib1g-dev libz-dev libseccomp-dev libcap-dev libminiupnpc-dev gettext
    
    # Additional dependencies
    hide_output sudo apt -y install libminiupnpc10 libzmq5
    hide_output sudo apt -y install libcanberra-gtk-module libqrencode-dev libzmq3-dev
    hide_output sudo apt -y install libqt5gui5 libqt5core5a libqt5webkit5-dev libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler
    
    # Bitcoin repository and dependencies
    hide_output sudo add-apt-repository -y ppa:bitcoin/bitcoin
    hide_output sudo apt update
    hide_output sudo apt -y install libdb4.8-dev libdb4.8++-dev libdb5.3 libdb5.3++
    
    # Additional build tools
    hide_output sudo apt -y install bison libbison-dev
    hide_output sudo apt -y install libnatpmp-dev libnatpmp1 libqt5waylandclient5 libqt5waylandcompositor5 qtwayland5 systemtap-sdt-dev
    
    # Comprehensive crypto dependencies
    hide_output sudo apt -y install libgmp-dev libunbound-dev libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev libexpat1-dev \
    libpgm-dev libhidapi-dev libusb-1.0-0-dev libudev-dev libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev \
    libboost-locale-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev libboost-system-dev libboost-thread-dev \
    python3 ccache doxygen graphviz default-libmysqlclient-dev libnghttp2-dev librtmp-dev libssh2-1 libssh2-1-dev libldap2-dev libidn11-dev libpsl-dev
}

function daemonbuiler_files {
    echo -e "$YELLOW Copy => Copy Daemonbuilder files.  <= ${NC}"
    cd $HOME/Yiimpoolv1
    sudo mkdir -p /etc/utils/daemon_builder
    sudo cp -r utils/start.sh $HOME/utils/daemon_builder
    sudo cp -r utils/menu.sh $HOME/utils/daemon_builder
    sudo cp -r utils/menu2.sh $HOME/utils/daemon_builder
    sudo cp -r utils/menu3.sh $HOME/utils/daemon_builder
    sudo cp -r utils/source.sh $HOME/utils/daemon_builder
    sudo cp -r utils/upgrade.sh $HOME/utils/daemon_builder
    
    echo '#!/usr/bin/env bash
    source /etc/functions.sh
    cd $STORAGE_ROOT/daemon_builder
    bash start.sh
    cd ~' | sudo -E tee /usr/bin/daemonbuilder >/dev/null 2>&1
    sudo chmod +x /usr/bin/daemonbuilder
    echo -e "$GREEN => Complete${NC}"
    sleep 2
}

#----------------------------------------
# Display Functions
#----------------------------------------
function term_art() {
    clear
    local num_cols=$(tput cols)
    local half_cols=$((num_cols / 2))
    local box_width=40
    local offset=$(( (num_cols - box_width) / 2 )) 

    if [ "$offset" -lt 0 ]; then
        offset=0
    fi

    printf "%${offset}s" " "
    echo -e "${BOLD_YELLOW}╔══════════════════════════════════════════╗${NC}"
    printf "%${offset}s" " "
    echo -e "${BOLD_YELLOW}║${NC}          ${BOLD_CYAN}Yiimp Installer Script${NC}          ${BOLD_YELLOW}║${NC}"
    printf "%${offset}s" " "
    echo -e "${BOLD_YELLOW}║${NC}            ${BOLD_CYAN}Fork By Afiniel!${NC}              ${BOLD_YELLOW}║${NC}"
    printf "%${offset}s" " "
    echo -e "${BOLD_YELLOW}╚══════════════════════════════════════════╝${NC}"

    echo
    center_text "Welcome to the Yiimp Installer!"
    echo
    echo -e "${BOLD_CYAN}This script will install:${NC}"
    echo
    echo -e "  ${GREEN}•${NC} MySQL for database management"
    echo -e "  ${GREEN}•${NC} Nginx web server with PHP for Yiimp operation"
    echo -e "  ${GREEN}•${NC} MariaDB as the database backend"
    echo
    echo -e "${BOLD_CYAN}Version:${NC} ${GREEN}${VERSION:-"unknown"}${NC}"
    echo
}

function term_yiimpool {
    clear
    figlet -f slant -w 100 "YiimpooL" | lolcat -p 0.12 -s 50
    echo -e "${YIIMP_CYAN}  ----------------|---------------------  "
    echo -e "${YIIMP_YELLOW}  Yiimp Installer Script Fork By Afiniel!  "
    echo -e "${YIIMP_YELLOW}  Version: ${YIIMP_GREEN}$VERSION                   "
    echo -e "${YIIMP_CYAN}  ----------------|---------------------  "
    echo
}

function install_end_message() {
    clear
    figlet -f slant -w 100 "Success"
    echo -e "${BOLD_GREEN}**Yiimp Version:**${NC} $VERSION"
    echo
    echo -e "${BOLD_CYAN}**Database Information:**${NC}"
    echo "  - Login credentials are saved securely in ~/.my.cnf"
    echo
    echo -e "${BOLD_CYAN}**Pool and Admin Panel Access:**${NC}"
    echo "  - Pool: http://$server_name"
    echo "  - Admin Panel: http://$server_name/site/AdminPanel"
    echo "  - phpMyAdmin: http://$server_name/phpmyadmin"
    echo
    echo -e "${BOLD_CYAN}**Customization:**${NC}"
    echo "  - To modify the admin panel URL (currently set to '$admin_panel'):"
    echo "    - Edit ${BOLD_YELLOW}/var/web/yaamp/modules/site/SiteController.php${NC}"
    echo "    - Update line 11 with your desired URL"
    echo
    echo -e "${BOLD_CYAN}**Security Reminders:**${NC}"
    echo "  - Update public keys and wallet addresses in ${BOLD_YELLOW}/var/web/serverconfig.php${NC}"
    echo "  - Replace placeholder private keys in ${BOLD_YELLOW}/etc/yiimp/keys.php${NC} with your actual keys"
    echo "    - ${RED}Never share your private keys with anyone!${NC}"
    echo
    echo -e "${BOLD_YELLOW}**Next Steps:**${NC}"
    echo "  1. Reboot your server to finalize the installation process. ( ${RED}reboot${NC} )"
    echo "  2. Secure your installation by following best practices for server security."
    echo
    echo "Thank you for using the Yiimp Installer Script Fork by Afiniel!"
}

function print_message_yiimpool_end() {
    echo -e "${YIIMP_HEADER}"
    echo -e "${YIIMP_GREEN}Thanks for using Yiimpool Installer ${YIIMP_BLUE}${VERSION}${YIIMP_GREEN} (by Afiniel!)!${YIIMP_RESET}"
    echo
    echo -e "${YIIMP_BLUE}To run this installer anytime, simply type: ${YIIMP_GREEN}yiimpool${YIIMP_RESET}"
    echo -e "${YIIMP_HEADER}"
    echo -e "${YIIMP_BLUE}Like the installer and want to support the project? Use these wallets:"
    echo -e "${YIIMP_HEADER}"
    echo -e "${YIIMP_WHITE}- BTC: ${BTCDON}"
    echo -e "${YIIMP_WHITE}- BCH: ${BCHDON}"
    echo -e "${YIIMP_WHITE}- ETH: ${ETHDON}"
    echo -e "${YIIMP_WHITE}- DOGE: ${DOGEDON}"
    echo -e "${YIIMP_WHITE}- LTC: ${LTCDON}"
    echo -e "${YIIMP_HEADER}"
    echo
    echo -e "${YIIMP_GREEN}Yiimp installation is now ${YIIMP_GREEN}complete!${YIIMP_RESET}"
    echo -e "${YIIMP_YELLOW}Please REBOOT your machine to finalize updates and set folder permissions.${YIIMP_YELLOW} YiiMP won't function until a reboot is performed.${YIIMP_RESET}"
    echo
    echo -e "${YIIMP_BLUE}After the first reboot, it may take up to 1 minute for the ${YIIMP_GREEN}main${YIIMP_BLUE}|${YIIMP_GREEN}loop2${YIIMP_BLUE}|${YIIMP_GREEN}blocks${YIIMP_BLUE}|${YIIMP_GREEN}debug${YIIMP_BLUE} screens to start."
    echo -e "${YIIMP_BLUE}If they show ${YIIMP_RED}stopped${YIIMP_BLUE} after 1 minute, type ${YIIMP_GREEN}motd${YIIMP_BLUE} to refresh the screen.${YIIMP_RESET}"
    echo
    echo -e "${YIIMP_BLUE}Access your ${YIIMP_GREEN}${AdminPanel} at ${YIIMP_BLUE}http://${DomainName}/site/${AdminPanel}${YIIMP_RESET}"
    echo
    echo -e "${YIIMP_RED}By default, all stratum ports are blocked by the firewall.${YIIMP_YELLOW} To allow a port, use ${YIIMP_GREEN}sudo ufw allow <port number>${YIIMP_YELLOW} from the command line.${YIIMP_RESET}"
    echo -e "${YIIMP_WHITE}Database usernames and passwords can be found in ${YIIMP_RED}$STORAGE_ROOT/yiimp/.my.cnf${YIIMP_RESET}"
}

function ask_reboot() {
    read -p "Do you want to reboot the system? (y/n): " reboot_choice
    if [[ "$reboot_choice" == "y" ]]; then
        sudo reboot
    fi
}

function last_words() {
    echo "<-------------------------------------|---------------------------------------->"
    echo
    echo -e "$YELLOW Thank you for using the Yiimpool Installer $GREEN $VERSION             ${NC}"
    echo
    echo -e "$YELLOW To run this installer anytime simply type: $GREEN yiimpool            ${NC}"
    echo -e "$YELLOW Donations for continued support of this script are welcomed at:       ${NC}"
    echo "<-------------------------------------|--------------------------------------->"
    echo -e "$YELLOW                     Donate Wallets:                                   ${NC}"
    echo "<-------------------------------------|--------------------------------------->"
    echo -e "$YELLOW =>  BTC:$GREEN $BTCDON                                   		 ${NC}"
    echo -e "$YELLOW =>  BCH:$GREEN $BCHDON                                   		 ${NC}"
    echo -e "$YELLOW =>  ETH:$GREEN $ETHDON                                   		 ${NC}"
    echo -e "$YELLOW =>  DOGE:$GREEN $DOGEDON                                 		 ${NC}"
    echo -e "$YELLOW =>  LTC:$GREEN $LTCDON                                   		 ${NC}"
    echo "<-------------------------------------|-------------------------------------->"
    exit 0
}
