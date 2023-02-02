#!/bin/sh
## Create a generic configuration and set of keys based on the current hostname if they don't exist
if [ ! -f /etc/freeDiameter/freeDiameter.conf ]; then
    ## Based on the hostname...
    HOSTNAME=`hostname`
    ## Create the freeDiameter config
    mv /etc/freeDiameter/freeDiameter.conf.sample /etc/freeDiameter/freeDiameter.conf
    sed --in-place "/^#Identity.*/s//Identity = \"${HOSTNAME}\";/g" /etc/freeDiameter/freeDiameter.conf
    sed --in-place "/^#Realm/s//Realm/g" /etc/freeDiameter/freeDiameter.conf
    sed --in-place '/^#TLS_CA.*/s//TLS_CA = "\/etc\/ssl\/certs\/cacert.pem";/g' /etc/freeDiameter/freeDiameter.conf

    ## Create the intermediate CA, and add it to the root certificates
    [ -d /etc/ssl/private ] || mkdir -p /etc/ssl/private
    cd /etc/ssl
    sed --in-place "/server.example.com/s//${HOSTNAME}/g" diametercert.template
    ( [ -f /etc/ssl/private/cakey.pem ] ) || ( umask 277 && certtool --generate-privkey > private/cakey.pem )
    ( [ -f /etc/ssl/certs/cacert.pem ] ) || ( certtool --generate-self-signed \
            --template rootcert.template \
            --load-privkey private/cakey.pem \
            --outfile certs/cacert.pem )
    cp certs/cacert.pem /usr/share/ca-certificates/
    update-ca-certificates

    ## Create the freeDiameter Certificate based on our intermediate CA
    [ -f /etc/ssl/private/freeDiameter.key ] || ( umask 277 && certtool --generate-privkey > private/freeDiameter.key )
    [ -f /etc/ssl/certs/freeDiameter.pem ] || ( certtool --generate-certificate \
            --template diametercert.template \
            --load-privkey private/freeDiameter.key \
            --load-ca-certificate certs/cacert.pem \
            --load-ca-privkey private/cakey.pem \
            --outfile certs/freeDiameter.pem )
fi

if [ -f /etc/freeDiameter/freeDiameter.conf.customization ]; then
  cat /etc/freeDiameter/freeDiameter.conf.customization >> /etc/freeDiameter/freeDiameter.conf
fi

if [ -f /etc/freeDiameter/hosts.customization ]; then
  cat /etc/freeDiameter/hosts.customization >> /etc/hosts
fi

# in some cases we must wait e.g. for other peers
[  -z "$DELAY_ENABLED" ] || sleep 10

#RUN!!
exec /usr/bin/freeDiameterd
