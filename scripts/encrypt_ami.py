#!/usr/bin/env python3

import boto3
import sys


def create_encrypted_ami_copy(ami_id, region='us-east-1', description='Encrypted copy of AMI'):
    """
    Create an encrypted copy of an AMI, copy its tags, add a new tag, and print the new AMI ID.

    :param ami_id: The ID of the source AMI.
    :param optional region: The region where the AMI is located. Default is 'us-east-1'.
    :param optional description: A description for the new AMI.
    """
    # Create an EC2 resource session
    ec2 = boto3.client('ec2', region_name=region)


    # Retrieve tags from the original AMI
    original_ami = ec2.describe_images(ImageIds=[ami_id])['Images'][0]
    original_tags = original_ami.get('Tags', [])

    # Add the new tag to the list of tags
    new_tag = {'Key': 'Encrypted From', 'Value': ami_id}
    original_tags.append(new_tag)

    # Copy the AMI and specify that the copy should be encrypted
    response = ec2.copy_image(
        SourceRegion=region,
        SourceImageId=ami_id,
        Name='Encrypted copy of ' + ami_id,
        Description=description,
        Encrypted=True
    )

    new_ami_id = response['ImageId']
    print("New Encrypted AMI ID:", new_ami_id)

    # Assign tags to the new AMI
    ec2.create_tags(Resources=[new_ami_id], Tags=original_tags)

    return new_ami_id


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <AMI_ID>")
        sys.exit(1)

    ami_id = sys.argv[1]

    new_ami_id = create_encrypted_ami_copy(ami_id)
    print("New Encrypted AMI ID:", new_ami_id)
