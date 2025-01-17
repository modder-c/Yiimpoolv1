#!/usr/bin/env bash

#########################################
# Updated Server Cleanup Script         #
# Originally created by Afiniel         #
#########################################

source /etc/functions.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf
source /etc/yiimpooldonate.conf

# Define constants
YIIMP_DIR="$STORAGE_ROOT/yiimp"
SCREENS_DIR="$YIIMP_DIR/starts"
STRATUM_DIR="$YIIMP_DIR/site/stratum"
LOG_DIR="$YIIMP_DIR/site/log"
CRONS_DIR="$YIIMP_DIR/site/crons"

# Display header
term_art
print_message "$MAGENTA" "    <----------------------------->"
print_message "$MAGENTA" "     <--$YELLOW Starting Server Cleanup$MAGENTA -->"
print_message "$MAGENTA" "    <----------------------------->"
echo

print_message "$YELLOW" " => Installing cron screens to crontab <= "

# Add cron jobs with error checking
add_cron_job "@reboot sleep 20 && $SCREENS_DIR/screens.start.sh"
if [[ "$CoinPort" == "no" ]]; then
    add_cron_job "@reboot sleep 20 && $SCREENS_DIR/stratum.start.sh"
fi
add_cron_job "@reboot sleep 20 && /etc/screen-scrypt-daemonbuilder.sh"
add_cron_job "@reboot source /etc/functions.sh"
add_cron_job "@reboot source /etc/yiimpool.conf"

# Create screens startup script
print_message "$MAGENTA" "=> Creating YiiMP Screens startup script <="

cat > $SCREENS_DIR/screens.start.sh << 'EOL'
#!/usr/bin/env bash
source /etc/yiimpool.conf
source /etc/yiimpooldonate.conf
source /etc/functions.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf

# Check for first boot script
[[ -f "$STORAGE_ROOT/yiimp/first_boot.sh" ]] && source $STORAGE_ROOT/yiimp/first_boot.sh

################################################################################
# YiiMP screen startup script                                                   #
################################################################################

# Set proper permissions
sudo chmod 777 $STORAGE_ROOT/yiimp/site/log/.
sudo chmod 777 $STORAGE_ROOT/yiimp/site/log/debug.log

# Define directories
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons

# Start main screens
screen -wipe > /dev/null 2>&1  # Clean up any dead screens first
screen -dmS main bash $CRONS/main.sh
screen -dmS loop2 bash $CRONS/loop2.sh
screen -dmS blocks bash $CRONS/blocks.sh
screen -dmS debug tail -f $LOG_DIR/debug.log

# Add monitoring
echo "[$(date)] YiiMP screens started" >> $LOG_DIR/screens.log
EOL

chmod +x $SCREENS_DIR/screens.start.sh

# Create stratum startup script
print_message "$MAGENTA" "=> Creating Stratum screens start script <="

# Define complete algorithm list
ALGORITHMS=(
    '0x10' 'a5a' 'aergo' 'allium' 'anime' 'argon2' 'argon2d-dyn' 'argon2d16000'
    'argon2d250' 'argon2d4096' 'astralhash' 'aurum' 'balloon' 'bastion' 'bcd'
    'core' 'blake' 'blake2s' 'blakecoin' 'bmw512' 'c11' 'cosa' 'cpupower'
    'curvehash' 'decred' 'dedal' 'deep' 'dmd-gr' 'geek' 'globalhash' 'gr'
    'groestl' 'heavyhash' 'hex' 'hmq1725' 'honeycomb' 'hsr' 'jeonghash' 'jha'
    'keccak' 'keccakc' 'lbk3' 'lbry' 'luffa' 'lyra2' 'lyra2TDC' 'lyra2v2'
    'lyra2v3' 'lyra2vc0ban' 'lyra2z' 'lyra2z330' 'm7m' 'megabtx' 'megamec'
    'memehash' 'mike' 'minotaur' 'minotaurx' 'myr-gr' 'neoscrypt' 'nist5'
    'padihash' 'pawelhash' 'penta' 'phi' 'phi2' 'phi5' 'pipe' 'polytimos'
    'power2b' 'quark' 'qubit' 'rainforest' 'renesis' 'scrypt' 'scryptn'
    'sha256' 'sha256csm' 'sha256dt' 'sha256t' 'sha3d' 'sha512256d' 'sib'
    'skein' 'skein2' 'skunk' 'skydoge' 'sonoa' 'timetravel' 'tribus' 'vanilla'
    'veltor' 'velvet' 'vitalium' 'whirlpool' 'x11' 'x11evo' 'x11k' 'x11kvs'
    'x12' 'x13' 'x14' 'x15' 'x16r' 'x16rt' 'x16rv2' 'x16s' 'x17' 'x18' 'x20r'
    'x21s' 'x22i' 'x25x' 'xevan' 'yescrypt' 'yescryptR16' 'yescryptR32'
    'yescryptR8' 'yespower' 'yespowerARWN' 'yespowerIC' 'yespowerIOTS'
    'yespowerLITB' 'yespowerLTNCG' 'yespowerMGPC' 'yespowerR16' 'yespowerRES'
    'yespowerSUGAR' 'yespowerTIDE' 'yespowerURX' 'zr5'
)

# Generate stratum start script
cat > $SCREENS_DIR/stratum.start.sh << 'EOL'
#!/usr/bin/env bash
source /etc/yiimpool.conf
source /etc/yiimpooldonate.conf
source /etc/functions.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf

################################################################################
# YiiMP stratum startup script                                                  #
################################################################################

STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
LOG_DIR=$STORAGE_ROOT/yiimp/site/log

# Clean up any dead screens
screen -wipe > /dev/null 2>&1

# Function to start stratum
start_stratum() {
    local algo=$1
    if [ -f "$STRATUM_DIR/run.sh" ]; then
        screen -dmS "$algo" bash $STRATUM_DIR/run.sh "$algo"
        echo "[$(date)] Started $algo stratum" >> $LOG_DIR/stratum.log
    else
        echo "[$(date)] Error: Unable to start $algo stratum - run.sh not found" >> $LOG_DIR/stratum.log
    fi
}

EOL

# Add algorithm starts
for algo in "${ALGORITHMS[@]}"; do
    echo "start_stratum $algo" >> $SCREENS_DIR/stratum.start.sh
done

chmod +x $SCREENS_DIR/stratum.start.sh

# Create prescreen configuration
cat > $STORAGE_ROOT/yiimp/.prescreens.start.conf << EOL
source /etc/yiimpool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
EOL

# Update bashrc
echo "source /etc/yiimpool.conf" | hide_output tee -a ~/.bashrc
echo "source $STORAGE_ROOT/yiimp/.prescreens.start.conf" | hide_output tee -a ~/.bashrc

print_message "$YELLOW" "YiiMP Screens$GREEN Added"

# Cleanup
sudo rm -r $STORAGE_ROOT/yiimp/yiimp_setup

# Update web files
print_message "$YELLOW" "Updating web files..."
cd $HOME/Yiimpoolv1/yiimp_single/yiimp_confs
sudo cp -f main.php $YIIMP_DIR/site/web/yaamp/ui/
sudo cp -f coin_form.php $YIIMP_DIR/site/web/yaamp/modules/site/

cd $HOME/Yiimpoolv1/yiimp_single

print_message "$GREEN" "Server cleanup completed successfully!"