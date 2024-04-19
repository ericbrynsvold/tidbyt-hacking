#!/bin/bash

# optionally load env variables
if [ -n "${TIDBYT_API_TOKEN+set}" ]
then
    echo "vars are set"
else
    source ".env"
fi

installationId=$1
fileName=$2
directory=$3
sourceFile="$directory/$fileName.star"
outputFile="$directory/$fileName.webp"
tidbytApiToken=$TIDBYT_API_TOKEN
tidbytDeviceId=$TIDBYT_DEVICE_ID
tidbytApiTokenKyle=$TIDBYT_API_TOKEN_KYLE
tidbytDeviceIdKyle=$TIDBYT_DEVICE_ID_KYLE
tidbytApiTokenJason=$TIDBYT_API_TOKEN_JASON
tidbytDeviceIdJason=$TIDBYT_DEVICE_ID_JASON

# build
pixlet render $sourceFile
# upload
pixlet push --installation-id $installationId $tidbytDeviceId $outputFile --api-token $tidbytApiToken
# upload to Kyle
pixlet push --installation-id $installationId $tidbytDeviceIdKyle $outputFile --api-token $tidbytApiTokenKyle
# upload to Jason
pixlet push --installation-id $installationId $tidbytDeviceIdJason $outputFile --api-token $tidbytApiTokenJason