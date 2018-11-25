#!/bin/bash

while getopts v:d:f: option
do
case "${option}"
in
v) VAULT=${OPTARG};;
d) DESCRIPTION=${OPTARG};;
f) FILE=${OPTARG};;
esac
done

# Create a temporary directory 
OUT="$(mktemp -d)"

# bytesize has to be a power of 2 (max 4 GB) - this is 2^28 (~270MB)
byteSize=268435456

cp $FILE $OUT
cd $OUT
split --bytes=$byteSize --verbose $FILE part

# Requires: 
# jq
# parallel
# awscli
# also assumes account is configured via $(aws config)

# count the number of files that begin with "part"
fileCount=$(ls -1 | grep "^part" | wc -l)
echo "Total parts to upload: " $fileCount

# get the list of part files to upload.  Edit this if you chose a different prefix in the split command
files=$(ls | grep "^part")

# initiate multipart upload connection to glacier
init=$(aws glacier initiate-multipart-upload --account-id - --part-size $byteSize --vault-name $VAULT --archive-description "$DESCRIPTION")

echo "---------------------------------------"
# xargs trims off the quotes
# jq pulls out the json element titled uploadId
uploadId=$(echo $init | jq '.uploadId' | xargs)

# create temp file to store commands
touch commands.txt

# create upload commands to be run in parallel and store in commands.txt
i=0
for f in $files 
  do
     byteStart=$((i*byteSize))
     byteEnd=$((i*byteSize+byteSize-1))
     echo aws glacier upload-multipart-part --body $f --range "'"'bytes '"$byteStart"'-'"$byteEnd"'/*'"'" --account-id - --vault-name $VAULT --upload-id $uploadId >> commands.txt
     i=$(($i+1))
     
  done

# run upload commands in parallel
#   --load 100% option only gives new jobs out if the core is than 100% active
#   -a commands.txt runs every line of that file in parallel, in potentially random order
#   --notice supresses citation output to the console
#   --bar provides a command line progress bar
parallel --gnu --load 100% -a commands.txt --no-notice --bar

echo "List Active Multipart Uploads:"
echo "Verify that a connection is open:"
aws glacier list-multipart-uploads --account-id - --vault-name $VAULT

# end the multipart upload
aws glacier abort-multipart-upload --account-id - --vault-name $VAULT --upload-id $uploadId

# list open multipart connections
echo "------------------------------"
echo "List Active Multipart Uploads:"
echo "Verify that the connection is closed:"
aws glacier list-multipart-uploads --account-id - --vault-name $VAULT

#echo "-------------"
#echo "Contents of commands.txt"
#cat commands.txt
echo "--------------"
echo "Deleting temporary commands.txt file"
rm commands.txt




