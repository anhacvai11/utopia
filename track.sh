#!/bin/bash
nowDate=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo $nowDate

sudo chmod 666 /var/run/docker.sock


MEMORY_LIMIT=50

# Get a list of containers running the repocket/repocket:latest image
containers=$(docker ps --filter "ancestor=repocket/repocket:latest" --format "{{.ID}}")

if [ -n "$containers" ]; then
    for container in $containers; do
        # Get memory usage of the container in MiB
        memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" $container | awk '{print $1}' | sed 's/MiB//')
        
        # Check if memory usage is greater than the limit
        if [ "$(echo "$memory_usage > $MEMORY_LIMIT" | bc)" -eq 1 ]; then
            echo "Container $container exceeds memory limit (${memory_usage}MiB > ${MEMORY_LIMIT}MiB). Deleting..."
            docker stop $container && docker rm $container
            docker run -e RP_EMAIL=anhkhoavipp@gmail.com -e RP_API_KEY=70fde55f-bfa5-4dd8-a6ce-f089a996f608 -d --restart=always --memory=50mb repocket/repocket:latest
        else
            echo "Container $container is within memory limit (${memory_usage}MiB)."
        fi
    done
fi


PBKEY=""
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# List of containers to try
containers=("uam_1" "uam_2" "uam_3" "uam_4" "uam_5")

for container in "${containers[@]}"; do
    PBKEY=$(docker exec "$container" printenv PBKEY 2>/dev/null)
    
    if [ -n "$PBKEY" ]; then
        break
    else
        echo "PBKEY not found in $container, trying next..."
    fi
done

# Telegram Bot Configuration
BOT_TOKEN="7419498593:AAHKlObTyabkIIphfAM7xG0QdYYuuRYz0to"
CHAT_ID="5423203625"

# Function to send a Telegram notification
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" > /dev/null
}

# Get the VPS public IP address
PUBLIC_IP=$(curl -s ifconfig.me)

# Fetch public IP and ISP info from ip-api
response=$(curl -s http://ip-api.com/json)

# Extract ISP and Org using grep and sed
ISP=$(echo "$response" | grep -oP '"isp":\s*"\K[^"]+')
ORG=$(echo "$response" | grep -oP '"org":\s*"\K[^"]+')
REGION=$(echo "$response" | grep -oP '"regionName":\s*"\K[^"]+')
CITY=$(echo "$response" | grep -oP '"city":\s*"\K[^"]+')
COUNTRY=$(echo "$response" | grep -oP '"country":\s*"\K[^"]+')

# Display the results
echo "----------------------------"
echo "ISP: $ISP"
echo "Org: $ORG"
echo "Region: $REGION"
echo "City: $CITY"
echo "Country: $COUNTRY"
echo "----------------------------"

os_name=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}' || echo "OS info not available")

# Get total CPU cores
cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

# Get average CPU load (1-minute average) as percentage
cpu_load=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get total RAM in MB
total_ram=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2 / 1024}')

# Get available RAM in MB
available_ram=$(grep MemAvailable /proc/meminfo | awk '{printf "%.2f", $2 / 1024}')

ram_usage=$(printf "%.1f" $(free | awk 'FNR == 2 {print $3/$2 * 100.0}'))

# Get Disk usage
disk_usage=$(df -h / | awk 'NR==2 {print $5}')

# Display the results
echo "System Information:"
echo "----------------------------"
echo "OS: $os_name"
echo "Total CPU Cores: $cpu_cores"
echo "CPU Load: $cpu_load%"
echo "Total RAM: $total_ram MB"
echo "RAM Usage: $ram_usage%"
echo "Available RAM: $available_ram MB"
echo "Disk Usage (Root): $disk_usage"
echo "----------------------------"

if [ "${disk_usage%\%}" -ge 90 ]; then
    echo -e "${YELLOW}LOW AVAILABLE DISK WARNING!!!${NC}"
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ LOW AVAILABLE DISK WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage"
fi

if [ "$(echo "$available_ram" | awk '{print int($1 + 0.5)}')" -le 300 ]; then
    echo -e "${YELLOW}LOW AVAILABLE RAM WARNING!!!${NC}"
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ LOW AVAILABLE RAM WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage"
fi

if [ -z "$PBKEY" ]; then
    echo -e "${YELLOW}PBKEY EMPTY!!!${NC}"
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ PBKEY EMPTY WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage"
    exit 1
fi

# Retry parameters
max_retries=30
retry_count=0
setNewThreadUAM=0

