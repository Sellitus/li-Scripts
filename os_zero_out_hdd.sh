#!/bin/bash
# This script is designed to zero out the free hard
# drive space in a KVM to make backups much smaller.
dd if=/dev/zero of=zero.small.file bs=1024 count=102400
dd if=/dev/zero of=zero.file bs=1024
rm zero.small.file
sync ; sleep 60 ; sync
rm zero.file