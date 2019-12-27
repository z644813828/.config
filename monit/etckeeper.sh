#!/bin/bash
IFS=$'\n' etc=$(etckeeper vcs diff)
if [ -z "${etc}" ]; then
    exit 0
fi
echo "//# etckeeper vcs diff"
for d in "${etc[@]}"; do
    echo "$d"
done
exit -1;
