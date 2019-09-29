#!/bin/bash

echo ""
echo "---Install Sysbench---"
echo ""

sudo apt install -y sysbench



echo ""
echo "---Core Tests---"
echo ""

cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
freq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
tram=$( free -m | awk 'NR==2 {print $2}' )
swap=$( free -m | awk 'NR==4 {print $2}' )
up=$(uptime|awk '{ $1=$2=$(NF-6)=$(NF-5)=$(NF-4)=$(NF-3)=$(NF-2)=$(NF-1)=$NF=""; print }')


echo "CPU model : $cname"
echo "Number of cores : $cores"
echo "CPU frequency : $freq MHz"
echo "Total amount of ram : $tram MB"
echo "Total amount of swap : $swap MB"
echo "System uptime : $up"


echo ""
io=$( ( dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
echo "I/O speed : $io"
io=$( ( dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
echo "I/O speed : $io"
io=$( ( dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
echo "I/O speed : $io"
io=$( ( dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
echo "I/O speed : $io"
io=$( ( dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
echo "I/O speed : $io"
echo ""



echo ""
echo "---Sysbench---"
echo ""

echo "# Threads: 1"
echo ""
sysbench --test=cpu --cpu-max-prime=20000 --num-threads=1 run
echo ""

echo "# Threads: 16"
echo ""
sysbench --test=cpu --cpu-max-prime=20000 --num-threads=32 run
echo ""



echo ""
echo "---Speedtest---"
echo ""

sudo apt update
sudo apt install -y python3-pip
yes | sudo pip3 install speedtest-cli
speedtest-cli

