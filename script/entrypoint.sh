#!/bin/sh

set -e -x

echo "start nginx"

#set TZ
test $TZ && cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone || true

#setup ssl keys
echo "ssl_key=${SSL_KEY:=le-key.pem}, ssl_cert=${SSL_CERT:=le-crt.pem}, ssl_chain_cert=${SSL_CHAIN_CERT:=le-chain-crt.pem}"
SSL_KEY=/etc/nginx/ssl/${SSL_KEY}
SSL_CERT=/etc/nginx/ssl/${SSL_CERT}
SSL_CHAIN_CERT=/etc/nginx/ssl/${SSL_CHAIN_CERT}

mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/ssl

#copy /etc/nginx/service*.conf if any of servcie*.conf mounted
if (ls /etc/nginx/service*.conf 1>/dev/null 2>/dev/null); then
    cp -fv /etc/nginx/service*.conf /etc/nginx/conf.d/
fi

#replace SSL_KEY, SSL_CERT and SSL_CHAIN_CERT by actual keys
sed -i "s|SSL_KEY|${SSL_KEY}|g" /etc/nginx/conf.d/*.conf
sed -i "s|SSL_CERT|${SSL_CERT}|g" /etc/nginx/conf.d/*.conf
sed -i "s|SSL_CHAIN_CERT|${SSL_CHAIN_CERT}|g" /etc/nginx/conf.d/*.conf

#generate dhparams.pem
if [ ! -f /etc/nginx/ssl/dhparams.pem ]; then
    echo "make dhparams"
    cd /etc/nginx/ssl
    openssl dhparam -out dhparams.pem 2048
    chmod 600 dhparams.pem
fi

#disable ssl configuration and let it run without SSL
mv -v /etc/nginx/conf.d /etc/nginx/conf.d.disabled

(
    sleep 5 #give nginx time to start

    mv -v /etc/nginx/conf.d.disabled /etc/nginx/conf.d #enable
    echo "start letsencrypt updater"

    if (find /etc/nginx/ssl -name `basename "${SSL_CERT}"` -mtime -7 -exec false {} +); then
        echo "trying to update letsencrypt ..."
        /le.sh
        echo "reload nginx with ssl"
        nginx -s reload
    else
        echo "certs already updated"
    fi

    while :
    do
        sleep 7d
        echo "trying to update letsencrypt ..."
        /le.sh
        echo "reload nginx with ssl"
        nginx -s reload
    done
) &

exec nginx -g "daemon off;"
