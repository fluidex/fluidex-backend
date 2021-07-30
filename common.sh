export OS="$(uname -s)"

function retry_cmd_until_ok() {
  set +e
  $@
  while [[ $? -ne 0 ]]; do
    sleep 1
    $@
  done
  set -e
}

function docker_rm() {
  if [ $OS = "Darwin" ]; then
    rm $@
  else
    sudo rm $@
  fi
}
