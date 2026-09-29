#!/usr/bin/env bash
# EC2(Ubuntu 24.04) 초기 설정: Docker, swap, opensearch용 vm.max_map_count
set -euo pipefail

# --- Docker Engine + Compose plugin ---
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
fi

# --- opensearch: vm.max_map_count ---
if ! grep -q '^vm.max_map_count' /etc/sysctl.conf 2>/dev/null; then
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -w vm.max_map_count=262144
fi

# --- swap (t3.medium 등 저메모리 인스턴스 대비) ---
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

mkdir -p ~/clothesplz
echo "완료. ~/clothesplz 에 docker-compose.prod.yaml, docker/, .env 배치 후 docker compose -f docker-compose.prod.yaml up -d 실행."
echo "docker 그룹 적용 위해 재로그인 필요할 수 있음."
