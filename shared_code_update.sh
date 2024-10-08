#!/bin/bash

# This script should be run from within the app/shared folder of the
# API that you wish to match the shared code with bsas.
#
# The script assumes all API repos are within the same working directory.


# Configurable variables if not standard. working_folder could be
# set to something like "/Users/username/workspace/" for example.
working_folder="../"
bsas_name="self-assessment-bsas-api"

# Go up two levels to base folder then get this API name.
cd ../../
this_api_name=${PWD##*/}

# Create location variables.
bsas_location="$working_folder$bsas_name"
this_api_location="$working_folder$this_api_name"

# Create the shared folder variables.
bsas_shared_app="$bsas_location/app/shared"
bsas_shared_it="$bsas_location/it/shared"
bsas_shared_test="$bsas_location/test/shared"

this_api_shared_app="$this_api_location/app/shared"
this_api_shared_it="$this_api_location/it/shared"
this_api_shared_test="$this_api_location/test/shared"

# Get current date and time format: YYYYMMDD-HHMM.
time_now=$(date +"%Y%m%d-%H%M")

### The codey bit below ###

## Functions ##

# Check APIs shared folders for differences.
checkDiff(){
  # Concatenate Differences.
  result=$result$(diff -rq "$1" "$2")
}

# Check both APIs and format result.
getResult(){
  checkDiff "$1" "$2"

  # Make result easier to read.
  result_formatted=$result
  result_formatted=${result_formatted//$bsas_location/$bsas_name:$'\n'}
  result_formatted=${result_formatted//$this_api_location/$this_api_name:$'\n'}
  result_formatted=${result_formatted// and/ &$'\n'}
  result_formatted=${result_formatted//Only in/$'\n'Only in }
  result_formatted=${result_formatted//Files/$'\n'}
}

# Check if the result has any data, if it does then there are differences.
checkResult(){
  # Check for differences in the 3 folders and get the result.
  getResult "$bsas_shared_app" "$this_api_shared_app"
  getResult "$bsas_shared_it" "$this_api_shared_it"
  getResult "$bsas_shared_test" "$this_api_shared_test"

  if [[ ${#result} -gt 0 ]]; then
    echo ">>> $(echo "$result" | wc -l)" "Differences Detected. Results stored in .Shared_Folder_Differences        <<<"

    # Write result to a text file so that the dev can review the differences.
    echo "$result_formatted" > "$this_api_location/.Shared_Folder_Differences"
  else
    echo ">>>        No Differences Found :)        <<<"
    exit 1
  fi
}

# Check we're in main branch and pull latest version.
updateAPI(){
  cd "$1" || exit
  git checkout main
  git pull
}

# Ask yes or no question. The script will exit if a word not beginning with y or Y is entered.
yesOrQuit(){
  read -rp "$1" confirm && [[ $confirm =~ ^[Yy] ]] || exit 1
}

# Check that both the /app and /shared folder exist below the current working directory.
# If they don't exist then either this API doesn't have the shared folders or the
# script is being run from a different directory.
checkShared(){
  cd app
  if [ "${PWD##*/}" == "app" ]; then
    cd shared
    if [ "${PWD##*/}" != "shared" ]; then
      echo "This script is not running from correct folder. Run from the app/shared folder."
      exit 1
    fi
  else
    echo "This script is not running from correct folder. Run from the app/shared folder."
    exit 1
  fi
  cd ../../ || exit
}

## Now to do all the things ##

# Check this script is running from correct app/shared folder.
checkShared

# Pull latest versions of APIs.
updateAPI "$bsas_location"
updateAPI "$this_api_location"

# Check and display the result for differences.
checkResult

# Get confirmation to update automatically.
yesOrQuit "Would you like to auto update? (Y/N): "

# Double check we're back in correct folder.
cd "$this_api_location" || exit

# Create new branch.
git checkout -b "UPDATE-SHARED-$time_now"

# Delete this APIs shared folders.
rm -rf "$this_api_shared_app" "$this_api_shared_it" "$this_api_shared_test"

# Copy bsas shared folders to this API.
cp -r "$bsas_shared_app" "$this_api_shared_app"
cp -r "$bsas_shared_it" "$this_api_shared_it"
cp -r "$bsas_shared_test" "$this_api_shared_test"

# Show git status so dev can confirm modified/added/deleted files.
git status

# Ask if they want to run tests with the new shared folders.
yesOrQuit "Would you like to run tests? (Y/N): "

sbt clean coverage test it:test coverageReport

# Check if they now want to commit and push the changes.
yesOrQuit "Would you like to commit changes and push? (Y/N): "

# Commit and push changes so now all the dev needs to do is create the PR.
git add .
git commit -m "Update Shared Folders $time_now"
git push --set-upstream origin "UPDATE-SHARED-$time_now"

# Delete the file now it's not needed.
rm .Shared_Folder_Differences
