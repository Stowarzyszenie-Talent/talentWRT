#!/usr/bin/env bash
set -euo pipefail
dir=$(mktemp -d)
trap "rm -rf $dir" EXIT
export HOME=$dir 
abuild-keygen -ainq

abuild -d
rm -r pkg
