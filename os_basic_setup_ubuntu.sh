#!/bin/bash
# User editable options
systemApps="curl nano build-essential unzip ufw fail2ban git sysbench htop"

serverApps="openssh-server"
desktopApps="eclipse gedit steam qbittorrent sublime-text-installer guake terminator"



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



echo "Change USER password? <y/N>"
userPassChoice="n"
read userPassChoice

if [[ $userPassChoice == "y" || $userPassChoice == "Y" || $userPassChoice == "yes" || $userPassChoice == "YES" || $userPassChoice == "Yes" ]]; then
        # Change user's password along with root's if applicable
	echo "/-----\         USER          /-----\\"
	echo "\-----/    Password Change!   \-----/"
	passwd

	echo "Change ROOT password as well? <y/N>"
	rootPassChoice="n"
	read rootPassChoice

	if [[ $rootPassChoice == "y" || $rootPassChoice == "Y" || $rootPassChoice == "yes" || $rootPassChoice == "YES" || $rootPassChoice == "Yes" ]]; then
		echo ""
		echo "/-----\         ROOT           /-----\\"
		echo "\-----/    Password Change!    \-----/"
		sudo passwd root
	fi
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



# Setup all the Python 3 Packages
sudo apt install -y software-properties-common

sudo apt install -y python3-setuptools
sudo apt install -y python3-all-dev
sudo apt install -y python3-software-properties

# Remove default PIP install and reinstall using easy_install
sudo apt purge -y python3-pip
sudo easy_install3 pip

# Update PIP packages using the python update script
sudo python3 pip_update.py



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

	# Sublime 3 PPA
	sudo add-apt-repository ppa:webupd8team/sublime-text-3

	sudo apt update

	# Install all optional apps
	# NOTE: Placed towards end since Steam must have a license agreement accepted

	#for currPackage in $desktopApps
	#do
	#	sudo apt install -y $currPackage
	#done
	
	sudo apt install -y $desktopApps
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
	sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCbgmxf5hfHKQ6juuPZIRuSH2TJqu5GYCzyspEn1pFci/0yAmwoLjOO/i9xB09q9cuIRBaxafaTN5yDPmB3z3yJNDfR08yAke/Nl8RyO6Vvv/IwxTKQt+ynK1Ogj5t12gfXzR6364oU0zs7dQeVseEHR2VKigyzcdJAI+FW1kOBZLrUZ7k2cMKvqd0Ef6cgJ+KFuqtw2eLi08VsguKPYhTBFhgi/AkbhxBF1bdBnP5GVGZLSvzFfT3roMrLvwxwGQabBMA+6MQj5g2WVP+Oqj3+HQs0KoRDVSdsBbMXFkDbb/SUicaag0L/m4B+9E4m8mevGP7tdNDapLotaBVfT8gPmq/0cFAIqgFZ7HcHrJA7/6IcG3qOaOGVN30f2NsMIll8m8IL39iXPEMoQcjdWlfJXPvBedbgsAtVX85BmeuOHCJuseYd75Xh0CU24Kp5531funy3AWQN8m1wVYcZ49cD4z4c3nELwkuiKEISTtuy+6FGduuJEXcrd2n6w5LQqtKn5wYXDIyfM130nFSY114zHK6hEob/duNQzT8VG4VLWImgXp1E99U9OPeFoB2vh3s75+0cUVlgQy7LD20j1t0yKUzkg1NsgQJGLg+rD0j987STrPFdzJ5ccL4ufh54WXyuznfmuVS7dVf4o30BTTbch9eZzR+aepRYqvRF3BmEVw== root@ubuntu" > /root/.ssh/authorized_keys
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
echo "Setup: Done  /  Restarting..."
sleep 5
# Final system restart
sudo reboot
