#!/bin/bash
docker rm -f $(docker ps -a -q)
# sudo docker rm -f genesis-creator geth-db-cleaner geth-genesis geth-execution beacon-1 beacon-2 beacon-3 beacon-4 validator-1 validator-2 validator-3 validator-4 2>/dev/null
rm -Rf ./consensus/beacondata* ./consensus/validatordata* ./consensus/genesis.ssz
rm -Rf ./execution/geth