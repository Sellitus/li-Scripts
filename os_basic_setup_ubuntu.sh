#!/bin/bash


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi


# User editable options
systemApps="vim tmux curl nano build-essential unzip ufw fail2ban git sysbench htop build-essential"

serverApps="openssh-server"
desktopApps="eclipse gedit qbittorrent sublime-text tilix"

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


adduser --home /home/objured/ --gecos "" objured
usermod -aG sudo objured


echo "Change ROOT password as well? <y/N>"
rootPassChoice="n"
read rootPassChoice

if [[ $rootPassChoice == "y" || $rootPassChoice == "Y" || $rootPassChoice == "yes" || $rootPassChoice == "YES" || $rootPassChoice == "Yes" ]]; then
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

  if [ -z "$keyPress" ]; then
    if command -v tmux>/dev/null; then
      if [ "$SSH_CONNECTION" != "" ]; then
        tmux attach-session -t main || tmux new-session -s main
      fi
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


# Install desktop software first
if [[ $deskChoice == "y" || $deskChoice == "Y" || $deskChoice == "yes" || $deskChoice == "YES" || $deskChoice == "Yes" ]]; then

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
	for currPackage in $desktopApps
	do
		sudo apt install -y $currPackage
	done
	
	#sudo apt install -y $desktopApps
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
	sudo mkdir /home/objured/.ssh
	sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCw+VydauD2UqTurhqPiIAZupauFLiKQqjxH9xk7bSfl4eA+fxc6d8BjAYNr4PMTo94rPt5wRxYaxH29lBz7uWJlQqev3ZvWljT0MHxJSvCCND5U+K+e9aEzayBBXq2Gue0EUv15Eap17CSLqKg0YT5JNKHLAV4ZfV2yXCDSt+zVBpfvzQjkdNDb6fnvYqfYmdta0fBXwY3JHNlGthGmZ30xIaO7Atm/G0hjvP6Sdv6RjoGWUh62XhpepTqQMY2wK4s+J8Mm/idNyLpEzE0ohpfILl4lUnpMDSTm0nOOifzJHk6RLWvSqmPx75GHjrkgjsuktT9iMzjpMjC3cZECrR7hF2pT7vHuaAreU7epup5BeupYbs2KCV1Nqx81tPo624z4vNosNjLG+FmMRViQfj/JwDVmDc/29dLOWFOecGV22KQ8UvspjuQlRw0gQ46XSL+VYhTzmajrrw5QMmT1ifAzepAUg/yTmkqUZsepKTZ/gt1jMzuCKpwsDUBPJnRnJi5D2v0Za5ijsbXizc0LFQ7OIejzgJXBebfC2hKEnEqYCZfuLn6T04BxP3SMQqk85dBFe7ydRpCqyIqlUu19RYrWPs59mE4DQza4nDWyhQjasbQP+FqOERIt1s+LW0TzvLOPcSoIyYX5h31v10DEJ5CqomrDFQYNNY4ZKZOaKrs3w== default@ubuntu" > /home/objured/.ssh/authorized_keys
	sudo chmod 700 /home/objured/.ssh/
	sudo chmod 600 /home/objured/.ssh/authorized_keys
	sudo chown -R objured:objured /home/objured/.ssh/
	# Only allow objured with a key to connect
	sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sudo echo 'AllowUsers objured' >> /etc/ssh/sshd_config
	sudo echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
	sudo service ssh restart

	# Add auto-update crontab job (6AM full update)
	crontab -l | { cat; echo "0 6 * * * sudo apt update && sudo apt dist-upgrade -y &&  sudo apt install -y -f && sudo dpkg --configure -a && sudo apt autoremove -y >/dev/null 2>&1"; } | crontab -
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
