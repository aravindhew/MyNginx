# nginx role

Manages NGINX with a clean nginx.conf and multiple conf.d site files.

## Variables
See defaults/main.yml for all variables.

## Usage
```yaml
- hosts: web
  become: yes
  roles:
    - role: nginx
      vars:
        nginx_app_server_name: "myapp.local"
        nginx_app_root: "/var/www/myapp"
```
