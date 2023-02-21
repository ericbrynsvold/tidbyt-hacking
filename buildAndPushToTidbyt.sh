#!/bin/bash
# get current directory of script, no matter where it's called from
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# optionally load env variables
if [ -n "${TIDBYT_API_TOKEN+set}" ]
then
    echo "vars are set"
else
    source "$parent_path/.env"
fi

appName=$1
sourceFile="$appName.star"
outputFile="$appName.webp"
tidbytApiToken=$TIDBYT_API_TOKEN
tidbytDeviceId=$TIDBYT_DEVICE_ID

# build
pixlet render $sourceFile
# upload
pixlet push --installation-id $appName $tidbytDeviceId $outputFile --api-token $tidbytApiToken