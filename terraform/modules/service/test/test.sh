#Verify Service Connect Configuration 
aws ecs describe-services --cluster jjr-microservices-cluster --services frontend-service backend-service

#Test Connectivity Using ECS Exec

#Enable ECS Exec on both services
aws ecs update-service --cluster jjr-microservices-cluster --service frontend-service --enable-execute-command --force-new-deployment
aws ecs update-service --cluster jjr-microservices-cluster --service backend-service --enable-execute-command --force-new-deployment

#Install session-manager plugin
brew install session-manager-plugin

#Open a shell
aws ecs execute-command --cluster plt-1448-microservices-cluster --task arn:aws:ecs:us-east-1:539247469933:cluster/plt-1448-microservices-cluster --container backend --interactive --command "/bin/bash"

#Run a command
curl http://backend-service.backend:80/health

#Check for envoy in the header
curl -I http://backend-service.backend:80/health

#Monitor Logs and Metrics

#- **View Logs**: Check container and application logs in Amazon CloudWatch Logs for connectivity or runtime errors.
#- **Review Metrics**: Use the CloudWatch console to monitor Service Connect metrics like`RequestCount` and `NewConnectionCount`under the`ECS`namespace.
#These metrics provide detailed telemetry and can be used for setting alarms and configuring auto scaling.
# Get a shell in one of your Service Connect-enabled containers
aws ecs execute-command --cluster your-cluster \
  --task your-task-id \
  --container your-container \
  --interactive --command "/bin/sh"

# Test DNS resolution of your service
nslookup backend-service
dig backend-service

# Test actual connectivity
wget -O- http://backend-service:8080
