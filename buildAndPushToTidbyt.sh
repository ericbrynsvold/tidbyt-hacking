#!/bin/bash
# get current directory of script, no matter where it's called from
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# load env variables
source "$parent_path/.env"

appName=$1
sourceFile="$appName.star"
outputFile="$appName.webp"
tidbytApiToken=$TIDBYT_API_TOKEN
tidbytDeviceId=$TIDBYT_DEVICE_ID

# build
pixlet render $sourceFile
# upload
pixlet push --installation-id $appName $tidbytDeviceId $outputFile --api-token $tidbytApiToken