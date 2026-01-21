aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 539247469933.dkr.ecr.us-east-1.amazonaws.com

brew install --cask docker

docker pull nginx:latest
docker tag nginx:latest 539247469933.dkr.ecr.us-east-1.amazonaws.com/testing/nginx:latest
docker push 539247469933.dkr.ecr.us-east-1.amazonaws.com/testing/nginx:latest
