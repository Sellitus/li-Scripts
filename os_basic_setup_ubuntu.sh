#!/bin/bash
# User editable options
systemApps="curl nano build-essential unzip ufw fail2ban git sysbench htop"

serverApps="openssh-server"
desktopApps="eclipse gedit steam qbittorrent pycharm-community spyder3"



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



# Change user's password along with root's if applicable
echo "/-----\         USER          /-----\\"
echo "\-----/    Password Change!   \-----/"
passwd

echo ""
echo "/-----\         ROOT           /-----\\"
echo "\-----/    Password Change!    \-----/"

echo "Change ROOT password? <y/N>"
rootPassChoice="n"
read rootPassChoice

if [[ $rootPassChoice == "y" || $rootPassChoice == "Y" || $rootPassChoice == "yes" || $rootPassChoice == "YES" || $rootPassChoice == "Yes" ]]; then
	sudo passwd root
fi



# Initial update
apt update
apt dist-upgrade -y

# Base system package install (including down to minimal 16.04)
apt install -y sudo
for currPackage in $systemApps
do
	sudo apt install -y $currPackage
done



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



# Remove apps that are not needed to lighten the load
sudo apt purge -y transmission-*
sudo apt purge -y apache2



# Install desktop software first
if [[ $deskChoice == "y" || $deskChoice == "Y" || $deskChoice == "yes" || $deskChoice == "YES" || $deskChoice == "Yes" ]]; then

	# Install Chrome
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	sudo dpkg -i google-chrome-stable_current_amd64.deb
	rm google-chrome-stable_current_amd64.deb

	# Download the public keys then add the repos.
	sudo add-apt-repository -y ppa:hydr0g3n/qbittorrent-stable
	sudo add-apt-repository -y ppa:mystic-mirage/pycharm

	sudo apt update

	# Install all optional apps
	# NOTE: Placed towards end since Steam must have a license agreement accepted
	for currPackage in $desktopApps
	do
		sudo apt install -y $currPackage
	done
fi


# Install server options
if [[ $serverChoice == "y" || $serverChoice == "Y" || $serverChoice == "yes" || $serverChoice == "YES" || $serverChoice == "Yes" || $serverChoice == "" ]]; then

	for currPackage in $serverApps
	do
        	sudo apt install -y $currPackage
	done

	# UFW
	sudo ufw limit 22

	# Private Key
	sudo mkdir /root/.ssh
	sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCvp+nTivEWyDH/HZw/Hj4OciL20nITXVpvwDpmVgJgRV8sT9jhoigdKvMSLBcbfTmeQ2EBDzdz4BwgiAOdLn4woVZzvZOW9pqRtU3oiTudjRX02zL+j3r+Htq5OirJL/EvzYN2FtgGJslfDRrZAdOxJoV/A2YeXsCX0Nco0eTX2dcCmIhFkGKIXEqT4ic+y8NTtiPqYfuXj3dRWaNcD0s/XCc0ygKSZi99/uWcdTkkJidJhjFFzNbNUzExoRO+H7A9ec8c6LfpuFEJz4uXuuA+GKhVKQaXsQ3/se5k/uR+l1ghVdYg1fCtsbTHDoCcXG0WIl2bsehEifOFpQk7umsRd2C/DuWOhs+j2DLV7p7AnifyzRRVf9tXdf8gv2cnyYN7tRpysFLkPhGkUGyB1BoIAXLLj7zJo4zSamknwRuxswrGkDEkhy+MqRsOeYVw9+fgUB8+qaw4ponkCC+2Og0LfwfcCWZb3jeDJoJ4PqITpj6KTBYl7JftqNnANYE5S4tt8RhvHFdZ6O0rWQDG1/25zwfh3A7qXSx4+lJh8HUzHrC0jw+yv2YshyyiswPGyooUZcKS1/EpBm2rrC0xc8X6pa6qeGFGKsfHiMYmjqga4Q8ChFIb4tqPyJLcVT1PSWPVibRLLq2xXjLXAkTzeb4LH/IAKcJNxDSyhuvMk99M1Q== root@s" > /root/.ssh/authorized_keys
	# Only allow root with a key to connect
	sudo sed -i 's/PermitRootLogin yes/PermitRootLogin without-password/g' /etc/ssh/sshd_config
	sudo echo 'AllowUsers root' >> /etc/ssh/sshd_config
	sudo service ssh restart

	# Add auto-update crontab job (6AM full update)
	crontab -l | { cat; echo "0 6 * * * sudo apt update && sudo apt dist-upgrade -y &&  sudo apt install -y -f && sudo apt autoremove -y >/dev/null 2>&1"; } | crontab -
fi

# Enable UFW
sudo ufw --force enable

# Config git while we're at it
git config --global user.email "sellitus@gmail.com"
git config --global user.name "Sellitus"
# User Git 2.0+'s method
git config --global push.default simple



# Resolve dependencies
sudo apt install -y -f

# Force configure, just in case
sudo dpkg --configure -a

# Final cleanup after all apt commands
sudo apt autoremove -y
sudo apt autoclean -y



# Message to notify user of restart
echo "Setup: done  /  Restarting..."
# Final system restart
sudo reboot
