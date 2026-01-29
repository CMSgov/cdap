#Verify Service Connect Configuration 
aws ecs describe-services --cluster jjr-microservices-cluster --services frontend-service backend-service

#Test Connectivity Using ECS Exec

#Enable ECS Exec on both services
aws ecs update-service --cluster jjr-microservices-cluster --service frontend-service --enable-execute-command --force-new-deployment
aws ecs update-service --cluster jjr-microservices-cluster --service backend-service --enable-execute-command --force-new-deployment

#Install session-manager plugin
brew install session-manager-plugin

#Open a shell
aws ecs execute-command --cluster jjr-microservices-cluster --task arn:aws:ecs:us-east-1:539247469933:task/jjr-microservices-cluster/4057d00dc8504d34aeb029dbf0b66331 --container backend --interactive --command "/bin/bash"




