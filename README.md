# Auto Deploy Python projects
Script to python projects on ubuntu servers

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

# Note
This script overwrites existin nginx config and you need to handle static files manually if you need to