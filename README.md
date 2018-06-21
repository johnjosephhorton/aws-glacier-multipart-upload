# aws-glacier-multipart-upload
Script for uploading large files to AWS Glacier

The script ice.sh builds off the original code to automate the file splitting.
You call it like this (assuming ice.sh is in your PATH)
```
ice.sh -v backups -d <description> -f <file> 
```

Helpful AWS Glacier pages:
 - <a href="http://docs.aws.amazon.com/cli/latest/userguide/cli-using-glacier.html#cli-using-glacier-initiate">Using Amazon Glacier with the AWS Command Line Interface</a>
 - <a href="http://docs.aws.amazon.com/cli/latest/reference/glacier/index.html#cli-aws-glacier">AWS Glacier Command Reference</a>

**Motivation**

The one-liner <a href="http://docs.aws.amazon.com/cli/latest/reference/glacier/upload-archive.html">upload-archive</a> isn't recommend for files over 100 MB, and you should instead use <a href="http://docs.aws.amazon.com/cli/latest/reference/glacier/upload-multipart-part.html">upload-multipart<a/>. The difficult part of using using multiupload is that it is really three major commands, with the second needing to repeated for every file to upload, and a custom byte range needs to be defined for each file chunk that is being uploaded.  For example, with a 4MB file (4194304 bytes) the first three files need the following argument.  This is repeated 1945 times for my 8GB file.
 - aws glacier upload-multipart-part --body partaa --range 'bytes 0-4194303/*' --account-id - --vault-name media1 --upload-id [your upload id here]
 - aws glacier upload-multipart-part --body partab --range 'bytes 4194304-8388607/*' --account-id - --vault-name media1 --upload-id [your upload id here]
 - aws glacier upload-multipart-part --body partac --range 'bytes 8388608-12582911/*' --account-id - --vault-name media1 --upload-id [your upload id here]
 - 1941 commands later...
 - aws glacier upload-multipart-part --body partzbxu --range 'bytes 8153726976-8157921279/*' --account-id - --vault-name media1 --upload-id [your upload id here]

We need a script to handle the math and autogenerate the code.  

This script leverages the <a href="https://www.gnu.org/software/parallel/parallel_tutorial.html">parallel</a> library, so my 1945 upload scripts are kicked off in parallel, but are queued up until a core is done with one before proceeding to the next.  There is even a progress bar built in that shows you what percent is complete, and an estimated wait time until it is done.

**Prerequisites**

All of the following items in the Prerequisites section only need to be done once to set things up. 

This script depends on <b>jq</b> for dealing with json and <b>parallel</b> for submitting the upload commands in parallel.  If you are using Fed/CentOS/RHEL, then run the following:

    sudo dnf install jq
    sudo dnf install parallel

It assumes you have an AWS account, and have signed up for the glacier service.  In this example, I have already created the vault named <i>media1</i> via AWS console.

It also assumes that you have the <a href="http://docs.aws.amazon.com/cli/latest/userguide/installing.html">AWS Command Line Interface</a> installed on your machine.  Again, if you are using Fed/CentOS/RHEL, then here is how you would get it:

    sudo pip install awscli

Configure your machine to pass credentials automatically.  This allows you pass a single dash with the account-id argument.

    aws configure

Before jumping into the script, verify that your connection works by describing the vault you have created, which is <i>media1</i> in my case. Run this describ-vault command and you should see similiar json results. 

    aws glacier describe-vault --vault-name media1 --account-id -
    {
    "SizeInBytes": 11360932143, 
    "VaultARN": "arn:aws:glacier:us-east-1:<redacted>:vaults/media1", 
    "LastInventoryDate": "2015-12-16T01:23:18.678Z", 
    "NumberOfArchives": 7, 
    "CreationDate": "2015-12-12T02:22:24.956Z", 
    "VaultName": "media1"
    }

Clone this repo
Make it `ice.sh` executable:

    chmod u+x ice.sh

**Script Usage**

Tar and zip the files you want to upload:

    tar -zcvf my-backup.tar.gz /location/to/zip/*

Now it is time to run the script.  

```
ice.sh -v backups -d <description> -f <file> 
```


