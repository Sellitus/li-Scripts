sudo /opt/kasm/current/bin/stop

sudo docker rm -f $(sudo docker container ls -qa --filter="label=kasm.kasmid")

export KASM_UID=$(id kasm -u)
export KASM_GID=$(id kasm -g)
sudo -E docker compose -f /opt/kasm/current/docker/docker-compose.yaml rm

sudo docker network rm kasm_default_network

sudo docker volume rm kasm_db_1.14.0

sudo docker rmi redis:5-alpine
sudo docker rmi postgres:9.5-alpine
sudo docker rmi kasmweb/nginx:latest
sudo docker rmi kasmweb/share:1.14.0
sudo docker rmi kasmweb/agent:1.14.0
sudo docker rmi kasmweb/manager:1.14.0
sudo docker rmi kasmweb/api:1.14.0

sudo docker rmi $(sudo docker images --filter "label=com.kasmweb.image=true" -q)

sudo rm -rf /opt/kasm/

sudo deluser kasm_db
sudo deluser kasm
