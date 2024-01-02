#!/bin/bash

update_install() {
    echo "Updating system and installing required packages..."
    sudo apt-get update
    sudo apt-get -y install python3-pip python3-venv nginx
    echo "System updated and required packages installed."
}

check_directory() {
    if [ ! -d "$1" ]; then
        echo "Directory $1 does not exist. Exiting."
        exit 1
    fi
}

check_file() {
    if [ ! -f "$1" ]; then
        return 1
    else
        return 0
    fi
}

check_venv() {
    echo "Checking for an existing virtual environment (venv) in the project directory..."
    if [ -d "$1/venv" ]; then
        read -p "A virtual environment is found in the project directory. Do you want to use it? (yes/no) " use_venv
        if [ "$use_venv" = "yes" ]; then
            echo "Using the existing virtual environment in the project directory."
            export VENV_PATH="$1/venv"
            source "$VENV_PATH/bin/activate" && python3 -m pip install -r "$1/requirements.txt" gunicorn uvicorn fastapi >/dev/null
            deactivate
        else
            read -p "Proceeding without using the existing virtual environment. Do you have a virtual environment located elsewhere? (yes/no) " venv_elsewhere
            if [ "$venv_elsewhere" = "yes" ]; then
                while true; do
                    read -p "Enter the absolute path to your virtual environment directory: " venv_path
                    if [ -d "$venv_path" ]; then
                        echo "Virtual environment found at $venv_path."
                        export VENV_PATH="$venv_path"
                        source "$VENV_PATH/bin/activate" && python3 -m pip install gunicorn uvicorn fastapi >/dev/null
                        deactivate
                        break
                    else
                        echo "Directory not found. Please enter a valid path."
                    fi
                done
            else
                if check_file "$1/requirements.txt"; then
                    echo "Setting up a new virtual environment and installing required packages from requirements.txt..."
                    python3 -m venv "$1/venv" >/dev/null
                    source "$1/venv/bin/activate" && python3 -m pip install -r "$1/requirements.txt" gunicorn uvicorn fastapi >/dev/null
                    deactivate
                    export VENV_PATH="$1/venv"
                else
                    echo "No virtual environment or requirements.txt found. Installing FastAPI, Gunicorn, and Uvicorn in a new virtual environment..."
                    python3 -m venv "$1/venv" >/dev/null
                    source "$1/venv/bin/activate" && python3 -m pip install gunicorn uvicorn fastapi >/dev/null
                    deactivate
                    export VENV_PATH="$1/venv"
                    echo "FastAPI, Gunicorn, and Uvicorn installed in the newly created virtual environment. Please note the implications of not having a requirements.txt file for dependency management."
                fi
            fi
        fi
    else
        read -p "No virtual environment found. Do you have a virtual environment located elsewhere? (yes/no) " venv_elsewhere

        if [ "$venv_elsewhere" = "yes" ]; then
            while true; do
                read -p "Enter the absolute path to your virtual environment directory: " venv_path
                if [ -d "$venv_path" ]; then
                    echo "Virtual environment found at $venv_path."
                    export VENV_PATH="$venv_path"
                    source "$VENV_PATH/bin/activate" && python3 -m pip install gunicorn uvicorn fastapi >/dev/null
                    deactivate
                    break
                else
                    echo "Directory not found. Please enter a valid path."
                fi
            done
        else
            if check_file "$1/requirements.txt"; then
                echo "Setting up a new virtual environment and installing required packages from requirements.txt..."
                python3 -m venv "$1/venv" >/dev/null
                source "$1/venv/bin/activate" && python3 -m pip install -r "$1/requirements.txt" gunicorn uvicorn fastapi >/dev/null
                deactivate
                export VENV_PATH="$1/venv"
            else
                echo "No virtual environment or requirements.txt found. Installing FastAPI, Gunicorn, and Uvicorn in a new virtual environment..."
                python3 -m venv "$1/venv" >/dev/null
                source "$1/venv/bin/activate" && python3 -m pip install gunicorn uvicorn fastapi >/dev/null
                deactivate
                export VENV_PATH="$1/venv"
                echo "FastAPI, Gunicorn, and Uvicorn installed in the newly created virtual environment. Please note the implications of not having a requirements.txt file for dependency management."
            fi
        fi
    fi
}

configure_nginx() {
    echo "Configuring NGINX..."

    # Create NGINX configuration
    nginx_config="server {
        listen 80 default_server;
        listen [::]:80 default_server;

        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }"

    # Check if NGINX default configuration file exists
    if [ -f /etc/nginx/sites-available/default ]; then
        # Create a new NGINX configuration file
        echo "$nginx_config" | sudo tee /etc/nginx/sites-available/default >/dev/null
        sudo systemctl restart nginx >/dev/null
        echo "NGINX configured to proxy requests to FastAPI app."
    else
        echo "NGINX default configuration file not found. Please ensure NGINX is properly installed and configured."
    fi
}

create_service() {
    echo "Creating and starting systemd service..."

    read -p "Enter project directory (absolute path): " project_directory

    check_directory "$project_directory"

    check_venv "$project_directory"

    read -p "Enter project name: " project_name
    read -p "Enter the name of your main FastAPI app (e.g., 'app'): " fastapi_app_name

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

        sudo systemctl daemon-reload >/dev/null
        sudo systemctl start "$project_name" >/dev/null
        sudo systemctl enable "$project_name" >/dev/null
    fi
}

update_install
configure_nginx
create_service

echo "Deployment completed!"
