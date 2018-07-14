#!/bin/bash

sudo apt install -y docker.io

sudo ufw allow 8080
sudo ufw allow 32768:65535/tcp
sudo ufw allow 32768:65535/udp
sudo ufw --force enable

docker run eclipse/che info --network

docker run -it -e CHE_MULTIUSER=true -e CHE_HOST=104.225.218.39 --rm -v /var/run/docker.sock:/var/run/docker.sock -v /root/EclipseChe/:/data eclipse/che start
