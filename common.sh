export OS="$(uname -s)"

DX_CLEAN=${DX_CLEAN^^}
export DX_CLEAN="${DX_CLEAN:-TRUE}"

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
