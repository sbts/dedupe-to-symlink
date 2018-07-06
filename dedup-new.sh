#!/bin/bash
#
# Workaround for duplicate files in PhotoTranscoder.
# Symlinks each duplicate file to the oldest (original) file
#
# https://www.reddit.com/r/PleX/comments/8vuhan/think_ive_found_a_cache_bug_large_cache_directory
# https://forums.plex.tv/t/plex-server-cache-over-310gb/274438/10
#

read -rst5 phototranscoder_path < <( readlink -f "$1"; )

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
#   exit 1
fi


if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  ${0##*/} /path/to/PhotoTranscoder"
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
#read


echo "Generating list of files (part 1)..."
tmpfilelistp1=$(mktemp)
#find "${phototranscoder_path}" -type f -printf "%C@\t" -exec md5sum "{}" \; > $tmpfilelistp1
while read -rst240 Ts Sum Name ; do
    printf '%s %s %s\n' "$Sum" "$Ts" "$Name" >> $tmpfilelistp1
done < <( find "${phototranscoder_path}" -type f -printf "%C@\t" -exec md5sum "{}" \; )


#echo "Generating list of files (part 2)..."
#tmpfilelistp2=$(mktemp)
#cat $tmpfilelistp1 | awk ' { print $2"\t"$1"\t"$3 } ' > $tmpfilelistp2


echo "Generating list of files (part 3)..."
tmpfilelistp3=$(mktemp)
cat $tmpfilelistp1 | sort > $tmpfilelistp3
#sort -o $tmpfilelistp3 $tmpfilelistp2


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


cat <<-EOF
	tmpfilelistp1 = $tmpfilelistp1
	tmpfilelistp2 = $tmpfilelistp2
	tmpfilelistp3 = $tmpfilelistp3
	EOF

head -n5 $tmpfilelistp1
#head -n5 $tmpfilelistp2
head -n5 $tmpfilelistp3

