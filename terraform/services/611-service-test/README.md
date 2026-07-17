# ECR Terraservice

This service is established for testing a cohesive provisioning and deployment of an ECR stored image and ECS hosted service. 
Each image category gets its own repository to support fully immutable tags. 
Currently, CDAP images are used only in the non-prod context.

The use of config does not have to be a list of services, as this terraservice pattern could be used to configure a single service at a time. 
