#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

update_install() {
    echo -e "${CYAN}Updating system and installing required packages...${NC}"
    sudo apt-get update >/dev/null
    sudo apt-get -y install python3-pip python3-venv nginx >/dev/null
    echo -e "${GREEN}System updated and required packages installed.${NC}"
}

check_directory() {
    if [ ! -d "$1" ]; then
        echo -e "${RED}Directory $1 does not exist. Exiting.${NC}"
        exit 1
    fi
}

check_file() {
    if [ -f "$1/requirements.txt" ]; then
        return 0
    else
        return 1
    fi
}

install_requirements_or_framework() {
    if check_file "$1"; then
        echo -e "${CYAN}Installing packages from requirements.txt...${NC}"
        python3 -m pip install -r "$1/requirements.txt" >/dev/null
        echo -e "${GREEN}Packages from requirements.txt installed successfully.${NC}"
    else
        echo -e "${YELLOW}No requirements.txt found. Installing framework-specific packages.${NC}"
    fi

    # Install gunicorn and framework-specific packages
    echo -e "${CYAN}Installing gunicorn...${NC}"
    python3 -m pip install gunicorn >/dev/null

    case "$2" in
        Django)
            python3 -m pip install django >/dev/null
            ;;
        Flask)
            python3 -m pip install flask >/dev/null
            ;;
        FastAPI)
            python3 -m pip install fastapi uvicorn >/dev/null
            ;;
        *)
            echo -e "${RED}Unknown project type. Exiting.${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}Framework-specific packages installed.${NC}"
}

check_venv() {
    echo -e "${CYAN}Checking for an existing virtual environment (venv) in the project directory...${NC}"
    if [ -d "$1/venv" ]; then
        read -p "A virtual environment is found in the project directory. Do you want to use it? (yes/no) " use_venv
        if [ "$use_venv" = "yes" ]; then
            echo -e "${GREEN}Using the existing virtual environment in the project directory.${NC}"
            export VENV_PATH="$1/venv"
            source "$VENV_PATH/bin/activate"
            install_requirements_or_framework "$1" "$2"
            deactivate
        else
            setup_new_venv "$1" "$2"
        fi
    else
        setup_new_venv "$1" "$2"
    fi
}

setup_new_venv() {
    echo -e "${CYAN}Setting up a new virtual environment...${NC}"
    python3 -m venv "$1/venv" >/dev/null
    source "$1/venv/bin/activate"
    install_requirements_or_framework "$1" "$2"
    deactivate
    export VENV_PATH="$1/venv"
    echo -e "${GREEN}New virtual environment set up successfully.${NC}"
}

configure_nginx() {
    echo -e "${CYAN}Configuring NGINX...${NC}"

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

    if [ -f /etc/nginx/sites-available/default ]; then
        echo "$nginx_config" | sudo tee /etc/nginx/sites-available/default >/dev/null
        sudo systemctl restart nginx >/dev/null
        echo -e "${GREEN}NGINX configured to proxy requests to your app.${NC}"
    else
        echo -e "${RED}NGINX default configuration file not found. Please ensure NGINX is properly installed and configured.${NC}"
    fi
}

create_service() {
    echo -e "${CYAN}Creating and starting systemd service...${NC}"

    read -p "Enter project directory (absolute path): " project_directory
    check_directory "$project_directory"

    echo "Please choose your project type:"
    echo -e "${CYAN}1) Django"
    echo "2) Flask"
    echo "3) FastAPI${NC}"
    read -p "Enter your choice (1/2/3): " project_type_choice

    case "$project_type_choice" in
        1)
            project_type="Django"
            read -p "Enter Django configuration folder (where wsgi.py is located): " django_config_folder
            entry_point="$django_config_folder.wsgi:application"
            worker_class=""
            ;;
        2)
            project_type="Flask"
            read -p "Enter the name of your Flask app (e.g., 'app'): " flask_app_name
            entry_point="$flask_app_name:app"
            worker_class=""
            ;;
        3)
            project_type="FastAPI"
            read -p "Enter the name of your FastAPI app (e.g., 'app'): " fastapi_app_name
            entry_point="$fastapi_app_name:app"
            worker_class="--worker-class uvicorn.workers.UvicornWorker"
            ;;
        *)
            echo -e "${RED}Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac

    check_venv "$project_directory" "$project_type"

    read -p "Enter project name: " project_name

    service_file="/etc/systemd/system/$project_name.service"
    if [ -f "$service_file" ]; then
        echo -e "${YELLOW}Service file already exists. Skipping service creation.${NC}"
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
ExecStart=$VENV_PATH/bin/gunicorn $entry_point --workers 4 $worker_class --bind 0.0.0.0:8000

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload >/dev/null
        sudo systemctl start "$project_name" >/dev/null
        sudo systemctl enable "$project_name" >/dev/null
        echo -e "${GREEN}Service created and started successfully.${NC}"
    fi
}

# Main script starts here
echo -e "${CYAN}Welcome to the Python project setup script!${NC}"
update_install
create_service
configure_nginx
echo -e "${GREEN}Setup completed successfully.${NC}"
