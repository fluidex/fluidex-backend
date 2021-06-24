#!/bin/bash
set -uex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# make sure submodule is correctly cloned!!
git submodule update --init --recursive
if [ -z ${CI+x} ]; then git pull --recurse-submodules; fi
