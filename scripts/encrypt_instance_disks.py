#!/usr/bin/env python3

import boto3
import time
import sys
import pprint3x as pp

ec2 = boto3.client("ec2", region_name="us-east-1")
start_time = time.time()

if len(sys.argv) > 1:
    instance_name = sys.argv[1]
    print(f"Working on instance named: '{instance_name}' ...")
else:
    raise ValueError("This script expects instance name as parameter")


def get_instance_id_by_name(instance_name):
    if instance_name:
        response = ec2.describe_instances(
            Filters=[{"Name": "tag:Name", "Values": [instance_name]}]
        )
        print(response)
        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                return instance["InstanceId"]
    else:
        raise ValueError("Missing instancce name when calling describe_instances()")
    return None


def shutdown_instance(instance_id):
    ec2.stop_instances(InstanceIds=[instance_id])
    print(f"Shutting down instance {instance_id} ...")

    waiter = ec2.get_waiter("instance_stopped")
    waiter.wait(InstanceIds=[instance_id])
    print(f"Instance {instance_id} is now stopped.")


def encrypt_volume(instance_id, volume):
    snapshot_data = []
    snapshot = ec2.create_snapshot(VolumeId=volume["VolumeId"])
    snapshot_id = snapshot["SnapshotId"]

    print(f"Creating snapshot {snapshot_id} from volume {volume['VolumeId']} ...")

    waiter = ec2.get_waiter("snapshot_completed")
    waiter.wait(SnapshotIds=[snapshot_id])

    encrypted_snapshot = ec2.copy_snapshot(SourceSnapshotId=snapshot_id, Encrypted=True, SourceRegion='us-east-1', DestinationRegion='us-east-1')
    encrypted_snapshot_id = encrypted_snapshot["SnapshotId"]

    print(f"Creating encrypted snapshot {encrypted_snapshot_id} from unencrypted {snapshot_id} ...")

    waiter.wait(SnapshotIds=[encrypted_snapshot_id])

    encrypted_volume = ec2.create_volume(
        SnapshotId=encrypted_snapshot_id,
        AvailabilityZone=volume["AvailabilityZone"],
        VolumeType='gp3',
        TagSpecifications=[
            {
                'ResourceType': 'volume',
                'Tags': [
                    {
                        'Key': 'ParentSnap',
                        'Value': encrypted_snapshot_id
                    },
                    {
                        'Key': 'InstanceName',
                        'Value': instance_name
                    },
                    {
                        'Key': 'InstanceId',
                        'Value': instance_id
                    }
                ]
            },
        ]
    )
    encrypted_volume_id = encrypted_volume["VolumeId"]

    print(f"Creating encrypted volume {encrypted_volume_id} ...")

    volume_waiter = ec2.get_waiter("volume_available")
    volume_waiter.wait(VolumeIds=[encrypted_volume_id])

    snapshot_data.append(
        {
            "snapshot_id":  snapshot,
            "encrypted_snapshot_id": encrypted_snapshot,
            "encrypted_volume_id": encrypted_volume,
        }
    )
    return snapshot_data


def process_volumes(instance_id):
    response = ec2.describe_volumes(
        Filters=[{"Name": "attachment.instance-id", "Values": [instance_id]}]
    )

    volume_mappings = []
    for volume in response["Volumes"]:
        device_name = volume["Attachments"][0]["Device"]
        encryption_data = encrypt_volume(instance_id, volume)
        volume_mappings.append([
            {
                "original_volume": volume["VolumeId"],
                "device_name": device_name,
            },
            {
                "encryption_data": encryption_data
            }]
        )
    return volume_mappings


def reattach_volumes(instance_id, volume_mappings):
    for mapping in volume_mappings:
        ec2.detach_volume(VolumeId=mapping["original_volume"])
        print(f"Detaching volume {mapping['original_volume']}...")

        waiter = ec2.get_waiter("volume_detached")
        waiter.wait(VolumeIds=[mapping["original_volume"]])

        ec2.attach_volume(
            VolumeId=mapping["encrypted_volume"],
            InstanceId=instance_id,
            Device=mapping["device_name"],
        )
        print(
            f"Attaching encrypted volume {mapping['encrypted_volume']} to {mapping['device_name']} ..."
        )


def start_instance(instance_id):
    ec2.start_instances(InstanceIds=[instance_id])
    print(f"Starting instance {instance_id} ...")


def main():
    volume_mappings = {}
    instance_id = get_instance_id_by_name(instance_name)
    if instance_id:
        # shutdown_instance(instance_id)
        volume_mappings = process_volumes(instance_id)
        # reattach_volumes(instance_id, volume_mappings)
        # start_instance(instance_id)
        print(
            f"Done. The instance {instance_name} is now running with encrypted volume(s)."
        )
    else:
        print("Instance not found.")

    end_time = time.time()
    execution_time = end_time - start_time
    if len(volume_mappings) > 0:
        print("Volume mappings: ")
        pp.pprint(volume_mappings)
    else:
        print("No volume mappings found")
    print(f"Script executed in {execution_time:.3f} seconds.")


if __name__ == "__main__":
    main()
