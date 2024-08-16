#!/bin/bash

# This script should be run from within the APIs base folder
# that you wish to match with bsas
#
# The script assumes all API repos are within the same working directory


# Configurable variables if not standard. working_folder could be
# set to something like "/Users/username/worksapce/" for example
working_folder="../"
this_api_name=${PWD##*/}
bsas_name="self-assessment-bsas-api"

# Create location variables
bsas_location="$working_folder$bsas_name"
this_api_location="$working_folder$this_api_name"

# Get current date and time format: YYYYMMDD-HHMM
time_now=$(date +"%Y%m%d-%H%M")

# Create the shared folder variables
bsas_shared_app="$bsas_location/app/shared"
bsas_shared_it="$bsas_location/it/shared"
bsas_shared_test="$bsas_location/test/shared"

this_api_shared_app="$this_api_location/app/shared"
this_api_shared_it="$this_api_location/it/shared"
this_api_shared_test="$this_api_location/test/shared"

### The codey bit below ###

## Functions ##

# Check APIs shared folders for differences
checkDiff(){
  # Concatenate Differences
  result=$result$(diff -rq "$1" "$2")
}

# Check both APIs and format result
getResult(){
  checkDiff "$1" "$2"

  # Make result easier to read
  result_formatted=$result
  result_formatted=${result_formatted//$bsas_location/$bsas_name:$'\n'}
  result_formatted=${result_formatted//$this_api_location/$this_api_name:$'\n'}
  result_formatted=${result_formatted// and/ &$'\n'}
  result_formatted=${result_formatted//Only in/$'\n'Only in }
  result_formatted=${result_formatted//Files/$'\n'}
}

# Check if the result has any data, if it does then there are differences
checkResult(){
  # Check for differences in the 3 folders and get the result
  getResult "$bsas_shared_app" "$this_api_shared_app"
  getResult "$bsas_shared_it" "$this_api_shared_it"
  getResult "$bsas_shared_test" "$this_api_shared_test"

  if [[ ${#result} -gt 0 ]]; then
    echo ">>> $(echo "$result" | wc -l)" "Differences Detected. Results stored in .Shared_Folder_Differences        <<<"

    # Write result to a text file so that the dev can review the differences
    echo "$result_formatted" > "$this_api_location/.Shared_Folder_Differences"
  else
    echo ">>>        No Differences Found :)        <<<"
    exit 1
  fi
}

## Now to do all the things ##

# Pull latest version of bsas API
cd "$bsas_location" || exit
git checkout main
git pull

# Pull latest version of this API
cd "$this_api_location" || exit
git checkout main
git pull

# Check and display the result for differences
checkResult

# Get confirmation to update automatically
read -rp "Would you like to auto update? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Double check we're back in correct folder
cd "$this_api_location" || exit

# Create new branch
git checkout -b "UPDATE-SHARED-$time_now"

# Delete this APIs shared folders
rm -rf "$this_api_shared_app" "$this_api_shared_it" "$this_api_shared_test"

# Copy bsas shared folders to this API
cp -r "$bsas_shared_app" "$this_api_shared_app"
cp -r "$bsas_shared_it" "$this_api_shared_it"
cp -r "$bsas_shared_test" "$this_api_shared_test"

# Show git status so dev can confirm modified/added/deleted files
git status

# Ask if they want to run tests with the new shared folders
read -rp "Would you like to run tests? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

sbt clean coverage test it:test coverageReport

# Check if they now want to commit and push the changes
read -rp "Would you like to commit changes and push? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

# Commit and push changes so now all the dev needs to do is create the PR
git add .
git commit -m "Update Shared Folders $time_now"
git push --set-upstream origin "UPDATE-SHARED-$time_now"

# Delete the file now it's not needed
rm .Shared_Folder_Differences
