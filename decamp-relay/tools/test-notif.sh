#!/bin/bash
# 1. Go to debug page in the app, copy the notification token
# 2. export it as an environment variable
#    export APNS_DEVICE_TOKEN="your_device_token_here"
# 3. Run this script to send a test notification
# Make sure decamp-relay server is running locally on port 8080

curl -X POST http://localhost:8080/send \
     -H "Content-Type: application/json" \
     -d "{
       \"device_tokens\": [\"$APNS_DEVICE_TOKEN\"],
       \"title\": \"Test Notification\",
       \"body\": \"This is a test from decamp-relay\",
       \"badge\": 1
     }"
