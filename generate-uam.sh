#!/bin/bash
# Thay đổi quyền truy cập của socket Docker
sudo chmod 666 /var/run/docker.sock

# Kiểm tra xem tham số thứ hai (number) có được cung cấp không, nếu không thì tính toán giá trị động
if [ -z "$2" ]; then
  number=$(docker ps | grep tuanna9414/uam:v2 | wc -l)
else
  number=$2
fi

# Xóa tất cả các container Docker dựa trên image tuanna9414/uam:v2 và xóa một thư mục
sudo docker rm -f $(docker ps -aq --filter ancestor=tuanna9414/uam:v2) && sudo rm -rf /opt/uam_data

# Tạo tên tệp dựa trên số lượng container
file_name=$number-docker-compose.yml

# Xóa các tệp cụ thể
rm entrypoint*
rm $file_name

# Tải phiên bản mới của các tệp
wget https://github.com/anhtuan9414/uam-docker/raw/master/uam-swarm/$file_name
wget https://github.com/anhtuan9414/uam-docker/raw/master/uam-swarm/entrypoint.sh

# Chạy Docker Compose với biến môi trường PBKEY được cung cấp
sudo PBKEY=$1 docker-compose -f $file_name up -d
