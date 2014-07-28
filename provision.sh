#!/bin/bash

sudo apt-get -y install bc curl gcc-4.6-arm-linux-gnueabi make makeself ncurses-dev || true
sudo ln -s /usr/bin/arm-linux-gnueabi-gcc-4.6 /usr/bin/arm-linux-gnueabi-gcc

