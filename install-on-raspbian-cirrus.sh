#!/bin/bash

## the installer 1.0 is a bit beta at the moment, ..


if [ "$UID" != "0" ]
then
    echo "Installer needs root privilegs. Exiting"
    exit
fi

## we use another user and keep the user pi for desktop-login
if [ -z "$1" ]
then
    USERNAME=x
else
    USERNAME=$1
fi

echo "username will be $USERNAME"
cat /etc/rpi-issue

export DEBIAN_FRONTEND=noninteractive

## installer helper function
function pm {
    echo "apt-get -y install $@"
    apt-get -y install $@
}

function pipm {
    echo "apt-get -y install $@"
    apt-get -y install $@
}


## set the current time +timezone
ntpd -gq
dpkg-reconfigure tzdata

## installs
pm mc


## first, format the drives and mount partitions
echo ''
echo "DISKS"
lsblk
echo "Hit Ctrl-C to partition disks."
sleep 3
echo "OK, ..."

## warm about hostname settings
echo ''
echo "Hostname: $(hostname)"
cat /etc/hosts
echo "Hit Ctrl-C to change the hostname manually."
sleep 3
echo "OK, ..."

## install vnc-related packages
pm tightvncserver
pm ratpoison

## install applications
pm audacity

## add user
adduser $USERNAME
usermod -a -G audio $USERNAME
usermod -a -G video $USERNAME
## not sure which are required for sure.
usermod -a -G gpio $USERNAME
usermod -a -G plugdev $USERNAME
usermod -a -G users $USERNAME
usermod -a -G netdev $USERNAME
usermod -a -G input $USERNAME
usermod -a -G spi $USERNAME


## setup key
su $USERNAME -c "rsa-keygen -t rsa"

echo "-- RSA PUBLICKEY for $USERNAME ---"
cat /home/$USERNAME/.ssh/id_rsa.pub
echo ""

## allow users to shutdown / halt
echo "ALL ALL=(ALL) NOPASSWD: $(which halt)" >> /etc/sudoers.d/commands
echo "ALL ALL=(ALL) NOPASSWD: $(which reboot)" >> /etc/sudoers.d/commands

## set vnc configs
echo "Set up vncserver"

echo '
#!/bin/sh
# /etc/init.d/tightvncserver
# Set the VNCUSER variable to the name of the user to start tightvncserver under
VNCUSER='$USERNAME'
case "$1" in
  restart)
    pkill Xtightvnc
    echo "Tightvncserver stopped"
    su $VNCUSER -c "/usr/bin/tightvncserver :1 -geometry 800x600 -depth 24 -dpi 96"
    echo "Starting TightVNC server for $VNCUSER"
    ;;
  start)
    su $VNCUSER -c "/usr/bin/tightvncserver :1 -geometry 800x600 -depth 24 -dpi 96"
    echo "Starting TightVNC server for $VNCUSER"
    ;;
  stop)
    pkill Xtightvnc
    echo "Tightvncserver stopped"
    ;;
  *)
    echo "Usage: /etc/init.d/tightvncserver {start|stop|restart}"
    exit 1
    ;;
esac
exit 0
' > /etc/init.d/vnc.sh

update-rc.d vnc.sh defaults
ln -s /etc/init.d/vnc.sh /bin/vnc

vnc start

cat '#!/bin/sh

xrdb $HOME/.Xresources
export XKL_XMODMAP_DISABLE=1

cd ~
ratpoison &
bash apps.sh
' > /home/$USERNAME/.vnc/xstartup

cat apps.sh > /home/$USERNAME/apps.sh

vnc restart

mkdir -p /home/$USERNAME/.audacity-data
mkdir -p /home/$USERNAME/.audacity_temp

cat audacity.cfg > /home/$USERNAME/.audacity-data/audacity.cfg
echo "TempDir=/home/$USERNAME/.audacity_temp" >> /home/$USERNAME/.audacity-data/audacity.cfg

chown -R $USERNAME:$USERNAME /home/$USERNAME/.audacity-data
chown -R $USERNAME:$USERNAME /home/$USERNAME/.audacity_temp

## copy the cirrus files and set 
cp -a /home/pi/cirrus /home/$USERNAME
chown -R $USERNAME:$USERNAME /home/$USERNAME/cirrus
