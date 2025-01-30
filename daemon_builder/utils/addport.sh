#!/usr/bin/env bash

#####################################################
# Dedicated Port config generator
# Created by afiniel for yiimpool
# This generator will modify the main algo.conf file
# Create the new coin.algo.conf file
# And update the stratum start file
#####################################################

source /etc/yiimpool.conf
source /etc/yiimpooldonate.conf
source /etc/functions.sh
source /etc/daemonbuilder.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf
source $STORAGE_ROOT/daemon_builder/conf/info.sh

clear

# Generate random open PORT
function EPHYMERAL_PORT(){
    LPORT=2768;
    UPORT=6999;
    while true; do
        MPORT=$[$LPORT + ($RANDOM % $UPORT)];
        (echo "" >/dev/tcp/127.0.0.1/${MPORT}) >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo $MPORT;
            return 0;
        fi
    done
}

coinport=$(EPHYMERAL_PORT)

GETPORT="$1"

if [[ ("$GETPORT" == "CREATECOIN") ]]; then
	echo -e "$YELLOW Add port to coin:${NC} $GREEN $2 ${NC}"
	echo
	CREATECOIN="true"
fi

cd ${PATH_STRATUM}/config

echo -e "$YELLOW addport will randomly selects an open port for the coin between ports 2768 and 6999 and open the port in UFW. ${NC}"

if [[ ("$CREATECOIN" == "true") ]]; then
	coinsymbol="$2"
	coinalgo="$3"
else
	echo -e "$YELLOW Thanks for using the addport script by Afiniel. ${NC}"
	echo
	echo -e "$YELLOW It will also create a new symbol.algo.conf in $RED $STORAGE_ROOT/yiimp/site/stratum/config ${NC}"
	echo -e "$YELLOW and will create a new stratum.symbol run file in $RED /usr/bin. ${NC}"
	echo
	
	echo -e "$RED Make sure coin symbol is all UPPER case.${NC}"
	echo
	read -e -p "Please enter the coin SYMBOL : " coinsymbol
	echo
	
	if ! locale -a | grep en_US.utf8 > /dev/null; then
		sudo locale-gen en_US.UTF-8
	fi

	export LANGUAGE=en_US.UTF-8
	export LC_ALL=en_US.UTF-8
	export LANG=en_US.UTF-8
	export LC_TYPE=en_US.UTF-8
	export NCURSES_NO_UTF8_ACS=1
	
	convertlistalgos=$(find $STORAGE_ROOT/yiimp/site/stratum/config/ -mindepth 1 -maxdepth 1 -type f -not -name '.*' -not -name '*.sh' -not -name '*.log' -not -name 'stratum.*' -not -name '*.*.*' -iname '*.conf' -execdir basename -s '.conf' {} +);
	optionslistalgos=$(echo -e "${convertlistalgos}" | awk '{ printf "%s on\n", $1}' | sort | uniq | grep [[:alnum:]])

	DIALOGFORLISTALGOS=${DIALOGFORLISTALGOS=dialog}
	tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
	trap "rm -f $tempfile" 0 1 2 5 15

	$DIALOGFORLISTALGOS --colors --title "\Zb\Zr\Z7| Select the algorithm for coin: \Zn\ZR\ZB\Z0${coinsymbol^^}\Zn\Zb\Zr\Z7 |" --clear --colors --no-items --nocancel --shadow \
			--radiolist "\n\
	\ZB\Z1Hello, choose the algorithm for your coin\n\
	the list scrolls so you can use the \n\
	UP/DOWN arrow keys, the first letter of the choice as \n\
	hotkey or number keys 1-9 to choose an option. \n\
	Press SPACE to select an option.\Zn\n\n\
		What is your algorithm? choose from the following..." \
		55 60 47 $optionslistalgos 2> $tempfile
	retvalalgoselected=$?
	ALGOSELECTED=`cat $tempfile`
	case $retvalalgoselected in
	  0)
		coinalgo="${ALGOSELECTED}";;
	  1)
		echo "Cancel pressed."
		exit;;
	  255)
		echo "ESC pressed."
		exit;;
	esac
	clear
fi

echo ""

