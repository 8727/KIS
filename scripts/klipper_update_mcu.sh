#!/usr/bin/env bash

set -e
clear

echo -e "${green}>>>>>> Update MCU <<<<<<${white}"

sudo cp -a ${USER}/klipper/.config ${USER}/.temp
sudo cp -a ${USER}/KIS/MKS.config ${USER}/klipper/.config

sudo service klipper stop
cd ~/klipper
make clean
make
./scripts/flash-sdcard.sh /dev/ttyS3 robin_v3
sudo service klipper start
sudo cp -a  ${USER}/.temp  ${USER}/klipper/.config

echo -e "${green}>>>>>> Update EBB <<<<<<${white}"

sudo cp -a ${USER}/klipper/.config ${USER}/.temp
sudo cp -a ${USER}/KIS/EBB.config ${USER}/klipper/.config

sudo service klipper stop
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_3C0048001350425539393020-if00
sudo service klipper start

sudo cp -a  ${USER}/.temp  ${USER}/klipper/.config
