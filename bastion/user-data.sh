#!/usr/bin/env bash

set -e
cat <<EOF > foo
Host *
  IdentityFile ~/.ssh/key.pem
  User ec2-user
EOF