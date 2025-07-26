#!/usr/bin/env bash

{
    echo 'set -eu';
    echo 'echo "#!/bin/sh" > /tmp/fakedoas';
    echo 'echo "\"\$@\"" >> /tmp/fakedoas';
    echo "chmod +x /tmp/fakedoas";
    echo 'apk add --no-cache abuild';
    echo 'SUDO=/tmp/fakedoas abuild-keygen -ainq';
    echo 'abuild -dFC /mnt -P /tmp/';
    echo "chown $(id -u):$(id -g) /tmp/x86_64/*.apk";
    echo 'cp -a /tmp/x86_64/*.apk /mnt/luci-app-talent.apk';
} | docker run --rm -iv ./:/mnt alpine sh
