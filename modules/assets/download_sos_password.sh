#!/bin/bash

/usr/bin/scp -i $ssh_private_key_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q root@$host:/tmp/*_secret.asc .
