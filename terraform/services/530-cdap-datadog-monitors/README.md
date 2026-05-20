# Configuration hierarchy 
Configuration is inherited from config/ and the hierarchy that is honored is: 
defaults.yml < shared.${env}.yml < ${app}.yml < ${app}.${env}.yml
