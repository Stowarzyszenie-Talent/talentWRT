#!/usr/bin/env bash

set -euo pipefail
IFS=$'\t\n'

tmp=$(mktemp -d "/tmp/luci-app-talent-ipkg-XXXXXX")
# worst lint ever
# shellcheck disable=2064
trap "rm -r $tmp" EXIT

echo 2.0>"$tmp/debian-binary"
tar cvzf "$tmp/control.tar.gz" -C control --owner=0 --group=0 .
tar cvzf "$tmp/data.tar.gz" -C data --owner=0 --group=0 .

tar cvzf "luci-app-talent.ipk" -C "$tmp" --owner=0 --group=0 .