read -e -p "Would you like to set a minimum nicehash value for this stratum? (y/n) : " nicehash
if [[ ("$nicehash" == "y" || "$nicehash" == "Y" || "$nicehash" == "yes" || "$nicehash" == "YES") ]]; then
read -e -p "Please enter a whole value, example: 750000 : " nicevalue
fi

# Make the coin symbol lower case
coinsymbollower=${coinsymbol,,}
# make sure algo is lower as well since we are Here
coinalgo=${coinalgo}
# and might as well make sure the symbol is upper case
coinsymbol=${coinsymbol^^}

# Make sure the stratum.symbol config doesnt exist and that the algo file does.
if [ -f $STORAGE_ROOT/yiimp/site/stratum/config/stratum.${coinsymbollower} ]; then
	echo
	echo -e "$RED A file for ${coinsymbol} already exists. Are you sure you want to overwrite?"
	read -r -e -p " A new port will be generated and you will need to update your coind.conf blocknotify line (y/n) :" overwrite
	echo -e "${NC}"
	if [[ ("$overwrite" == "n" || "$overwrite" == "N" || "$overwrite" == "no" || "$overwrite" == "NO") ]]; then
		echo -e "$RED Exiting... ${NC}"
		echo
		exit 0
	fi
if [ ! -f $STORAGE_ROOT/yiimp/site/stratum/config/$coinalgo.conf ]; then
  echo -e "$YELLOW Sorry that algo config file doesn't exist in $RED $STORAGE_ROOT/yiimp/site/stratum/config/ $YELLOW please double check and try again. ${NC}"
  exit 0
fi
fi

# Prevent duplications from people running addport multiple times for the same coin...Also known as asshats...
if [ -f $STORAGE_ROOT/yiimp/site/stratum/config/$coinsymbollower.$coinalgo.conf ]; then
  if [[ ("$overwrite" == "y" || "$overwrite" == "Y" || "$overwrite" == "yes" || "$overwrite" == "YES") ]]; then
    # Insert the port in to the new symbol.algo.conf
    sudo sed -i '/port/c\port = '${coinport}'' $coinsymbollower.$coinalgo.conf
    echo -e "$YELLOW Port updated! Remeber to update your blocknotify line!! ${NC}"
  fi
else
# Since this is a new symbol we are going to add it to the other conf files first.
# First we need to check if this is the first time addport has been ran
files=(*.$coinalgo.conf)
if [ -e "${files[0]}" ]; then
for r in *.$coinalgo.conf; do
  if ! grep -Fxq "exclude = ${coinsymbol}" "$r"; then
    sudo sed -i -e '$a\
[WALLETS]\
exclude = '${coinsymbol}'' "$r"
fi
done
fi

# Copy the default algo.conf to the new symbol.algo.conf
sudo cp -r $coinalgo.conf $coinsymbollower.$coinalgo.conf
  
# Insert the port in to the new symbol.algo.conf
sudo sed -i '/port/c\port = '${coinport}'' $coinsymbollower.$coinalgo.conf
  
# If setting a nicehash value
if [[ ("$nicehash" == "y" || "$nicehash" == "Y" || "$nicehash" == "yes" || "$nicehash" == "YES") ]]; then
  sudo sed -i -e '/difficulty =/a\
nicehash = '${nicevalue}'' $coinsymbollower.$coinalgo.conf
fi

# Insert the include in to the new symbol.algo.conf
  sudo sed -i -e '$a\
[WALLETS]\
include = '${coinsymbol}'' $coinsymbollower.$coinalgo.conf
fi

#Again preventing asshat duplications...
if ! grep -Fxq "exclude = ${coinsymbol}" "$coinalgo.conf"; then
# Insert the exclude in to algo.conf
  sudo sed -i -e '$a\
[WALLETS]\
exclude = '${coinsymbol}'' $coinalgo.conf
else
  echo -e "$YELLOW ${coinsymbol} is already in $coinalgo.conf, skipping... Which means you are trying to run this multiple times for the same coin. ${NC}"
  echo
fi

# New coin stratum start file

