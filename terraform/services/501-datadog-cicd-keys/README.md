This service instantiates the necessary API keys and Application keys per application running Terraform or leveraging Datadog in Github Actions. 

When the creator of that administrator's Datadog account is terminated, an admin user must

0) decrypt the sops files per config instructions: `bin/sopsw -e values/prod.sopsw.yaml`
1) generate a new application key via:
https://app.ddog-gov.com/organization-settings/application-keys. 
2) write the application key in the sops file and save 
3) repeat these instructions but using `test.sopsw.yaml`

If SOPs cannot be leveraged, the administrator can write the value directly into the SSM parameter in each account at the path `/dasgapi/sensitive/datadog/init_application_key`.

The API key will not need to be regenerated for operations continue, though you may wish to rotate that key as well via `/dasgapi/sensitive/datadog/init_api_key`.