# deploy_fastapi
Script to deploy fastapi on ubutu servers

## Usage

* clone your repository into your server
* create your virtual environment
* run uvicorn and verify that your project is running
* run
```
$ ./deploy.sh
```

# Note - refuse the nginx configuration is you existing nginx config as this will remove all prior configurations

```
Do you want to set up NGINX (yes/no)? 
# Use the no option if you have existing configuration
```