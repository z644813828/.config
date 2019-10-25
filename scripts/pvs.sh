#!/bin/bash
 
rm -rf fullhtml
rm -f PVS-Studio.log
/opt/pvs_add_comment -c 2 .
pvs-studio-analyzer trace -- make
pvs-studio-analyzer analyze -C e2k-linux-gcc
plog-converter -a GA:1,2 -t fullhtml -o . PVS-Studio.log

sed -i '/PVS-Studio/d' src/*
sed -i '/PVS-Studio/d' examples/*
