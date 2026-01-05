#!/usr/bin/env bash
 
rm -rf fullhtml
rm -f PVS-Studio.log

/opt/pvs_add_comment -c 2 .
pvs-studio-analyzer trace -- make -I$CPATH -I../include
pvs-studio-analyzer analyze --incremental
# pvs-studio-analyzer analyze -C e2k-linux-gcc -e /opt --incremental
plog-converter -a GA:1,2 -t fullhtml -o . PVS-Studio.log

sed -i '/PVS-Studio/d' *
sed -i '/PVS-Studio/d' src/*
sed -i '/PVS-Studio/d' include/*
sed -i '/PVS-Studio/d' examples/*

exit 0;

rm -rf fullhtml
rm -f PVS-Studio.log

/opt/pvs_add_comment -c 2 .
pvs-studio-analyzer trace -- make
pvs-studio-analyzer analyze --incremental
# pvs-studio-analyzer analyze -C e2k-linux-gcc -e /opt --incremental
plog-converter -a GA:1,2 -t fullhtml -o . PVS-Studio.log

sed -i '/PVS-Studio/d' src/*
sed -i '/PVS-Studio/d' examples/*
