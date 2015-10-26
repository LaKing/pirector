#!/bin/bash

## the installer 1.0 is a bit beta at the moment, ..


if [ "$UID" != "0" ]
then
    echo "Installer needs root privilegs. Exiting"
    exit
fi

if [ -z "$1" ]
then
    USERNAME=x
else
    USERNAME=$1
fi

echo "username will be $USERNAME"


if [ -f /etc/fedora-release ]
then
    echo "Fedora $(rpm -E %fedora)"
    FEDORA=true

    ## installer helper function
    function pm {
	echo "dnf -y install $@"
	dnf -y install $@
    }

    ## add rpmfusion
    dnf -y install --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    ## date setup?

else
    echo "This is not fedora. Exiting."
    exit
fi

## installs
pm mc


## install vnc-related packages
pm tigervnc-server
pm xorg-x11-apps
pm ratpoison
pm mp3gain

## install applications
pm audacity-freeworld
pm xmms2*

## add user
adduser $USERNAME
usermod -a -G audio $USERNAME
usermod -a -G video $USERNAME


## setup key
su $USERNAME -c "rsa-keygen -t rsa"

echo "-- RSA PUBLICKEY for $USERNAME ---"
cat /home/$USERNAME/.ssh/id_rsa.pub
echo ""


## set vnc configs
echo "Set up vncserver"

echo '[Unit]
Description=Remote desktop service (VNC) for '$USERNAME'
After=syslog.target network.target

[Service]
Type=forking
# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c "/usr/bin/vncserver -kill :1 > /dev/null 2>&1 || :"
ExecStart=/sbin/runuser -l '$USERNAME' -c "/usr/bin/vncserver :1"
PIDFile=/home/'$USERNAME'/.vnc/%H:1.pid
ExecStop=/bin/sh -c "/usr/bin/vncserver -kill :1 > /dev/null 2>&1 || :"

[Install]
WantedBy=multi-user.target
' > /usr/lib/systemd/system/vncserver.service

systemctl enable vncserver.service
systemctl start vncserver.service

systemctl stop vncserver.service

cat apps.sh > /home/$USERNAME/apps.sh

cat '#!/bin/sh

xrdb $HOME/.Xresources
export XKL_XMODMAP_DISABLE=1

cd ~
ratpoison &
bash apps.sh
' > /home/$USERNAME/.vnc/xstartup

systemctl start vncserver.service

mkdir -p /home/$USERNAME/.audacity-data
mkdir -p /home/$USERNAME/.audacity_temp

cat audacity.cfg > /home/$USERNAME/.audacity-data/audacity.cfg
echo "TempDir=/home/$USERNAME/.audacity_temp" >> /home/$USERNAME/.audacity-data/audacity.cfg

chown -R $USERNAME:$USERNAME /home/$USERNAME/.audacity-data
chown -R $USERNAME:$USERNAME /home/$USERNAME/.audacity_temp

