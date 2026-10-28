# TFTesting Service App 
This application is designed to serve as primary test logic for infrastructure provided by CDAP. Any changes to this application will affect multiple terraservices, and, as such, this application will be mainted to verify: 

## For standalone service use 
The service can access datadog. 
The service can come up "healthy". 

## For multi service use 
An upstream service can connect a downstream service.

## Synthetic/e2e test validation 
A data object is returned.
The service can come up "healthy" behind a load balancer. 

## Possibility for extension 
This application can be modified to ensure various types of connectivity are possible. For example, this application can be extended and then provisioned alongside a database to ensure database connectivity using database IAM permissions. 
