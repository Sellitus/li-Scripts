#!/bin/bash



# User editable options
brewApps="python@3.11 neovim lazygit"
serverApps="openssh-server"


# Initialization
basicChoice=""
serverChoice=""


userInput=$1
if [[ $userInput == "" ]]; then
	echo ""
	echo "Choose some or all of the options below. Separate your choices by comma with no spaces."
	echo "EXAMPLE: 1,2,3"
	echo "1 - Basic Updates and Config"
	echo "    ($brewApps)"
	echo "2 - Extras (not yet implemented)"
	echo "    ($serverApps)"
	echo ""
	read -p ":: " userInput
fi



IFS=',' read -ra ADDR <<< "$userInput"
for i in "${ADDR[@]}"; do
	if [[ $i == "1" ]]; then
		basicChoice="y"
	fi
	if [[ $i == "2" ]]; then
		serverChoice="y"
	fi
done



if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config A ( 1 / 2 ) ---------------------"
	echo ""
	echo ""

	# Make wifi connect to the strongest AP for wifi AP roaming
	(sudo crontab -l; echo "@reboot sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport prefs joinMode=Strongest
") | sudo crontab -

	# Increase VRAM limit
	(sudo crontab -l; echo "@reboot sudo sysctl iogpu.wired_limit_mb=90112") | sudo crontab -


	# Install brew non-interactively
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	
	# Create ~/.bashrc file
	touch ~/.bashrc

	# source ~/.bashrc in ~/.zshrc
	echo "source ~/.bashrc" >> ~/.zshrc

	# Brew install each system app
	for currPackage in $brewApps
	do
		echo "\n\n ----- Installing: $currPackage ----- \n\n"
		brew install $currPackage
	done

	# Switch to using python3.11 installed by brew
	echo "alias python=/opt/homebrew/bin/python3.11" >> ~/.bashrc
	echo "alias pip=/opt/homebrew/bin/pip3.11" >> ~/.bashrc
	echo "alias python3=/opt/homebrew/bin/python3.11" >> ~/.bashrc
	echo "alias pip3=/opt/homebrew/bin/pip3.11" >> ~/.bashrc

	# Install LunarVim Prereqs
	brew install python node
	echo '\n' | curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	brew install ripgrep
	
  	# Install NeoVim, then LunarVim
  	LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
   	echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc

	# Replace vim with lvim
	echo "alias vim1=/usr/bin/vim" >> ~/.bashrc
	echo "alias vim=lvim" >> ~/.bashrc

	# Install VS Code
	brew install --cask visual-studio-code

	# Install VSCode plugins
	code --install-extension ms-python.python
	code --install-extension njqdev.vscode-python-typehint
	code --install-extension ms-toolsai.jupyter
	code --install-extension donjayamanne.python-extension-pack
	code --install-extension huggingface.huggingface-vscode
	code --install-extension visualstudioexptteam.vscodeintellicode
	code --install-extension github.copilot
	code --install-extension dp-faces.dpico-theme
	code --install-extension vscjava.vscode-java-pack
	code --install-extension vscjava.vscode-gradle
	code --install-extension golang.go
	# code --install-extension continue.continue
	code --install-extension jiapeiyao.tab-group
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension ms-vscode-remote.remote-wsl
	code --install-extension ms-vscode-remote.vscode-remote-extensionpack
 	code --install-extension esbenp.prettier-vscode


	# Initialize VS Code from CLI
	code --list-extensions | xargs -L 1 echo code --install-extension

	# Add new settings, and disable continue.continue plugin
	rm -f $HOME/Library/Application\ Support/Code/User/settings.json
	echo '{
    "workbench.editor.wrapTabs": true,
    "workbench.editor.tabSizing": "shrink",
    "continue.continue": false,
	"files.autoSave": "afterDelay",
    "editor.wordWrap": "on"
}' > $HOME/Library/Application\ Support/Code/User/settings.json

fi


# Install server options
if [[ $serverChoice == "y" ]]; then

	echo "not yet implemented"
	
fi


if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config B ( 2 / 2 ) ---------------------"
	echo ""
	echo ""


	echo ""
	echo ""
	echo "TO COMPLETE SETUP: Run LunarVim and then run ':Lazy sync' to get rid of LunarVim errors"
	echo ""
	echo ""

 	
fi
