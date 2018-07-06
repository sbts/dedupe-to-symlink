#!/bin/bash
#
# Workaround for duplicate files in PhotoTranscoder.
# Symlinks each duplicate file to the oldest (original) file
#
# https://www.reddit.com/r/PleX/comments/8vuhan/think_ive_found_a_cache_bug_large_cache_directory
# https://forums.plex.tv/t/plex-server-cache-over-310gb/274438/10
#

phototranscoder_path=$1

last_hash=""
last_file=""
cur_hash=""
cur_file=""
cur_timestamp=""
first_hash=""
first_file=""
first_file_owner=""
first_file_group=""


if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root!" 
   exit 1
fi


if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "$@ /path/to/PhotoTranscoder"
    exit 1
fi


if [ ! -d $phototranscoder_path ]
then
    echo "PhotoTranscoder path does not exist! - ${phototranscoder_path}"
    exit 1
fi


echo "Please ensure Plex is stopped and you have a backup before continuing."
echo "This process can take hours to complete."
echo ""
echo "Press ENTER when ready."
read


echo "Generating list of files (part 1)..."
tmpfilelistp1=$(mktemp)
find "${phototranscoder_path}" -type f -printf "%C@\t" -exec md5sum "{}" \; > $tmpfilelistp1


echo "Generating list of files (part 2)..."
tmpfilelistp2=$(mktemp)
cat $tmpfilelistp1 | awk ' { print $2"\t"$1"\t"$3 } ' > $tmpfilelistp2


echo "Generating list of files (part 3)..."
tmpfilelistp3=$(mktemp)
cat $tmpfilelistp2 | sort > $tmpfilelistp3


echo "Symlinking duplicates to originals..."
OLDIFS="$IFS"
IFS=$'\n'
while read line
do
    cur_hash=$(echo "${line}" | awk ' { print $1 } ')
    cur_file=$(echo "${line}" | awk ' { print $3 } ')

    if [ "${cur_hash}" = "${last_hash}" ]
    then
    	echo "===== DUPE : ${cur_hash} - ${cur_file}"
        rm "${cur_file}"
        ln -s "${first_file}" "${cur_file}"
        chown ${first_file_owner}:${first_file_group} "${cur_file}"
    else
        if [ "${cur_hash}" != "${first_hash}" ]
        then
            first_hash=$cur_hash
            first_file=$cur_file
            first_file_owner=$(stat -c "%U" "${first_file}")
            first_file_group=$(stat -c "%G" "${first_file}")

            echo "===== ORIG : ${first_hash} - ${first_file}"
        fi
    fi

    last_hash=$cur_hash
    last_file=$cur_file
done < $tmpfilelistp3