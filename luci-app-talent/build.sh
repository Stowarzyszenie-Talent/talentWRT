#!/usr/bin/env bash

set -euo pipefail
IFS=$'\t\n'

tmp=$(mktemp -d "/tmp/luci-app-talent-ipkg-XXXXXX")
# worst lint ever
# shellcheck disable=2064
trap "rm -r $tmp" EXIT

echo 2.0>"$tmp/debian-binary"
tar cvf "$tmp/control.tar" -C control --exclude=control .

sed "s/@PKG_SIZE@/$(du -s data | awk '{ printf $0 * 1000 }')/g" control/control >"$tmp/control"
tar rvf "$tmp/control.tar" -C "$tmp" control --owner=0 --group=0
rm "$tmp/control"
gzip "$tmp/control.tar"

tar cvzf "$tmp/data.tar.gz" -C data .

tar cvzf "luci-app-talent.ipk" -C "$tmp" .
