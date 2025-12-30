# Terraform module for bucket resources 

This module generates an S3 bucket with core configuration.   

We enforce the use of lifecycle management, versioning, encryption, and SSL requests. 

## Managing access to buckets 

This module manages two types of access policies: 
1. A bucket access policy. Here, we enforce SSL and can enable cross-account bucket access, which is used sparingly and was leveraged for historical migrations. 
2. IAM access policies. These policies can be attached to resources in other modules. Maintaining IAM policies here enables central oversight of common access patterns and distributed enablement of access based on those patterns. Please see the variables to choose which policies are needed. Additional policies may be generated as necessary.

## Bucket Access Logging 
Access and access attempts to generated buckets is logged in pre-configured buckets that are not managed in this Terraform.

