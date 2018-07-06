#!/bin/bash

fileQty=100;            # The number of files to generate
fileSizeMin=100;        # The minimum size of each file in bytes. it will vary by a few bytes, but not too many
fileDuplicates=10;      # The number of duplicates to create for each file

targetDir="$PWD/data"
RandomData="";
fileName="";

Args="$*";

cat <<-EOF
	====================================================
	== Generating test files containing random data
	==     - $fileNumber unique files of $fileSize
	==     - $fileDuplicates duplicates per unique file
	====================================================
	EOF

GenerateRandomData() {
    Random="";
    while (( ${#Random} < fileSizeMin )); do
        Random+=$RANDOM;
    done
}

GenerateFileName() {
    fileName="";
    read -rst5 fileName < <( tempfile --directory "$targetDir" )
}

GenerateFiles() {
    pushd "$targetDir";
    while (( fileQty-- >0 )); do
        GenerateRandomData;
        echo -e "=============\n== $Random\n============="
        (( Dups = fileDuplicates ));
        while (( Dups-- >0 )); do
            GenerateFileName;
            printf 'Remaining Files: %4s\t Dup: %4s\t Name: %s\n' "$fileQty" "$Dups" "$fileName"
            printf '%s\n' "$Random" > "$fileName";
        done
    done
    popd;
}

DeleteFiles() {
    cat <<-EOF
	==========================
	== Delete all files in
	== $targetDir
	==========================
	EOF
    [[ -d "$targetDir" ]] || return; # if the data dir doesn't exist there is no point trying to delete it
    if ! [[ $Args =~ '--auto' ]]; then
        read -n1 -p 'Delete existing test files? [y/n]: ' K;
    else
        K='Y';
    fi
    if [[ yY =~ "${K:0:1}" ]]; then
        pushd "$targetDir";
            rm -rf "$targetDir";
        popd;
        echo $'\n\nDeleted old files\n';
    else
        echo $'\n\nSkipped deletion\n';
    fi
}

DeleteFiles;

mkdir -p "$targetDir";
GenerateFiles;

