#!/bin/bash
IFS=$'\n'
stat=$(etckeeper vcs status --short)
diff=$(etckeeper vcs diff)

if [ -z "${stat}" ]; then
    exit 0
fi

echo "####"
for d in "${stat[@]}"; do
    echo "$d"
done

echo "> //# etckeeper vcs diff"
for d in "${diff[@]}"; do
    echo "$d"
done
exit -1;