echo '#####################################################
# Source code from https://codereview.stackexchange.com/questions/55077/small-bash-script-to-sta$
# Updated by Afiniel for Yiimpool use...
#####################################################
source /etc/yiimpool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
#!/usr/bin/env bash
'""''"${coinsymbollower}"''""'="screen -dmS '""''"${coinsymbollower}"''""' bash $STRATUM_DIR/run.sh '""''"${coinsymbollower}"''""'.'""''"${coinalgo}"''".conf"'"
'""''"${coinsymbollower}"''""'stop="'screen -X -S ${coinsymbollower} quit'"
startstop_'""''"${coinsymbollower}"''""'() {
    cmd=$1
    case $cmd in
        stop) $'""''"${coinsymbollower}"''""'stop ;;
        start) $'""''"${coinsymbollower}"''""' ;;
        restart)
            $'""''"${coinsymbollower}"''""'stop
            sleep 1
            $'""''"${coinsymbollower}"''""'
            ;;
    esac
}
case "$1" in
    start|stop|restart) cmd=$1 ;;
    *)
        shift
        servicenames=${@-servicenames}
        echo "usage: $0 [start|stop|restart] algo"
        exit 1
esac
shift
for name; do
    case "$name" in
    '""''"${coinsymbollower}"''""') startstop_'""''"${coinsymbollower}"''""' $cmd ;;
    *) startstop_service $cmd $name ;;
    esac
done ' | sudo -E tee $STORAGE_ROOT/yiimp/site/stratum/config/stratum.${coinsymbollower} >/dev/null 2>&1
sudo chmod +x $STORAGE_ROOT/yiimp/site/stratum/config/stratum.${coinsymbollower}

sudo cp -r $STORAGE_ROOT/yiimp/site/stratum/config/stratum.${coinsymbollower} /usr/bin
sudo ufw allow $coinport

echo
echo "Adding stratum.${coinsymbollower} to crontab for autostart at system boot."
(crontab -l 2>/dev/null; echo "@reboot sleep 10 && bash stratum.${coinsymbollower} start ${coinsymbollower}") | crontab -
echo
echo -e "$YELLOW Starting your new stratum...${NC}"
bash stratum.${coinsymbollower} start ${coinsymbollower}

if [[ ("$CREATECOIN" == "true") ]]; then
	echo '
	COINPORT='""''"${coinport}"''""'
	COINALGO='""''"${coinalgo}"''""'
	' | sudo -E tee $STORAGE_ROOT/daemon_builder/.addport.cnf >/dev/null 2>&1
	echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
	echo -e "$GREEN    The assigned dedicated port for this coins stratum is :$YELLOW $coinport ${NC}"
	echo -e "$GREEN    Addport finish return to config...										${NC}"
	echo -e "$CYAN --------------------------------------------------------------------------- 	${NC}"
	sleep 4
	exit 0
else
	echo -e "$YELLOW Your new stratum is$GREEN started...$YELLOW Do NOT run the start command manually...${NC}"
	echo
	echo -e "$YELLOW To use your new stratum type,$BLUE stratum.${coinsymbollower} start|stop|restart ${coinsymbollower} ${NC}"
	echo
	echo -e "$YELLOW To see the stratum screen type,$MAGENTA screen -r ${coinsymbollower} ${NC}"
	echo
	echo -e "$YELLOW The assigned dedicated port for this coins stratum is :$GREEN $coinport ${NC}"
	echo
	echo -e "$YELLOW The assigned algo for this coin stratum is :$GREEN $coinalgo ${NC}"
	echo	
	echo -e "$YELLOW Make sure to add this to the Dedicated Port section in your YiiMP admin panel! ${NC}"
	echo
	echo -e "$CYAN  --------------------------------------------------------------------------- 	${NC}"
	echo -e "$GREEN	Donations are welcome at wallets below:					  	${NC}"
	echo -e "$YELLOW  BTC: ${NC} $MAGENTA ${BTCDON}	${NC}"
	echo -e "$YELLOW  LTC: ${NC} $MAGENTA ${LTCDON}	${NC}"
	echo -e "$YELLOW  ETH: ${NC} $MAGENTA ${ETHDON}	${NC}"
	echo -e "$YELLOW  BCH: ${NC} $MAGENTA ${DOGEDON}	${NC}"
	echo -e "$CYAN  --------------------------------------------------------------------------- 	${NC}"
	echo
	cd ~
	exit 0
fi