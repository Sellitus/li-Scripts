#!/bin/bash

# Initialization
cppChoice=""
pythonChoice=""

# Iterate through every argument passed by user
for arg in "$@"
do
	if [[ $arg == "-cpp" ]]; then
		cppChoice="y"
	fi

	if [[ $arg == "-python" ]]; then
		pythonChoice="y"
	fi
done


if [[ $cppChoice != "y" && $cppChoice != "n" ]]; then
	echo "Would you like to install C++ packages? <Y/n>"
	cppChoice="y"
	read cppChoice
fi

if [[ $pythonChoice != "y" && $pythonChoice != "n" ]]; then
	echo "Would you like to install Python packages? <Y/n>"
	pythonChoice="y"
	read pythonChoice
fi


# Install Atom's Ubuntu package
sudo add-apt-repository -y ppa:webupd8team/atom
sudo apt update
sudo apt install -y atom


# Install Atom package prerequisites


# Install Atom packages
sudo apm install linter
sudo apm install highlight-selected
sudo apm install git-plus
sudo apm install local-history

sudo apm install minimap
sudo apm install minimap-find-and-replace
sudo apm install minimap-pigments
sudo apm install minimap-cursorline
sudo apm install minimap-highlight-selected


# User option check
if [[ $cppChoice == "y" || $cppChoice == "Y" || $cppChoice == "yes" || $cppChoice == "YES" || $cppChoice == "Yes" || $cppChoice == "" ]]; then
	sudo apt install -y clang

	sudo apm install autocomplete-clang
	sudo apm install linter-clang
	sudo apm install switch-header-source
	sudo apm install clang-format
fi


if [[ $pythonChoice == "y" || $pythonChoice == "Y" || $pythonChoice == "yes" || $pythonChoice == "YES" || $pythonChoice == "Yes" || $pythonChoice == "" ]]; then
	sudo apt install -y python3-pip
	sudo pip3 install --upgrade pip

	sudo pip3 install pylama pylama-pylint
	sudo pip3 install pep8

	sudo apm install python-tools
	sudo apm install python-indent
	sudo apm install autocomplete-python
	sudo apm install linter-python
	sudo apm install linter-pep8
fi


