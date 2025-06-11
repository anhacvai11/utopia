#!/bin/bash
# Function to download a file with retries
download_file() {
    local file_name=$1
    local url="https://github.com/anhacvai11/utopia/raw/main/$nameFile"
    local output=$file_name
    local wait_seconds=2
    local retry_count=0
    local max_retries=50

    while [ $retry_count -lt $max_retries ]; do
        wget --no-check-certificate -q "$url" -O "$output"

        if [ $? -eq 0 ]; then
            echo "Download successful: $file_name saved as $output."
            return 0
        else
            retry_count=$((retry_count + 1))
            echo "Download failed. Retrying in $wait_seconds seconds..."
            echo "Retrying to download $file_name from $url (Attempt $retry_count/$max_retries)..."
            sleep $wait_seconds
        fi
    done

    echo "Failed to download $file_name after $max_retries attempts."
    exit 1
}
nameFile=track.sh
sudo rm -f $nameFile
download_file $nameFile
sudo chmod +x $nameFile

net=$(ip link show | awk -F: '/^[0-9]+:/ {print $2}' | tr -d ' ' | grep -v '^lo$' | head -n1)

if [[ -z "$net" ]]; then
    echo "No network interface found."
    exit 1
else
    echo "First network interface: $net"
fi

echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo "grub-pc grub-pc/install_devices multiselect /dev/sda15" | sudo debconf-set-selections
echo "grub-pc grub-pc/install_devices_empty boolean false" | sudo debconf-set-selections
echo "grub-pc grub-pc/postrm_purge boolean false" | sudo debconf-set-selections
echo "grub-efi grub-efi/install_devices multiselect /dev/sda15" | sudo debconf-set-selections
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
sudo apt install nload && sudo apt install mc -y && sudo apt install docker.io -y && sudo apt install nload && sudo apt install cbm -y && sudo apt install ethtool -y
echo "miniupnpd miniupnpd/start_daemon boolean true" | sudo debconf-set-selections
echo "miniupnpd miniupnpd/listen string docker0" | sudo debconf-set-selections
echo "miniupnpd miniupnpd/iface string $net" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt install miniupnpd -y
sudo sed -i 's/After=network-online.target.*/After=network-online.target docker.service/' /etc/systemd/system/multi-user.target.wants/miniupnpd.service
sudo sed -i 's|IPTABLES=$(which iptables)|IPTABLES=$(which iptables-legacy)|g; s|IPTABLES=$(which ip6tables)|IPTABLES=$(which ip6tables-legacy)|g' /etc/miniupnpd/miniupnpd_functions.sh
sudo sed -ie 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1'/g /etc/sysctl.conf
sudo sysctl -p
sudo systemctl daemon-reload
sudo systemctl restart miniupnpd
sudo chmod 666 /var/run/docker.sock
sudo iptables -F
sudo iptables -A INPUT -p all -j ACCEPT
sudo iptables -A FORWARD -p all -j ACCEPT
sudo iptables -A OUTPUT -p all -j ACCEPT
sudo iptables -A InstanceServices -p all -j ACCEPT
sudo iptables -t nat -I POSTROUTING -s 172.17.0.1 -j SNAT --to-source $(ip addr show $net | grep "inet " | grep -v 127.0.0.1|awk 'match($0, /(10.[0-9]+\.[0-9]+\.[0-9]+)/) {print substr($0,RSTART,RLENGTH)}')

number=$(docker ps | grep debian:bullseye-slim | wc -l)
docker rm -f $(docker ps -aq --filter ancestor=debian:bullseye-slim) && sudo rm -rf /opt/uam_data
for i in `seq 1 $number`; do docker run -d --restart always --name uam_$i -e WALLET=7DF0D54A0C90CDB458D485A48FFB59E39EB079D3C3A0BC635414B36FEFF0380B --cap-add=IPC_LOCK tuanna9414/uam:latest; done
docker ps --filter ancestor=tuanna9414/uam:latest
