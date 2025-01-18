#####################################################
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by Afiniel
#####################################################

if [ "`lsb_release -d | sed 's/.*:\s*//' | sed 's/18\.04\.[0-9]/18.04/' `" == "Ubuntu 18.04 LTS" ]; then
  DISTRO=18
  sudo chmod g-w /etc /etc/default /usr
else [ "`lsb_release -d | sed 's/.*:\s*//' | sed 's/16\.04\.[0-9]/16.04/' `" != "Ubuntu 16.04 LTS" ];
  DISTRO=16
fi

TOTAL_PHYSICAL_MEM=$(head -n 1 /proc/meminfo | awk '{print $2}')
if [ $TOTAL_PHYSICAL_MEM -lt 1436000 ]; then
  if [ ! -d /vagrant ]; then
    TOTAL_PHYSICAL_MEM_GB=$(awk "BEGIN {printf \"%.1f\", ${TOTAL_PHYSICAL_MEM}/1024/1024}")
    echo "Your Pool Server needs more memory (RAM) to function properly."
    echo "Please provision a machine with at least 1.5 GB, 6 GB recommended."
    echo "This machine has ${TOTAL_PHYSICAL_MEM_GB} GB memory."
    exit
  fi
fi

if [ $TOTAL_PHYSICAL_MEM -lt 1436000 ]; then
  TOTAL_PHYSICAL_MEM_GB=$(awk "BEGIN {printf \"%.1f\", ${TOTAL_PHYSICAL_MEM}/1024/1024}")
  echo "WARNING: Your Pool Server has less than 1.5 GB of memory."
  echo "It might run unreliably when under heavy load."
  echo "Current memory: ${TOTAL_PHYSICAL_MEM_GB} GB"
fi

# Check swap
echo Checking if swap space is needed and if so creating...

SWAP_MOUNTED=$(cat /proc/swaps | tail -n+2)
SWAP_IN_FSTAB=$(grep "swap" /etc/fstab)
ROOT_IS_BTRFS=$(grep "\/ .*btrfs" /proc/mounts)
TOTAL_PHYSICAL_MEM=$(head -n 1 /proc/meminfo | awk '{print $2}')
AVAILABLE_DISK_SPACE=$(df / --output=avail | tail -n 1)
if
  [ -z "$SWAP_MOUNTED" ] &&
  [ -z "$SWAP_IN_FSTAB" ] &&
  [ ! -e /swapfile ] &&
  [ -z "$ROOT_IS_BTRFS" ] &&
  [ $TOTAL_PHYSICAL_MEM -lt 1536000 ] &&
  [ $AVAILABLE_DISK_SPACE -gt 5242880 ]
then
  echo "Adding a swap file to the system..."

  # Allocate and activate the swap file. Allocate in 1KB chuncks
  # doing it in one go, could fail on low memory systems
  sudo fallocate -l 3G /swapfile
    if [ -e /swapfile ]; then
      sudo chmod 600 /swapfile
      hide_output sudo mkswap /swapfile
      sudo swapon /swapfile
      echo "vm.swappiness=10" >> sudo /etc/sysctl.conf
    fi
# Check if swap is mounted then activate on boot
  if swapon -s | grep -q "\/swapfile"; then
    echo "/swapfile  none swap sw 0  0" >> sudo /etc/fstab
  else
    echo "ERROR: Swap allocation failed!"
  fi
fi

ARCHITECTURE=$(uname -m)
if [ "$ARCHITECTURE" != "x86_64" ]; then
  if [ -z "$ARM" ]; then
    echo "${namescryptinstall} ${TAG} only supports x86_64 and will not work on any other architecture, like ARM or 32 bit OS."
    echo "Your architecture is $ARCHITECTURE"
    exit
  fi
fi

# Set STORAGE_USER and STORAGE_ROOT to default values (utils and /home/utils), unless
# we've already got those values from a previous run.
#if [ -z "$STORAGE_USER" ]; then
#  STORAGE_USER=$([[ -z "$DEFAULT_STORAGE_USER" ]] && echo "utils" || echo "$DEFAULT_STORAGE_USER")
#fi
#if [ -z "$STORAGE_ROOT" ]; then
#  STORAGE_ROOT=$([[ -z "$DEFAULT_STORAGE_ROOT" ]] && echo "/home/$STORAGE_USER" || echo "$DEFAULT_STORAGE_ROOT")
#fi