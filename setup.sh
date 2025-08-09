#!/usr/bin/env bash
set -euo pipefail

ROLE_NAME="nginx"

# Create main.yaml
cat > main.yaml <<'EOF'
- name: Run nginx
  hosts: all
  become: true

  roles:
    - nginx
EOF

# Directories
mkdir -p "${ROLE_NAME}"/{defaults,files,handlers,meta,tasks,templates/conf.d,tests,vars}

# defaults/main.yml
cat > "${ROLE_NAME}/defaults/main.yml" <<'EOF'
nginx_package: nginx
nginx_service: nginx
nginx_conf_dir: /etc/nginx
nginx_main_conf: nginx.conf
nginx_conf_d: conf.d

# List of site config templates to deploy (from templates/conf.d/)
nginx_sites:
  - default.conf.j2
  - app.conf.j2

# Vars used by example templates
nginx_default_server_name: "_"
nginx_app_server_name: "example.com"
nginx_app_root: "/usr/share/nginx/html"
EOF

# handlers/main.yml
cat > "${ROLE_NAME}/handlers/main.yml" <<'EOF'
---
- name: validate and reload nginx
  listen: validate and reload nginx
  block:
    - name: Validate nginx configuration
      ansible.builtin.command:
        cmd: "nginx -t"
      register: nginx_check
      changed_when: false
    - name: Reload nginx
      ansible.builtin.service:
        name: "{{ nginx_service }}"
        state: reloaded
  rescue:
    - name: Show nginx test output
      ansible.builtin.debug:
        var: nginx_check.stderr
    - name: Fail if config invalid
        # Use fail to stop the play if validation failed
      ansible.builtin.fail:
        msg: "nginx config validation failed."
EOF

# meta/main.yml
cat > "${ROLE_NAME}/meta/main.yml" <<'EOF'
galaxy_info:
  role_name: nginx
  author: your_name
  description: Manage NGINX with modular conf.d configs and safe reload
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: EL
      versions: ["8","9"]
    - name: Debian
      versions: ["11","12"]
    - name: Ubuntu
      versions: ["20.04","22.04"]
dependencies: []
EOF

# tasks/main.yml
cat > "${ROLE_NAME}/tasks/main.yml" <<'EOF'
---
- name: Install nginx
  ansible.builtin.package:
    name: "{{ nginx_package }}"
    state: present

- name: Ensure conf.d directory exists
  ansible.builtin.file:
    path: "{{ nginx_conf_dir }}/{{ nginx_conf_d }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Deploy main nginx.conf
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: "{{ nginx_conf_dir }}/{{ nginx_main_conf }}"
    owner: root
    group: root
    mode: "0644"
  notify: validate and reload nginx

- name: Deploy site configs
  ansible.builtin.template:
    src: "conf.d/{{ item }}"
    dest: "{{ nginx_conf_dir }}/{{ nginx_conf_d }}/{{ item | regex_replace('\\.j2$', '') }}"
    owner: root
    group: root
    mode: "0644"
  loop: "{{ nginx_sites }}"
  notify: validate and reload nginx

- name: Ensure nginx is enabled and started
  ansible.builtin.service:
    name: "{{ nginx_service }}"
    enabled: true
    state: started
EOF

# templates/nginx.conf.j2
cat > "${ROLE_NAME}/templates/nginx.conf.j2" <<'EOF'
user nginx;
worker_processes auto;

error_log /var/log/nginx/error.log warn;
pid       /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile        on;
    keepalive_timeout 65;

    include {{ nginx_conf_dir }}/{{ nginx_conf_d }}/*.conf;
}
EOF

# templates/conf.d/default.conf.j2
cat > "${ROLE_NAME}/templates/conf.d/default.conf.j2" <<'EOF'
server {
    listen 80 default_server;
    server_name {{ nginx_default_server_name }};
    return 444;
}
EOF

# templates/conf.d/app.conf.j2
cat > "${ROLE_NAME}/templates/conf.d/app.conf.j2" <<'EOF'
server {
    listen 80;
    server_name {{ nginx_app_server_name }};

    root {{ nginx_app_root }};
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /healthz {
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
EOF

# tests/inventory
cat > "${ROLE_NAME}/tests/inventory" <<'EOF'
[all]
localhost ansible_connection=local
EOF

# tests/test.yml
cat > "${ROLE_NAME}/tests/test.yml" <<'EOF'
---
- hosts: all
  become: true
  roles:
    - nginx
EOF

# vars/main.yml
cat > "${ROLE_NAME}/vars/main.yml" <<'EOF'
# vars for nginx role (override in group_vars/host_vars)
EOF

# README.md
cat > "${ROLE_NAME}/README.md" <<'EOF'
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
EOF
