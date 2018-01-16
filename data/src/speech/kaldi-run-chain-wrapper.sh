#!/usr/bin/bash

now=$(date -u "+%Y-%m-%d-%H-%M-%S")

./run-chain.sh 2>&1 | tee -a "run-chain-${now}.log"
