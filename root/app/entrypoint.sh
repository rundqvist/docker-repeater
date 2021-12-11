#!/bin/bash

sPath="/app/supervisor"
mkdir -p $sPath

#
# Function to get interface of an ip address (ending with .0)
#
function getInterface {
    if=$(route -n | grep "$1" | awk '{print $8}')
    echo "$if"
}

#
# Set up mDNS repeater
#
if [ -z "$MDNS" ]
then
    echo "No MDNS repeat configured"
else
    echo "Parsing MDNS configuration: $MDNS"

    IFS=';' read -r -a mdnsconfigs <<< "$MDNS"
    
    for mdnsconfig in $mdnsconfigs
    do
        echo "Parsing MDNS set: $mdnsconfig"
        
        items=($(echo "$mdnsconfig" | tr ":" " "))
        source=${items[0]}
        deststr=$(echo "${items[1]}" | tr "," " ")
        echo "repeat $source to $deststr -"

        #
        # Resolve source interface
        #
        sourceInterface=$(getInterface "$source")
        if [ -z "$sourceInterface" ]
        then
            echo "Interface not found for $source"
            exit 1
        fi
        echo "- source $source interface $sourceInterface"

        #
        # Resolve destination interface(s)
        #
        destInterfaces=""
        destarr=("$deststr")
        for dest in $destarr
        do
            destInterface=$(getInterface "$dest")
            if [ -z "$destInterface" ]
            then
                echo "Interface not found for $dest"
                exit 1
            fi
            echo "- dest $dest interface $destInterface"
            destInterfaces+=" ${destInterface}"
        done

        #
        # Configure supervisor
        #
        echo "Loop done: $sourceInterface$destInterfaces"
        app="mdns-$sourceInterface"

        echo "[program:$app]" > "$sPath/$app.conf"
        echo "command = /usr/bin/mdns-repeater -f $sourceInterface$destInterfaces" >> "$sPath/$app.conf"
        echo "autorestart = true" >> "$sPath/$app.conf"
        echo "pidfile = /run/$app.pid" >> "$sPath/$app.conf"
        echo "priority = 2" >> "$sPath/$app.conf"
    done
fi

#
# Setup websocket proxy
#
if [ -z "$WS" ]
then
    echo "No WS configured"
else
    echo "Parsing WS configuration: $WS"

    IFS=';' read -r -a wsconfigs <<< "$WS"
    
    for wsconfig in $wsconfigs
    do
        echo "Parsing WS set: $wsconfig"

        items=($(echo "$wsconfig" | tr ":" " "))

        targetIp=${items[0]}
        ports=$(echo "${items[1]}" | tr "," " ")
        
        echo 'worker_processes  1;' >> /app/nginx.conf
        echo 'error_log  /var/log/error.log;' >> /app/nginx.conf
        echo 'pid        /run/nginx.pid;' >> /app/nginx.conf
        echo 'worker_rlimit_nofile 8192;' >> /app/nginx.conf
        echo 'daemon off;' >> /app/nginx.conf
        echo 'events {' >> /app/nginx.conf
        echo '  worker_connections  4096;' >> /app/nginx.conf
        echo '}' >> /app/nginx.conf
        echo 'http {' >> /app/nginx.conf
        echo '    map $http_upgrade $connection_upgrade {' >> /app/nginx.conf                
        echo '        default upgrade;' >> /app/nginx.conf                       
        echo "        '' close;" >> /app/nginx.conf                                                                                                      
        echo '    }' >> /app/nginx.conf                                                                                                                  
        echo '' >> /app/nginx.conf                                                           
        echo '    upstream websocket {' >> /app/nginx.conf

        for port in $ports
        do
            echo "        server $targetIp:$port;" >> /app/nginx.conf
        done

        #echo '        server IP_OF_YOUR_TV:8001;' >> /app/nginx.conf                
        #echo '        server IP_OF_YOUR_TV:8002;' >> /app/nginx.conf                                                                                        
        echo '    }' >> /app/nginx.conf                                                                                                                  
        echo '' >> /app/nginx.conf                                                           
        echo '    server {' >> /app/nginx.conf

        for port in $ports
        do
            echo "        listen $port;" >> /app/nginx.conf
        done
                                                                                                    
        echo '        location / {' >> /app/nginx.conf                                       
        echo '            proxy_pass http://websocket;' >> /app/nginx.conf                   
        echo '            proxy_http_version 1.1;' >> /app/nginx.conf                        
        echo '            proxy_set_header Upgrade $http_upgrade;' >> /app/nginx.conf                                                                    
        echo '            proxy_set_header Connection $connection_upgrade;' >> /app/nginx.conf                                                           
        echo '            proxy_set_header Host $host;' >> /app/nginx.conf                   
        echo '        }' >> /app/nginx.conf                                                                                                              
        echo '    }' >> /app/nginx.conf                                                                                                                  
        echo '}' >> /app/nginx.conf

        #
        # Configure supervisor
        #
        echo "Loop done"
        app="nginx"

        echo "[program:$app]" > "$sPath/$app.conf"
        echo "command = /usr/sbin/nginx -c /app/nginx.conf" >> "$sPath/$app.conf"
        echo "autorestart = true" >> "$sPath/$app.conf"
        echo "pidfile = /run/$app.pid" >> "$sPath/$app.conf"
        echo "priority = 2" >> "$sPath/$app.conf"

    done
fi

# if expr "${PNET}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
# 	route add -net ${PNET} netmask 255.255.255.0 gw $(route -n | grep 'UG[ \t]' | awk '{print $2}')
# fi

echo "Starting supervisor"

exec /usr/bin/supervisord -c /app/supervisord.conf