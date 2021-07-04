set -ex

sudo apt install cmake librdkafka-dev cpulimit pkg-config libssl-dev nlohmann-json3-dev nasm g++ libgmp-dev

cargo install --git https://github.com/Fluidex/plonkit
cargo install sqlx-cli

nvm install v16
nvm use v16
nvm alias default v16
npm install -g snarkit
