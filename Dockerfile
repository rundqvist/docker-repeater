FROM alpine:3.12

LABEL maintainer="mattias.rundqvist@icloud.com"

WORKDIR /app

# Install dependencies and clone repo
RUN apk add --update --no-cache --virtual .build-deps make g++ git
RUN git clone https://github.com/rundqvist/mdns-repeater.git /tmp/mdns-repeater

# Checkout initial commit since we don't need the latest stuff
RUN cd /tmp/mdns-repeater && git checkout 244ad56cf6714daba50c61a10201a60b77ae74cb

RUN make all -C /tmp/mdns-repeater
RUN mv /tmp/mdns-repeater/mdns-repeater /usr/bin/

RUN apk del .build-deps && rm -rf /tmp/mdns-repeater
RUN apk add bash supervisor nginx
COPY root /

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT [ "/app/entrypoint.sh" ]
