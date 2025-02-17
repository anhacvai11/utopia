#!/bin/bash

# Download and execute ens160-pre-install-uam.sh
wget https://raw.githubusercontent.com/anhacvai11/utopia/main/aws-pre-install-uam.sh
sudo chmod 777 aws-pre-install-uam.sh
./aws-pre-install-uam.sh

# Download and execute generate-uam.sh
wget https://raw.githubusercontent.com/anhacvai11/utopia/main/generate-uam.sh
sudo chmod 777 generate-uam.sh
./generate-uam.sh 7DF0D54A0C90CDB458D485A48FFB59E39EB079D3C3A0BC635414B36FEFF0380B 2a

# Install w3m and w3m-img
sudo apt-get install w3m w3m-img -y