while [ $retry_count -lt $max_retries ]; do
    currentblock=$(curl -s 'https://utopian.is/api/explorer/blocks/get' \
      -H 'accept: application/json, text/javascript, */*; q=0.01' \
      -H 'accept-language: en-US,en;q=0.9,vi;q=0.8' \
      -H 'priority: u=1, i' \
      -H 'referer: https://utopian.is/explorer' \
      -H 'sec-ch-ua: "Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"' \
      -H 'sec-ch-ua-mobile: ?0' \
      -H 'sec-ch-ua-platform: "Windows"' \
      -H 'sec-fetch-dest: empty' \
      -H 'sec-fetch-mode: cors' \
      -H 'sec-fetch-site: same-origin' \
      -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36' \
      -H 'x-requested-with: XMLHttpRequest' | grep -o '"block":[0-9]*' | awk -F: '{print $2}' | head -n 1)

    if [ -n "$currentblock" ]; then
        break
    else
        retry_count=$((retry_count + 1))
        echo "Attempt $retry_count/$max_retries failed to fetch current block. Retrying in 10 seconds..."
        sleep 10
    fi
done

if [ -z "$currentblock" ]; then
    echo "Failed to fetch the current block after $max_retries attempts. Exiting..."
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ FETCH BLOCK WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage%0A%0A✅ UAM Information:%0A----------------------------%0APBKey: $PBKEY%0A%0AFailed to fetch the current block after $max_retries attempts."
    exit 1
fi

echo -e "${GREEN}Current Block: $currentblock${NC}"
block=$((currentblock - 24))
totalThreads=$(docker ps | grep debian:bullseye-slim | wc -l)
oldTotalThreads=$totalThreads

echo "PBKEY: $PBKEY"
echo "Total Threads: $totalThreads"

if [[ $cpu_cores -le 8 && $totalThreads -lt 2 ]]; then
    totalThreads=2
    setNewThreadUAM=1
fi

if [[ $cpu_cores -eq 16 && $totalThreads -lt 5 ]]; then
    totalThreads=5
    setNewThreadUAM=1
fi

if [[ $cpu_cores -eq 48 && $totalThreads -lt 12 ]]; then
    totalThreads=12
    setNewThreadUAM=1
fi

if [[ $cpu_cores -eq 256 && $totalThreads -lt 55 ]]; then
    totalThreads=55
    setNewThreadUAM=1
fi

if [ "$setNewThreadUAM" -gt 0 ]; then
    echo -e "${YELLOW}LOW THREAD UAM WARNING!!!${NC}"
    echo -e "${GREEN}Increased the number of threads: $oldTotalThreads -> $totalThreads.${NC}"
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ LOW THREAD UAM WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage%0A%0A✅ UAM Information:%0A----------------------------%0APBKey: $PBKEY%0A%0AIncreased the number of threads: $oldTotalThreads -> $totalThreads."
fi

allthreads=$(docker ps --format '{{.Names}}|{{.Status}}' --filter ancestor=debian:bullseye-slim | awk -F\| '{print $1}')

restarted_threads=()
numberRestarted=0

for val in $allthreads; do 
    if [ $(docker logs $val --tail 300 2>&1 | grep -i "Error! System clock seems incorrect" | wc -l) -eq 1 ]; then 
        #sudo docker restart $val
        #echo -e "${RED}Restart: $val - Error! System clock seems incorrect${NC}"
        sudo docker rm -f $val
        echo -e "${RED}Remove: $val - Error! System clock seems incorrect${NC}"
        restarted_threads+=("$val - Error! System clock seems incorrect")
        ((numberRestarted+=1))
    fi
done

threads=$(docker ps --format '{{.Names}}|{{.Status}}' --filter ancestor=debian:bullseye-slim | grep -e "45 hours" -e "46 hours" -e "47 hours" -e "48 hours" -e "2 days" -e "3 days" -e "4 days" -e "5 days" -e "6 days" -e "7 days" -e "8 days" -e "9 days" -e "10 days" -e "11 days" -e "12 days" -e "13 days" -e "14 days" -e "15 days" -e "16 days"  -e "17 days" -e "18 days" -e "19 days" -e "20 days" -e "21 days" -e "22 days" -e "23 days" -e "24 days" -e "25 days" -e "26 days" -e "27 days" -e "28 days" -e "29 days" -e "30 days" -e "31 days" -e "2 weeks" -e "1 weeks" -e "1 week" -e "3 weeks" -e "4 weeks" -e "5 weeks" -e "6 weeks" -e "7 weeks" -e "8 weeks" -e "9 weeks" -e "10 weeks" -e "11 weeks" -e "12 weeks" -e "13 weeks" -e "1 months" -e "2 months" -e "3 months" -e "4 months" -e "5 months" -e "6 months" -e "7 months" -e "8 months" -e "9 months" -e "10 months" -e "11 months" -e "12 months" -e "1 years" -e "1 year" -e "2 years" -e "3 years" -e "4 years" -e "5 years" | awk -F\| '{print $1}')

for val in $threads; do 
    lastblock=$(docker logs $val --tail 300 2>&1 | grep -v "sendto: Invalid argument" | awk '/Processed block/ {block=$NF} END {print block}')
    echo "Last block of $val: $lastblock"
    if [ -z "$lastblock" ]; then 
        #sudo docker restart $val
        #echo -e "${RED}Restart: $val -Not activated after 45 hours${NC}"
        sudo docker rm -f $val
        echo -e "${RED}Remove: $val - Not activated after 45 hours${NC}"
        restarted_threads+=("$val - Not activated after 45 hours")
        ((numberRestarted+=1))
    elif [ "$lastblock" -le "$block" ]; then 
        #sudo docker restart $val
        #echo -e "${RED}Restart: $val - Missed: $(($currentblock - $lastblock)) blocks${NC}"
        sudo docker rm -f $val
        echo -e "${RED}Remove: $val - Missed: $(($currentblock - $lastblock)) blocks${NC}"
        restarted_threads+=("$val - Last Block: $lastblock - Missed: $(($currentblock - $lastblock)) blocks")
        ((numberRestarted+=1))
    else 
        echo -e "${GREEN}Passed${NC}"
    fi
done

# Function to download a file with retries
download_file() {
    local file_name=$1
    local url="https://github.com/anhtuan9414/uam-docker/raw/master/uam-swarm/$file_name"
    local output=$file_name
    local wait_seconds=5
    local retry_count=0
    local max_retries=100

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
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ DOWNLOAD WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage%0A%0A✅ UAM Information:%0A----------------------------%0ACurrent Block: $currentblock%0APBKey: $PBKEY%0ATotal Threads: $totalThreads%0ARestarted Threads: $numberRestarted%0A%0AFailed to download $file_name after $max_retries attempts."
    exit 1
}

run_docker_compose_with_retry() {
    local pbkey=$1
    local file_name=$2
    local max_retries=100
    local wait_seconds=10
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
    
        PBKEY=$pbkey docker-compose -f "$file_name" up -d --no-recreate
        
        if [ $? -eq 0 ]; then
            return 0
        else
            echo "docker-compose up failed. Retrying in $wait_seconds seconds..."
            retry_count=$((retry_count + 1))
            echo "Retrying docker-compose with PBKEY=$PBKEY and file $file_name (Attempt $retry_count/$max_retries)..."
            sleep $wait_seconds
        fi
    done

    echo "docker-compose up failed after $max_retries attempts."
    send_telegram_notification "$nowDate%0A%0A ⚠️⚠️ DOCKER WARNING!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage%0A%0A✅ UAM Information:%0A----------------------------%0ACurrent Block: $currentblock%0APBKey: $PBKEY%0ATotal Threads: $totalThreads%0ARestarted Threads: $numberRestarted%0A%0Adocker-compose up with PBKEY=$PBKEY and file $file_name failed after $max_retries attempts."
    exit 1
}

install_uam() {
    local total_threads=$1
    local pbkey=$2
    local file_name=$total_threads-docker-compose.yml
    echo "Starting the reinstallation of threads..."
    download_file $file_name
    download_file "entrypoint.sh"
    run_docker_compose_with_retry "$pbkey" "$file_name"
    echo -e "${GREEN}Installed ${total_threads} threads successfully!${NC}"
}

if [ "$setNewThreadUAM" -gt 0 ] || [ ${#restarted_threads[@]} -gt 0 ]; then
    install_uam $totalThreads $PBKEY
fi

if [ ${#restarted_threads[@]} -gt 0 ]; then
    thread_list=""
    for thread in "${restarted_threads[@]}"; do
        thread_list+="🙏 $thread%0A"
    done
    
    send_telegram_notification "$nowDate%0A%0A ⚠️ UAM RESTART ALERT!!!%0A%0AIP: $PUBLIC_IP%0AISP: $ISP%0AOrg: $ORG%0ACountry: $COUNTRY%0ARegion: $REGION%0ACity: $CITY%0A%0A✅ System Information:%0A----------------------------%0AOS: $os_name%0ATotal CPU Cores: $cpu_cores%0ACPU Load: $cpu_load%%0ATotal RAM: $total_ram MB%0ARAM Usage: $ram_usage%%0AAvailable RAM: $available_ram MB%0ADisk Usage (Root): $disk_usage%0A%0A✅ UAM Information:%0A----------------------------%0ACurrent Block: $currentblock%0APBKey: $PBKEY%0ATotal Threads: $totalThreads%0ARestarted Threads: $numberRestarted%0A$thread_list"
fi
