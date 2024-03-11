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
	echo "------------------ Basic Updates and Config A ( 1 / 8 ) ---------------------"
	echo ""
	echo ""

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
	
  	# Install LunarVim
  	LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
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
	code --install-extension continue.continue
	code --install-extension jiapeiyao.tab-group
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension ms-vscode-remote.remote-wsl
	code --install-extension ms-vscode-remote.vscode-remote-extensionpack


	# Initialize VS Code from CLI
	code --list-extensions | xargs -L 1 echo code --install-extension

	# Add new settings, and disable continue.continue plugin
	rm -f $HOME/Library/Application\ Support/Code/User/settings.json
	echo '{
    "workbench.editor.wrapTabs": true,
    "workbench.editor.tabSizing": "shrink",
    "continue.continue": false,
	"files.autoSave": "afterDelay"
}' > $HOME/Library/Application\ Support/Code/User/settings.json

fi


# Install server options
if [[ $serverChoice == "y" ]]; then

	echo "not yet implemented"
	
fi


if [[ $basicChoice == "y" ]]; then

	echo ""
	echo ""
	echo "------------------ Basic Updates and Config B ( 8 / 8 ) ---------------------"
	echo ""
	echo ""

 	
fi
