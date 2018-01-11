#!/usr/bin/env bash

if [ ! "${USER}" == "root" ]; then
    echo "This script must be run as user 'root'."
    exit 1
fi

apt-get install -y libatlas-dev
