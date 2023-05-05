#!/usr/bin/env bash

set -e
clear

echo -e "${green}>>>>>> Update Host <<<<<<${white}"

sudo echo "klipper ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/klipper

sudo apt update -y
sudo apt upgrade -y