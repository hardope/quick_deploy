#!/bin/bash

# Function to update and install dependencies
update_install() {
    echo "Updating system and installing required packages..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get -y install python3-pip python3-venv git
}

# Function to check if directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        echo "Directory $1 does not exist. Exiting."
        exit 1
    fi
}

# Function to check if file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "File $1 does not exist. Exiting."
        exit 1
    fi
}

# Function to check if venv exists in the project directory
check_venv() {
    echo "Checking for existing virtual environment (venv)..."
    if [ -d "$1/venv" ]; then
        echo "Virtual environment found."
        export VENV_PATH="$1/venv"
    else
        echo "Virtual environment not found in the project directory."
        read -p "Enter the absolute path to your virtual environment directory: " venv_path
        export VENV_PATH="$venv_path"
    fi
}

# Function to configure NGINX with the provided server block configuration
configure_nginx() {
    read -p "Do you want to set up NGINX (yes/no)? " setup_nginx

    if [ "$setup_nginx" = "yes" ]; then
        echo "Configuring NGINX..."
        nginx_config="server {
            listen 80 default_server;
            listen [::]:80 default_server;

            server_name _;

            location / {
                    proxy_pass http://127.0.0.1:8000;
                    include proxy_params;
            }
        }"

        if ! grep -q "proxy_pass http://127.0.0.1:8000;" /etc/nginx/sites-available/default; then
            sudo sed -i -e '/^\s*}/i '"$nginx_config"'' /etc/nginx/sites-available/default
            sudo systemctl restart nginx
        else
            echo "NGINX proxy configuration already exists. Skipping..."
        fi
    else
        echo "Skipping NGINX setup as per user choice."
    fi
}

# Function to create and start the systemd service
create_service() {
    echo "Creating and starting systemd service..."

    read -p "Enter project directory (absolute path): " project_directory

    check_directory "$project_directory"
    check_file "$project_directory/requirements.txt"

    check_venv "$project_directory"

    read -p "Enter project name: " project_name
    read -p "Enter the name of your main FastAPI app (e.g., 'app'): " fastapi_app_name

    # Check if the service file already exists
    service_file="/etc/systemd/system/$project_name.service"
    if [ -f "$service_file" ]; then
        echo "Service file already exists. Skipping service creation."
    else
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Gunicorn instance to serve $project_name
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$project_directory
Environment="PATH=$VENV_PATH/bin"
ExecStart=$VENV_PATH/bin/gunicorn $fastapi_app_name:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl start "$project_name"
        sudo systemctl enable "$project_name"
    fi
}

# Main script execution
update_install
configure_nginx
create_service

echo "Deployment completed!"
