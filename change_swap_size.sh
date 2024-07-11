# The first argument should be a value understood by fallocate, such as: 16G

sudo swapoff -a
sudo fallocate -l $1 /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
