#!/bin/bash
set -eux

git submodule foreach git pull origin master
