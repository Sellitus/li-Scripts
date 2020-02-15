#!/bin/bash


if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root." 
	exit 1
fi


# User editable options
systemApps="vim tmux curl nano build-essential unzip ufw fail2ban git sysbench htop build-essential fish virtualenv virtualenvwrapper"
serverApps="openssh-server"
guiApps="qbittorrent sublime-text tilix firefox gedit"
x11Apps="gedit xfce4 xfce4-goodies tightvncserver"
vmGuestAdditions="open-vm-tools open-vm-tools-desktop"


# Initialization
basicChoice=""
mountChoice=""
serverChoice=""
x11Choice=""
guiChoice=""
vmGuestChoice=""
username=""


userInput=$1
if [[ $userInput == "" ]]; then
	echo ""
	echo "Choose some or all of the options below. Separate your choices by comma with no spaces."
	echo "EXAMPLE: 1,2,3"
	echo "1 - Basic Updates and Config"
	echo "    ($systemApps)"
	echo "2 - Mount Remote ~/obju.red/ Directory"
	echo "    ($serverApps)"
	echo "3 - Server Setup"
	echo "    ($serverApps)"
	echo "4 - X11 Apps"
	echo "    ($x11Apps)"
	echo "5 - GUI Apps"
	echo "    ($guiApps)"
	echo "6 - VMware / VirtualBox Guest Additions"
	echo "    ($vmGuestAdditions)"
	echo ""
	read -p ":: " userInput
fi



IFS=',' read -ra ADDR <<< "$userInput"
for i in "${ADDR[@]}"; do
	if [[ $i == "1" ]]; then
		basicChoice="y"
	fi
	if [[ $i == "2" ]]; then
		mountChoice="y"
	fi
	if [[ $i == "3" ]]; then
		serverChoice="y"
	fi
	if [[ $i == "4" ]]; then
		x11Choice="y"
	fi
	if [[ $i == "5" ]]; then
		guiChoice="y"
	fi
	if [[ $i == "6" ]]; then
		vmGuestChoice="y"
	fi
done



if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config A ( 1 / 7 ) ---------------------"
	echo ""
	echo ""

	sure=0
	while [[ $sure -eq 0 ]]; do
		echo ""
		echo "Enter username to create/use with sudo access (may already exist)"
		read -p ":: " username
		username="$(echo -e "${username}" | tr -d '[:space:]')"
	
		sureInput=""
		echo ""
		echo "Do you want to create the user: $username ? <Y/n>"
		read -p ":: " sureInput
		sureInput="$(echo -e "${sureInput}" | tr -d '[:space:]')"
	
		sure=1
	done

	adduser --home /home/$username/ --gecos "" $username
	usermod -aG sudo $username


	echo "Change ROOT password as well? <Y/n>"
	rootPassChoice="y"
	read rootPassChoice
	rootPassChoice="$(echo -e "${rootPassChoice}" | tr -d '[:space:]')"

	if [[ $rootPassChoice == "" ]] || [[ $rootPassChoice == "y" || $rootPassChoice == "Y" ]]; then
		echo ""
		echo "/-----\         ROOT           /-----\\"
		echo "\-----/    Password Change!    \-----/"
		passwd root
	fi
	
	# Create remote storage folder
	mkdir /home/$username/obju.red/
	chown $username:$username /home/$username/obju.red/
	chmod 600 /home/$username/obju.red/

	# Initial update
	apt update
	apt install -y sudo

	# Full upgrade and base system package install (including down to Ubuntu Minimal)
	apt full-upgrade -y
	for currPackage in $systemApps
	do
		sudo apt install -y $currPackage
	done


	# Set tmux to run upon starting shell (along with recovery)

# 	echo 'echo ""
# 	if [[ -z "$TMUX" ]] && [ "$SSH_CONNECTION" != "" ]; then
# 	  IFS= read -t 1 -n 1 -r -s -p "Press any key (except enter) for /bin/bash... " keyPress
# 	  echo ""

