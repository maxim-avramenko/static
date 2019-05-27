#!/usr/bin/env bash

echo "List of packages to install: "${LUAROCKS_INSTALL}""
LUAROCKS=( ${LUAROCKS_INSTALL} )
for i in "${LUAROCKS[@]}"
do
    echo "luarocks install "${i}""
    luarocks install ${i}
done
exit 0
