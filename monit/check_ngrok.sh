#!/bin/bash
NGROK_RESTART_CMD="/opt/ngrok start -all > /dev/null &"
NGROK_STATUS_FILE="localhost:4040/api/tunnels"
PARSE_CMD_SSH="jq -r '.tunnels[]|select(.name==\"server_ssh\")|.public_url'"
PARSE_CMD_WEB="jq -r '.tunnels[]|select(.name==\"asus_router\")|.public_url'"

STATUS=$(curl -s $NGROK_STATUS_FILE)
if [[ "$?" -ne 0 ]]; then
    echo "_"
    echo " "
    echo "Restarting ngrok service"
    echo " "
    eval $NGROK_RESTART_CMD
    sleep 2
else
    exit 0
fi

CMD="curl -s $NGROK_STATUS_FILE | $PARSE_CMD_SSH"
DATA=$(eval $CMD)
DATA=$(echo $DATA | awk '{ print substr ($0, 7 ) }')
echo $DATA | awk -F ":" '{print "ssh -p "$2 " dmitriy@"$1}'

CMD="curl -s $NGROK_STATUS_FILE | $PARSE_CMD_WEB"
DATA=$(eval $CMD)
echo $DATA

exit 1;
