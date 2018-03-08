#!/bin/bash

now=$(date -u "+%Y-%m-%d-%H-%M-%S")

./run-chain-cpu.sh $@ 2>&1 | tee -a "run-chain-cpu-${now}.log"
