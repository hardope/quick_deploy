# deploy_fastapi
Script to deploy fastapi on ubutu servers

## Usage

* clone your repository into your server
* Ensure you have a requirements.txt file to avoid errors or create your virtual environment `venv` in the project folder
* Verify if your project is running manually if you ceated your virtual environment
* run script
```
# grant executable permission
$ chmod +x deploy

# run script
$ ./deploy.sh
```

# Note - refuse the nginx configuration is you existing nginx config as this will remove all prior configurations

This script overwrites existin nginx config and you need to handle static files manually if you need to