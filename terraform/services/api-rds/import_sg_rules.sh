#!/bin/bash

# Define the rules (Security group rule IDs)
rules=(
  "sgr-086f403195b7b46ca"
  "sgr-026828254b6b4aa2a"
  "sgr-05b004ab95be3cb64"
  "sgr-0e4421a7ae214c90e"
)

# Loop through each rule and import it into Terraform state
for sgr_id in "${rules[@]}"; do
  # Construct the Terraform import command for each security group ID
  import_command="terraform import aws_vpc_security_group_ingress_rule.db_access_from_jenkins_agent[\"${sgr_id}\"] ${sgr_id}"
  
  # Print the command for debugging purposes
  echo "Running: $import_command"

  # Run the import command
  eval $import_command

  # Check if the import was successful
  if [ $? -eq 0 ]; then
    echo "Successfully imported rule $sgr_id"
  else
    echo "Failed to import rule $sgr_id"
  fi
done
