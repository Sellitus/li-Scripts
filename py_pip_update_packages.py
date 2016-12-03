import pip
from subprocess import call

call("sudo pip install --upgrade pip", shell=True)

for dist in pip.get_installed_distributions():
    call("pip install --upgrade " + dist.project_name, shell=True)
