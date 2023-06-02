#!/usr/bin/env python3

import boto3

def list_unencrypted_s3_buckets():
    s3 = boto3.client('s3')
    print ("Checking for unencrypted S3 buckets...")

    # List all S3 buckets
    response = s3.list_buckets()
    for bucket in response['Buckets']:
        bucket_name = bucket['Name']

        try:
            # Get the bucket policy status
            encryption = s3.get_bucket_encryption(Bucket=bucket_name)
        except:
            # If there's an exception, the bucket might not be encrypted
            print(f"S3 Bucket {bucket_name} is not encrypted.")

def list_unencrypted_ec2_volumes():
    ec2 = boto3.client('ec2')
    print ("Checking for unencrypted ec2 volumes...")

    # Describe all volumes
    response = ec2.describe_volumes()

    for volume in response['Volumes']:
        volume_id = volume['VolumeId']

        # If volume is not encrypted
        if not volume.get('KmsKeyId'):
            # check if volume is attached to an instance
            if volume['Attachments']:
                instance_id = volume['Attachments'][0]['InstanceId']
                instance_response = ec2.describe_instances(InstanceIds=[instance_id])
                instance_name = ''
                for tag in instance_response['Reservations'][0]['Instances'][0]['Tags']:
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
                print(f"Unencrypted EC2 Volume {volume_id} is attached to Instance {instance_id} with Name '{instance_name}'")


def list_unencrypted_rds_instances():
    rds = boto3.client('rds')
    print ("Checking for unencrypted RDS instances...")

    # Describe all RDS instances
    response = rds.describe_db_instances()

    for instance in response['DBInstances']:
        instance_id = instance['DBInstanceIdentifier']

        # If instance storage is not encrypted
        if not instance['StorageEncrypted']:
            print(f"RDS Instance {instance_id} is not encrypted.")


if __name__ == '__main__':
    list_unencrypted_s3_buckets()
    list_unencrypted_ec2_volumes()
    list_unencrypted_rds_instances()
