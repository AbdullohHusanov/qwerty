### Install PostgreSQL and Setup

1. Install `apt install -y postgresql`
2. Change user `su - postgres`
3. Create new user `createuser --interactive --pwprompt`
4. Create database `createdb -O username postgres`
5. Logout from postgres role `exit`

(you can login into database using `psql -U username -d postgres -h localhost`)

### Setup python and run application

_Debian 12 already has python3_ so we dont need do anything with it

1. Install pip3 `apt install -y python3 python3-venv python3-pip`
2. Verify python's version `python3 --version or pip3 --version`
3. If there not showing the version then do the next step and check one more time
4. Make python3 default add `alias python="python3"` and `alias pip="pip3"` to ~/.bashrc
5. Unzip your backend `unzip server.zip`
6. One folder back create your .venv `python3 -m venv .venv`
7. Then activate it `source .venv/bin/activate`
8. Go to backend `cd project_folder/server`
9. Install dependencies `pip install -r requirements.txt`
10. Configure your .env `nano .env`
11. One folder back collectstatic `python manage.py collectstatic --no-input`
12. Migrate changes from the project's directory `python manage.py migrate`
13. Run project `python manage.py runserver`

### Gunicorn, Nginx, SSL

1. Open `nano /etc/systemd/system/gunicorn.socket` and write

```
[Unit]
Description=gunicorn socket
[Socket]
ListenStream=/run/gunicorn.sock
[Install]
WantedBy=sockets.target
```

2. Open `nano /etc/systemd/system/gunicorn.service` and put

```
[Unit]
Description=gunicorn daemon
Requires=gunicorn.sockeDest

[Service]
User=root
Group=www-data
WorkingDirectory=/home/user/server
ExecStart=/home/user/.venv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock config.wsgi:application

[Install]
WantedBy=multi-user.target
```

3. Run `systemctl start gunicorn.socket` `systemctl enable gunicorn.socket`
4. Check `curl --unix-socket /run/gunicorn.sock localhost` if error occurred run `journalctl -u gunicorn` to see logsx
5. Inatall nginx `apt install -y nginx`
6. Create file `nano /etc/nginx/sites-available/reestr` and put:

```
server {
    listen 80;
    listen [::]:80;
    server_name 10.130.9.31;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        alias /home/user/static/;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
```

7. Enable config `ln -s /etc/nginx/sites-available/reestr /etc/nginx/sites-enabled`
8. Put certificates to `/root/ssl`
9. Check `nginx -t`
10. Restart `systemctl restart nginx`

### Useful commands and snippents

- `journalctl -u gunicorn` - see gunicorn logs
- `systemctl restart nginx` - restart nginx
- `systemctl restart gunicorn` - restart gunicorn
- `nano /etc/nginx/sites-available/reestr` - change nginx settings
- `nginx -t` - check nginx config files







`server {
  root /home/admin/assistant/frontend/build/;
  index index.html;
  server_name app.staging.assistant.io;
  location / {
    try_files $uri /index.html;
  }
