#!/bin/bash

# optionally load env variables
if [ -n "${TIDBYT_API_TOKEN+set}" ]
then
    echo "vars are set"
else
    source ".env"
fi

appName=$1
directory=$2
sourceFile="$directory/$appName.star"
outputFile="$directory/$appName.webp"
tidbytApiToken=$TIDBYT_API_TOKEN
tidbytDeviceId=$TIDBYT_DEVICE_ID
tidbytApiTokenKyle=$TIDBYT_API_TOKEN_KYLE
tidbytDeviceIdKyle=$TIDBYT_DEVICE_ID_KYLE

# build
pixlet render $sourceFile
# upload
pixlet push --installation-id $appName $tidbytDeviceId $outputFile --api-token $tidbytApiToken
# upload to Kyle
pixlet push --installation-id $appName $tidbytDeviceIdKyle $outputFile --api-token $tidbytApiTokenKyle