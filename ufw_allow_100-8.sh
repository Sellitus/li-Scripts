#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <port_number>"
    exit 1
fi

if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number"
    exit 1
fi

sudo ufw allow from 100.0.0.0/8 to any port "$1"
