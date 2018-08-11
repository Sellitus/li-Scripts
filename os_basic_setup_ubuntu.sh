#!/bin/bash


if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root." 
	exit 1
fi


# User editable options
systemApps="vim tmux curl nano build-essential unzip ufw fail2ban git sysbench htop build-essential"
serverApps="openssh-server"
guiApps="eclipse gedit qbittorrent sublime-text tilix"
x11Apps="xubuntu-desktop"


# Initialization
basicChoice=""
serverChoice=""
x11Choice=""
guiChoice=""
username=""


userInput=$1
if [[ $userInput == "" ]]; then
	echo ""
	echo "Choose some or all of the options below. Separate your choices by comma with no spaces."
	echo "EXAMPLE: 1,2,3"
	echo "1 - Basic Updates and Config"
	echo "    ($systemApps)"
	echo "2 - Server Setup"
	echo "    ($serverApps)"
	echo "3 - X11 Apps"
	echo "    ($x11Apps)"
	echo "4 - GUI Apps"
	echo "    ($guiApps)"
	echo ""
	read -p ":: " userInput
fi

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
	

	if [[ $sureInput == "" ]] || [[ $sureInput == "y" ]] || [[ $sureInput == "Y" ]]; then
		sure=1
	fi
done


IFS=',' read -ra ADDR <<< "$userInput"
for i in "${ADDR[@]}"; do
	if [[ $i == "1" ]]; then
		basicChoice="y"
	fi
	if [[ $i == "2" ]]; then
		serverChoice="y"
	fi
	if [[ $i == "3" ]]; then
		x11Choice="y"
	fi
	if [[ $i == "4" ]]; then
		guiChoice="y"
	fi
done



if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config A ( 1 / 5 ) ---------------------"
	echo ""
	echo ""

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

	echo 'echo ""
	if [[ -z "$TMUX" ]]; then
	  IFS= read -t 1 -n 1 -r -s -p "Press any key (except enter) for /bin/bash... " keyPress
	  echo ""

	  if [ -z "$keyPress" ] && [ "$SSH_CONNECTION" != "" ]; then
	    if command -v tmux>/dev/null; then
              tmux attach-session -t main || tmux new-session -s main
	    fi
	  else
	    echo ""
	    echo ""
	  fi
	fi
	' >> ~/.bashrc


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
fi



if [[ $x11Choice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ X11 Apps ( 2 / 5 ) ---------------------"
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
	echo "------------------ GUI Apps ( 3 / 5 ) ---------------------"
	echo ""
	echo ""

	# Install Chrome
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
	sudo dpkg -i /tmp/google-chrome-stable_current_amd64.deb
	rm /tmp/google-chrome-stable_current_amd64.deb

	# Sublime 3
	wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
	sudo apt-add-repository "deb https://download.sublimetext.com/ apt/stable/"

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
	echo "------------------ Server Setup ( 4 / 5 ) ---------------------"
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
	sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCw+VydauD2UqTurhqPiIAZupauFLiKQqjxH9xk7bSfl4eA+fxc6d8BjAYNr4PMTo94rPt5wRxYaxH29lBz7uWJlQqev3ZvWljT0MHxJSvCCND5U+K+e9aEzayBBXq2Gue0EUv15Eap17CSLqKg0YT5JNKHLAV4ZfV2yXCDSt+zVBpfvzQjkdNDb6fnvYqfYmdta0fBXwY3JHNlGthGmZ30xIaO7Atm/G0hjvP6Sdv6RjoGWUh62XhpepTqQMY2wK4s+J8Mm/idNyLpEzE0ohpfILl4lUnpMDSTm0nOOifzJHk6RLWvSqmPx75GHjrkgjsuktT9iMzjpMjC3cZECrR7hF2pT7vHuaAreU7epup5BeupYbs2KCV1Nqx81tPo624z4vNosNjLG+FmMRViQfj/JwDVmDc/29dLOWFOecGV22KQ8UvspjuQlRw0gQ46XSL+VYhTzmajrrw5QMmT1ifAzepAUg/yTmkqUZsepKTZ/gt1jMzuCKpwsDUBPJnRnJi5D2v0Za5ijsbXizc0LFQ7OIejzgJXBebfC2hKEnEqYCZfuLn6T04BxP3SMQqk85dBFe7ydRpCqyIqlUu19RYrWPs59mE4DQza4nDWyhQjasbQP+FqOERIt1s+LW0TzvLOPcSoIyYX5h31v10DEJ5CqomrDFQYNNY4ZKZOaKrs3w== default@ubuntu" > /home/$username/.ssh/authorized_keys
	sudo chmod 700 /home/$username/.ssh/
	sudo chmod 600 /home/$username/.ssh/authorized_keys
	sudo chown -R $username:$username /home/$username/.ssh/
	# Only allow $username with a key to connect
	sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sudo echo "AllowUsers $username" >> /etc/ssh/sshd_config
	sudo echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
	sudo echo 'Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr,aes256-cbc,aes192-cbc,aes128-cbc' >> /etc/ssh/sshd_config
	sudo echo 'Compression yes' >> /etc/ssh/sshd_config
	sudo service ssh restart

	# Add auto-update crontab job (6AM full update)
	crontab -l | { cat; echo "0 6 * * * sudo apt update && sudo apt dist-upgrade -y &&  sudo apt install -y -f && sudo dpkg --configure -a && sudo apt autoremove -y >/dev/null 2>&1"; } | crontab -
fi

if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config B ( 5 / 5 ) ---------------------"
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
