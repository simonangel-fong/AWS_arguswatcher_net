#!/bin/bash

# Program Name: beforeInstall.sh
# Author name: Wenhao Fang
# Date Created: Jan 1st 2024
# Date updated: Jan 1st 2024
# Description of the script:
#   Script for afterinstall, including packages installation.

###########################################################
## Arguments, subject to be changed
###########################################################
P_GITHUB_REPO_NAME=AWS_arguswatcher_net                         # github repo name
P_PROJECT_NAME=Arguswatcher                                     # the name of django project name
P_HOST_IP=$(dig +short myip.opendns.com @resolver1.opendns.com) # public IP, call method to update automatically
P_DOMAIN="arguswatcher.net"

P_HOME=/home/ubuntu                             # path of home dir
P_LOG=${P_HOME}/log                             # log file
P_VENV_PATH=${P_HOME}/env                       # path of venv
P_REPO_PATH=${P_HOME}/${P_GITHUB_REPO_NAME}     # path of repo
P_PROJECT_PATH=${P_REPO_PATH}/${P_PROJECT_NAME} # path of project, where the manage.py locates.

log() {
    sudo echo -e "$(date +'%Y-%m-%d %R'): ${1}" >>$P_LOG
}

###########################################################
## Establish virtual environment
###########################################################
# Remove existing venv
sudo rm -rf $P_VENV_PATH &&
    log "remove existing venv" || log "Fail: remove existing venv"

# Install python3-venv package
sudo apt-get -y install python3-venv &&
    log "Install python3-venv package" || log "Fail: Install python3-venv package"

# Creates virtual environment
python3 -m venv $P_VENV_PATH &&
    log "Creates virtual environment" || log "Fail: Creates virtual environment"

###########################################################
## Install app dependencies
###########################################################

source ${P_VENV_PATH}/bin/activate # activate venv
echo -e "$(date +'%Y-%m-%d %R') Activate venv" >>~/log

pip install -r ${P_REPO_PATH}/requirements.txt # install dependencies based on the requirements.txt
echo -e "$(date +'%Y-%m-%d %R') install dependencies based on the requirements.txt" >>~/log

deactivate # deactivate venv
echo -e "$(date +'%Y-%m-%d %R') Deactivate venv" >>~/log

###########################################################
## Install gunicorn in venv
###########################################################

source ${P_VENV_PATH}/bin/activate # activate venv
echo -e "$(date +'%Y-%m-%d %R') Activate venv" >>~/log

pip install gunicorn # install gunicorn
echo -e "$(date +'%Y-%m-%d %R') install gunicorn" >>~/log

deactivate # deactivate venv
echo -e "$(date +'%Y-%m-%d %R') deactivate venv" >>~/log

###########################################################
## Configuration gunicorn.socket
###########################################################
socket_conf=/etc/systemd/system/gunicorn.socket

sudo bash -c "sudo cat >$socket_conf <<SOCK
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
SOCK"
echo -e "$(date +'%Y-%m-%d %R') Configure gunicorn.socket." >>~/log

###########################################################
## Configuration gunicorn.service
###########################################################
service_conf=/etc/systemd/system/gunicorn.service

sudo bash -c "sudo cat >$service_conf <<SERVICE
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=root
Group=www-data 
WorkingDirectory=${P_PROJECT_PATH}
ExecStart=/home/ubuntu/env/bin/gunicorn \
    --access-logfile - \
    --workers 3 \
    --bind unix:/run/gunicorn.sock \
    ${P_PROJECT_NAME}.wsgi:application

[Install]
WantedBy=multi-user.target
SERVICE"
echo -e "$(date +'%Y-%m-%d %R') Configure gunicorn.service." >>~/log

###########################################################
## Apply gunicorn configuration
###########################################################
sudo systemctl daemon-reload # reload daemon
echo -e "$(date +'%Y-%m-%d %R') reload daemon." >>~/log

sudo systemctl start gunicorn.socket # Start gunicorn
echo -e "$(date +'%Y-%m-%d %R') Start gunicorn." >>~/log

sudo systemctl enable gunicorn.socket # enable on boots
echo -e "$(date +'%Y-%m-%d %R') enable on boots." >>~/log

sudo systemctl restart gunicorn # restart gunicorn
echo -e "$(date +'%Y-%m-%d %R') restart gunicorn." >>~/log

###########################################################
## Configuration nginx
###########################################################
sudo apt-get install -y nginx # install nginx
echo -e "$(date +'%Y-%m-%d %R') install nginx." >>~/log

nginx_conf=/etc/nginx/nginx.conf
sudo sed -i '1cuser root;' $nginx_conf # overwrites user
echo -e "$(date +'%Y-%m-%d %R') overwrites user." >>~/log

# create conf file
django_conf=/etc/nginx/sites-available/django.conf
sudo bash -c "cat >$django_conf <<DJANGO_CONF
server {
listen 80;
server_name ${P_HOST_IP} ${P_DOMAIN} www.${P_DOMAIN};
location = /favicon.ico { access_log off; log_not_found off; }
location /static/ {
    root ${P_PROJECT_PATH};
}

location /media/ {
    root ${P_PROJECT_PATH};
}

location / {
    include proxy_params;
    proxy_pass http://unix:/run/gunicorn.sock;
}
}
DJANGO_CONF"
echo -e "$(date +'%Y-%m-%d %R') create django.conf file." >>~/log

#  Creat link in sites-enabled directory
sudo ln -sf /etc/nginx/sites-available/django.conf /etc/nginx/sites-enabled
echo -e "$(date +'%Y-%m-%d %R') Creat link in sites-enabled directory." >>~/log

sudo systemctl restart nginx # restart nginx
echo -e "$(date +'%Y-%m-%d %R') restart nginx." >>~/log

###########################################################
## Configuration supervisor
###########################################################
sudo apt-get install -y supervisor # install supervisor
echo -e "$(date +'%Y-%m-%d %R') install supervisor." >>~/log

sudo mkdir -p /var/log/gunicorn # create directory for logging
echo -e "$(date +'%Y-%m-%d %R') create directory for logging." >>~/log

supervisor_gunicorn=/etc/supervisor/conf.d/gunicorn.conf # create configuration file
sudo bash -c "cat >$supervisor_gunicorn <<SUP_GUN
[program:gunicorn]
    directory=${P_PROJECT_PATH}
    command=${P_VENV_PATH}/bin/gunicorn --workers 3 --bind unix:/run/gunicorn.sock  ${P_PROJECT_NAME}.wsgi:application
    autostart=true
    autorestart=true
    stderr_logfile=/var/log/gunicorn/gunicorn.err.log
    stdout_logfile=/var/log/gunicorn/gunicorn.out.log

[group:guni]
    programs:gunicorn
SUP_GUN"
echo -e "$(date +'%Y-%m-%d %R') create supervisor file for gunicorn logging." >>~/log

sudo supervisorctl reread # tell supervisor read configuration file
echo -e "$(date +'%Y-%m-%d %R') tell supervisor read configuration file." >>~/log

sudo supervisorctl update # update supervisor configuration
echo -e "$(date +'%Y-%m-%d %R') update supervisor configuration." >>~/log

sudo systemctl daemon-reload
echo -e "$(date +'%Y-%m-%d %R') daemon-reload." >>~/log

sudo supervisorctl reload # Restarted supervisord
echo -e "$(date +'%Y-%m-%d %R') Restarted supervisord." >>~/log
