#!/bin/bash
# User editable options
desktopApps="eclipse gedit steam qbittorrent pycharm-community"

# Initialization
deskChoice=""
serverChoice=""

# Iterate through every argument passed by user
for arg in "$@"
do
	if [[ $arg == "-desktop" ]]; then
		deskChoice="y"
	fi

	if [[ $arg == "-server" ]]; then
		serverChoice="y"
	fi
done


if [[ $serverChoice != "y" && $serverChoice != "n" ]]; then
	echo "Would you like to set this machine up as a server? <Y/n>"
	serverChoice="y"
	read serverChoice
fi

if [[ $deskChoice != "y" && $deskChoice != "n" ]]; then
	echo "Would you like to install optional desktop apps? <y/N>"
	deskChoice="n"
	read deskChoice
fi


# Initial update
apt update
apt dist-upgrade -y

# Base package install (including down to minimal 14.04)
apt install -y sudo
sudo apt install -y nano
sudo apt install -y openssh-server
sudo apt install -y htop
sudo apt install -y build-essential
sudo apt install -y ufw
sudo apt install -y fail2ban
sudo apt install -y git
sudo apt install -y sysbench


# Setup all the Python 2 and 3 Packages
sudo apt install -y software-properties-common

sudo apt install -y python-setuptools
sudo apt install -y python-all-dev
sudo apt install -y python-software-properties

sudo apt install -y python3-setuptools
sudo apt install -y python3-all-dev
sudo apt install -y python3-software-properties


# Remove default PIP install and reinstall using easy_install
sudo apt purge -y python-pip
sudo apt purge -y python3-pip
sudo easy_install pip
sudo easy_install3 pip

# User option check
if [[ $deskChoice == "y" || $deskChoice == "Y" || $deskChoice == "yes" || $deskChoice == "YES" || $deskChoice == "Yes" ]]; then

	# Download the public keys then add the repos.
	sudo add-apt-repository -y ppa:hydr0g3n/qbittorrent-stable
	sudo add-apt-repository -y ppa:mystic-mirage/pycharm

	sudo apt update

	# Install all optional apps
	sudo apt install -y $desktopApps

	# Install Chrome
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	sudo dpkg -i google-chrome-stable_current_amd64.deb
	rm google-chrome-stable_current_amd64.deb
	
	# Install Anadconda/Spyder
	wget https://repo.continuum.io/archive/Anaconda3-4.1.1-Linux-x86_64.sh
	sudo bash Anaconda3-4.1.1-Linux-x86_64.sh -b
	sudo rm -f Anaconda3-4.1.1-Linux-x86_64.sh

	# Remove desktop apps that are not needed
	sudo apt remove -y transmission-*
fi

# Resolve dependencies
sudo apt install -y -f

# Force configure, just in case
sudo dpkg --configure -a

# Final cleanup after all apt-get commands
sudo apt autoremove -y
sudo apt autoclean -y


# ------------Configuration---------------

if [[ $serverChoice == "y" || $serverChoice == "Y" || $serverChoice == "yes" || $serverChoice == "YES" || $serverChoice == "Yes" || $serverChoice == "" ]]; then
	# UFW
	sudo ufw limit 22
	sudo ufw --force enable

	# Private Key
	sudo mkdir /root/.ssh
	sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcRoyVh2rT98Z/8pCx4FXlNPyFM8hQRF7xEq8g4ts9zutAnFbG/7xe7TOGl+3gaH7a9R6I+fw/jsnP62tA2rlVveKiPQi28L6/BEzvi673j6EkH7CREbO6SrOwLpKFu/MoU7chUdNM/7mGMEXfOv2Wvn1yUcldXtegm9RP/+yjhpYp4Fc073cPzzf/1hRAXKnzeSk4gUr2cpATUuVK4Yf0orW/Q2ZB+iQ3o3MHPQQh6of2EFhLf6e0AliKqO7jjgK6vXooPn+/zVTAazkQof92mIDb8QtUTuenb4b4SbHKj0VgIJvmT/K4VYua7AOk7dMPnqBvqiNF9ZlpxMRETgYzxip9XATX/NGqCvN45aaMt+r+ULOoe0jRNupMvy5++q9mHT6BileIsOgDjQC8kv5nL6/sC+0V/Wgn3237U6MwdLHVObnyga31VrT2iqCmOkr8qt8af6Dsu7/rbTGx/OXY0baCxIoOWWgiQwIDCEzAr+FY+MVY/ziYfRKIfBzyZs77/W3HsDeOHI1yxqA+WSCX11uOXxuVnMr20JBsDrK80vwHCgOfCP+P+ckRBY6DsSO0MHPhDdf9AXu+Cj9yVufj21Q+AQSmVG4J9LvgFmS6mpZI5+HAk/r0HPfQAIHE9zqtRbbY2AZpn2ldpXbyj6ClIZ1WT6Kth7XSJcoPd8UHSQ== root@sellitus" > /root/.ssh/authorized_keys
	# Only allow root with a key to connect
	sudo sed -i 's/PermitRootLogin yes/PermitRootLogin without-password/g' /etc/ssh/sshd_config
	sudo echo 'AllowUsers root' >> /etc/ssh/sshd_config
	sudo service ssh restart

	# Add auto-update crontab job (6AM full update)
	crontab -l | { cat; echo "0 6 * * * sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y >/dev/null 2>&1"; } | crontab -
fi


# Config git while we're at it
git config --global user.email "sellitus@gmail.com"
git config --global user.name "Sellitus"


# Message to notify user of restart
echo "Setup: done  /  Restarting..."
# Final system restart
sudo reboot
