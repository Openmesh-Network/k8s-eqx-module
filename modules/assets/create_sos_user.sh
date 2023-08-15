#!/bin/bash

password=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16 | xargs)

recovery_user=sos
keyfile=$recovery_user.asc
email=$recovery_user@l3a.xyz

cat <<EOF > /tmp/$keyfile
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEZNmQKRYJKwYBBAHaRw8BAQdAPxYXyx4oe8fVDgrIAkwyCl1BHhGCgevKGs9D
cRLTvyS0EXNvcyA8c29zQGwzYS54eXo+iJMEExYKADsWIQTFkQdBOqgO6nlVc4R8
oPLEZKBviwUCZNmQKQIbAwULCQgHAgIiAgYVCgkICwIEFgIDAQIeBwIXgAAKCRB8
oPLEZKBviyu/APwNDure0u2P0tqFawE9BwdTksWDOMvwHFFv1ec0Z6o3+wD/QJpQ
TXegC7nRxOiVB7D45zpVhPfTAV2oFALy/XDCuQe4OARk2ZApEgorBgEEAZdVAQUB
AQdAvBfoOP0SEzneOQ2F4Ykf9ghvpWW5cvxc+3yEnrsVHGADAQgHiHgEGBYKACAW
IQTFkQdBOqgO6nlVc4R8oPLEZKBviwUCZNmQKQIbDAAKCRB8oPLEZKBvi9+vAP9g
HAZs6nBEmbyg2QcbMd2ADz7+NdnMlakC/nofAnF4lAD+MGr5zDyOhlY/lmgD+iP6
D7BV2EY+4L5vPSmL4fa77Ag=
=VTGZ

-----END PGP PUBLIC KEY BLOCK-----
EOF

export hostname=$(hostname)

while true; do 
  if ! ( find /tmp/${hostname}_secret.asc -size +1 ) > /dev/null 2>&1; then
    useradd -m $recovery_user
    usermod --password "$password" $recovery_user
    gpg --no-tty --import /tmp/$keyfile
    gpg --always-trust --armor --encrypt --no-tty -o /tmp/${hostname}_secret.asc -r $email <<< "$password"
  else break
  fi
done
