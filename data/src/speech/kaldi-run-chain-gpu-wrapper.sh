#!/bin/bash

now=$(date -u "+%Y-%m-%d-%H-%M-%S")

./run-chain-gpu.sh 2>&1 | tee -a "run-chain-gpu-${now}.log"
