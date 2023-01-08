if [ $# -eq 0 ]
then
      echo "No folder was passed to rsync. Ex: ./rsync aws-connector"
      exit 1
fi

rsync -e "ssh -i $HOME/.ssh/id_rsa.desktop" -a $1 sellitus@192.168.50.150:/home/sellitus/SYNC/$1
