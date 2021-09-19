#!/bin/bash
set -eux

function install_rust() {
  echo 'install rust'
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
}

function install_docker() {
  echo 'install docker'
  curl -fsSL https://get.docker.com | bash
  sudo groupadd docker
  sudo usermod -aG docker $USER
  newgrp docker
  sudo systemctl start docker
  sudo systemctl enable docker
}

function install_docker_compose() {
  echo 'install docker compose'
  sudo curl -L "https://github.com/docker/compose/releases/download/1.28.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

function install_node() {
  echo 'install node'
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
  nvm install v16
  nvm use v16
  nvm alias default v16
  npm install --global yarn
}

function install_sys_deps() {
  echo 'install system deps'
  sudo apt install cmake librdkafka-dev libpq-dev cpulimit pkg-config libssl-dev nlohmann-json3-dev nasm gcc g++ libgmp-dev postgresql-client-12
}

function install_cli_tools() {
  echo 'install some cli tools'
  npm install -g snarkit
  npm install -g ganache-cli
  cargo install --git https://github.com/fluidex/plonkit
  cargo install sqlx-cli
  cargo install envsub
}

function install_dev_deps() {
  echo 'install some useful tools for development'
  go get mvdan.cc/sh/v3/cmd/shfmt
}

function install_all() {
  install_sys_deps
  install_rust
  install_docker
  install_docker_compose
  install_node
  install_cli_tools
}

install_all
