#!/bin/bash

recovery_user=sos
keyfile=$recovery_user.asc
email=$recovery_user@openmesh.network

password=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16 | xargs)
salt="Q9"
hash=$(perl -e "print crypt('${password}','${salt}')")

cat <<EOF > /tmp/$keyfile
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEZSzgURYJKwYBBAHaRw8BAQdABscJ5RxO2TIWCi8x11LjENlwJalmMMmB5ARa
f/nlg360GnNvcyA8c29zQG9wZW5tZXNoLm5ldHdvcms+iJMEExYKADsWIQTYai8y
g0wAZN6fwbb5AccRSLmVlgUCZSzgUQIbAwULCQgHAgIiAgYVCgkICwIEFgIDAQIe
BwIXgAAKCRD5AccRSLmVlsruAQD7srEVktnC1VnvkX7dzwdJjCRyaRSI0mxb1ceL
ML5DbQD+LdVyqqBOy25lRDHzGmoTNZHTAjN4iOREpEcUWCBGawK4OARlLOBREgor
BgEEAZdVAQUBAQdALnLeTsydbzXRgqHEv6gekOpzsMYXuvoHu8URIr+mNVoDAQgH
iHgEGBYKACAWIQTYai8yg0wAZN6fwbb5AccRSLmVlgUCZSzgUQIbDAAKCRD5AccR
SLmVlrE2AQCaysdHge0P8+oBSfHPVtZ5eten7akpi33nUCvqRj+k7wEApqTQ8eLj
XylbmbnY/mzeOUT78kP6Ew20w7L6eBAu/Ak=
=48vs
-----END PGP PUBLIC KEY BLOCK----
EOF

export hostname=$(hostname)

while true; do 
  if ! ( find /tmp/${hostname}_secret.asc -size +1 ) > /dev/null 2>&1; then
    useradd -m $recovery_user
    usermod --password $hash $recovery_user
    echo "sos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sos
    gpg --no-tty --import /tmp/$keyfile
    gpg --always-trust --armor --encrypt --no-tty -o /tmp/${hostname}_secret.asc -r $email <<< "$password"
  else break
  fi
done
