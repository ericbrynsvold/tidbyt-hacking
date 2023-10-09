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
tidbytApiTokenJason=$TIDBYT_API_TOKEN_JASON
tidbytDeviceIdJason=$TIDBYT_DEVICE_ID_JASON

# build
pixlet render $sourceFile
# upload
(set -x; pixlet push --installation-id $appName $tidbytDeviceId $outputFile --api-token $tidbytApiToken)
# upload to Kyle
pixlet push --installation-id $appName $tidbytDeviceIdKyle $outputFile --api-token $tidbytApiTokenKyle
# upload to Jason
pixlet push --installation-id $appName $tidbytDeviceIdJason $outputFile --api-token $tidbytApiTokenJason