# 	  if [ -z "$keyPress" ]; then
# 	    if command -v tmux>/dev/null; then
#               tmux attach-session -t main || tmux new-session -s main
# 	    fi
# 	  else
# 	    echo ""
# 	    echo ""
# 	  fi
# 	fi
# 	' >> ~/.bashrc
	
	
	echo 'function tmux1 ()
{
	tmux attach-session -t main1 || tmux new-session -s main1
}' >> ~/.bashrc
	echo 'function tmux2 ()
{
	tmux attach-session -t main2 || tmux new-session -s main2
}' >> ~/.bashrc
	echo 'function tmux3 ()
{
	tmux attach-session -t main3 || tmux new-session -s main3
}' >> ~/.bashrc
	echo 'function tmux4 ()
{
	tmux attach-session -t main4 || tmux new-session -s main4
}' >> ~/.bashrc
	echo 'function tmux5 ()
{
	tmux attach-session -t main5 || tmux new-session -s main5
}' >> ~/.bashrc
	echo 'function tmux6 ()
{
	tmux attach-session -t main6 || tmux new-session -s main6
}' >> ~/.bashrc
	echo 'function tmux7 ()
{
	tmux attach-session -t main7 || tmux new-session -s main7
}' >> ~/.bashrc
	echo 'function tmux8 ()
{
	tmux attach-session -t main8 || tmux new-session -s main8
}' >> ~/.bashrc
	echo 'function tmux9 ()
{
	tmux attach-session -t main9 || tmux new-session -s main9
}' >> ~/.bashrc
	echo 'function tmux10 ()
{
	tmux attach-session -t main10 || tmux new-session -s main10
}' >> ~/.bashrc


	# Setup all the Python 3 Packages
	sudo apt install -y software-properties-common

	sudo apt install -y python3-setuptools
	sudo apt install -y python3-all-dev
	sudo apt install -y python3-software-properties

	# Remove default PIP install and reinstall using easy_install
	sudo apt install -y python3-pip
	# sudo easy_install3 pip

	# Update PIP packages using the python update script
	sudo python3 pip_update.py

	# Remove apps that are not needed to lighten the load
	sudo apt purge -y transmission-*
	sudo apt purge -y apache2
fi



if [[ $mountChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Mount Remote ~/obju.red/ Directory ( 2 / 7 ) ---------------------"
	echo ""
	echo ""
	
	for currPackage in $x11Apps
	do
		sudo apt install -y $currPackage
	done
fi



if [[ $x11Choice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ X11 Apps ( 3 / 7 ) ---------------------"
	echo ""
	echo ""
	
	for currPackage in $x11Apps
	do
		sudo apt install -y $currPackage
	done
fi



if [[ $guiChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ GUI Apps ( 4 / 7 ) ---------------------"
	echo ""
	echo ""

	# Install Chrome
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
	sudo dpkg -i /tmp/google-chrome-stable_current_amd64.deb
	rm /tmp/google-chrome-stable_current_amd64.deb

	# Update apt cache
	sudo apt update

	# Install all desktop apps individually in case one fails
	for currPackage in $guiApps
	do
		sudo apt install -y $currPackage
	done
	
	#sudo apt install -y $guiApps
fi



# Install server options
if [[ $serverChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Server Setup ( 5 / 7 ) ---------------------"
	echo ""
	echo ""

	for currPackage in $serverApps
	do
        	sudo apt install -y $currPackage
	done

	# UFW
	sudo ufw limit 22

	# Private Key
	sudo mkdir /home/$username/.ssh
	sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRrATacEhBkF626/ABvBJzGMtbVNxNIShkPmZwszxkk" > /home/$username/.ssh/authorized_keys
	sudo chmod 700 /home/$username/.ssh/
	sudo chmod 600 /home/$username/.ssh/authorized_keys
	sudo chown -R $username:$username /home/$username/.ssh/
	# Only allow $username with a key to connect
	sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sudo echo "AllowUsers $username" >> /etc/ssh/sshd_config
	sudo echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
	sudo service ssh restart

	# Add auto-update crontab job (6AM full update)
	crontab -l | { cat; echo "0 6 * * * sudo apt update && sudo apt install -y unattended-upgrades && sudo apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y &&  sudo apt install -y -f && sudo dpkg --configure -a && sudo apt autoremove -y >/dev/null 2>&1"; } | crontab -
fi


# Install server options
if [[ $vmGuestChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ VMware / VirtualBox Guest Additions ( 6 / 7 ) ---------------------"
	echo ""
	echo ""

	for currPackage in $vmGuestAdditions
	do
        	sudo apt install -y $currPackage
	done
fi


if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config B ( 7 / 7 ) ---------------------"
	echo ""
	echo ""

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
fi
