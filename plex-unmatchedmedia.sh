#!/bin/bash

flag=$*

[[ $flag == "-s" ]] && silent=1

if [[ $silent != 1 ]]
then
  echo -e "\n**** Plex Metadata Checking Script ****"
  echo -e "\nThis script will check the Plex DB for the following issues:"
  echo "1. Video files not found in Plex"
  echo "2. Plex conent missing a file"
  echo "3. Missing Plex metadata - movies or shows without a proper title."
  echo "Requirements: sqlite3"
  echo -e "\nRun this with a '-s' to use in a script. Only found issues will be displayed."
  echo -e "\nVersion: 1.1"
  echo -e "***************************************"
fi

# Plex DB path
plexdbpath="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

#check if sqlite3 installed
if ! type sqlite3 &> /dev/null
then
  echo -e "\nsqlite3 is not installed"
  exit 1
fi

# Test if DB file is accessible
if [[ ! -r "$plexdbpath" ]]
then
  # attempt to find db file
  [[ $silent != 1 ]] && echo -e "\nDefault database path invalid, finding Plex database file"
  plexdbpath=`find / -name "com.plexapp.plugins.library.db" -type f  -printf '%T+ %p\n'  2>/dev/null | grep -v "find:" | sort -r | head -1 | cut -d' ' -f2-`
  if [[ ! -r "$plexdbpath" ]]
  then
    echo -e "\ncom.plexapp.plugins.library.db is not found or accessible"
    exit 1
  else 
    echo -e "\nUsing $plexdbpath"
  fi
fi

# Test if DB can access tables
plextables=`sqlite3 "$plexdbpath" ".tables"`
if [[ $plextables != *"metadata_items"* ]] 
then
  echo -e "\nThe needed tables were not found. $plexdbpath may not be the right database"
  exit 1
fi 

# Query for missing metadata

missingmetadataquery="SELECT C.file FROM metadata_items A LEFT JOIN media_items B ON A.id = B.metadata_item_id LEFT JOIN media_parts C ON B.id = C.media_item_id WHERE (A.media_item_count = 1 AND (A.title_sort = '' OR A.title = '')) OR (A.guid LIKE 'local%' AND A.metadata_type = 1 AND A.title = '');"

# Query for finding all file paths
filepathsquery="SELECT A.root_path FROM section_locations A LEFT JOIN library_sections B ON A.library_section_id = B.id WHERE (B.section_type = 1 OR B.section_type = 2);"

# Query for all files in Plex
plexfilequery="SELECT file FROM media_parts WHERE directory_id != '';"


## Find all data not in Plex
# Find file paths
filepaths=`sqlite3 "$plexdbpath" "$filepathsquery"`

# Find all files in plex
plexfiles=`sqlite3 "$plexdbpath" "$plexfilequery"`

[[ $silent != 1 ]] && echo -e "\nChecking files - finding all video content"

# Disable whitespace as line break for file paths
IFS=$'\n'
for filepath in $filepaths
do
  [[ $silent != 1 ]] && echo "Checking '$filepath'"

  # find all video files bigger than 2 MB
  listoffiles=`find $filepath -type f -size +2M -exec file -N -i -- {} + | sed -n 's!: video/[^:]*$!!p'`

  # check each file if it is listed in Plex
  for file in $listoffiles
  do
    # check if file is not Plex list
    if [[ $plexfiles != *"$file"* ]]
    then
      # find directory of file
      filedir=$(dirname "${file}")
      
      # check if ignore file exists if missing, then file is missing
      if [[ ! -f "$filedir/.plexignore" ]]
      then 
        echo "'$file' is missing from Plex"
      else
       [[ $silent != 1 ]] && echo  "$file has plexignore file"
      fi
    fi
  done
done

# Check for files in Plex missing on drives
[[ $silent != 1 ]] && echo -e "\nChecking for Plex content that is missing a file"

for plexfile in $plexfiles
do
  [[ ! -f "$plexfile" ]] && echo "$plexfile is missing"
done

# Enable whitespace as line break
unset IFS

# Find unmatched content

# Check for files in Plex missing on drives
[[ $silent != 1 ]] && echo -e "\nChecking for Plex content that is missing metadata"

unmatched=`sqlite3 "$plexdbpath" "$missingmetadataquery"`
[[ ! -z "$unmatched" ]] && echo -e "\nContent which is unmatched or missing metadata in Plex\n$unmatched"

exit 0
