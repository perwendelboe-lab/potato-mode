#!/bin/bash
cd "$(dirname "$0")/.."; exec ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i id_ed25519 -p 2223 potato@127.0.0.1 "$@"
