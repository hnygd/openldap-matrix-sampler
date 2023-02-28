#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: oms init [-hv] [-n network] [-r freebsd_version] sampler_name

    network defaults to '10.100.1' - do not change as things break
    freebd_version defaults to '13.1'
"
}

if [ -f config.ini ]; then
    # shellcheck disable=SC1091
    source config.ini
else
    echo "config.ini is missing? Please fix"
    exit 1; exit 1
fi

if [ -z "${ACCESSIP}" ]; then
    echo "ACCESSIP is unset. Please configure web access IP in config.ini"
    exit 1; exit 1
fi

# Current FreeBSD version
FREEBSD_VERSION=13.1

# Do not change this if using Virtualbox DHCP on primary interface
GATEWAY="10.0.2.2"

# enable experimental disk support
export VAGRANT_EXPERIMENTAL="disks"

OPTIND=1
while getopts "hv:n:r:" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  v)
    # shellcheck disable=SC2034
    VERBOSE="YES"
    ;;
  n)
    NETWORK="${OPTARG}"
    ;;
  r)
    FREEBSD_VERSION="${OPTARG}"
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

shift "$((OPTIND-1))"

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

NETWORK="$(echo "${NETWORK:=10.100.1}" | awk -F\. '{ print $1"."$2"."$3 }')"
SAMPLER_NAME="$1"

set -eE
trap 'echo error: $STEP failed' ERR
# shellcheck disable=SC1091
source "${INCLUDE_DIR}/common.sh"
common_init_vars

set -eE
trap 'echo error: $STEP failed' ERR

if [ -z "${SAMPLER_NAME}" ] || [ -z "${FREEBSD_VERSION}" ]; then
  usage
  exit 1
fi

if [[ ! "${SAMPLER_NAME}" =~ $SAMPLER_NAME_REGEX ]]; then
  >&2 echo "invalid sampler name $SAMPLER_NAME"
  exit 1
fi

if [[ ! "${FREEBSD_VERSION}" =~ $FREEBSD_VERSION_REGEX ]]; then
  >&2 echo "unsupported freebsd version $FREEBSD_VERSION"
  exit 1
fi

if [[ ! "${NETWORK}" =~ $NETWORK_REGEX ]]; then
  >&2 echo "invalid network $NETWORK (expecting A.B.C, e.g. 10.100.1)"
  exit 1
fi

step "Init sampler"
mkdir "$SAMPLER_NAME"
git init "$SAMPLER_NAME" >/dev/null
cd "$SAMPLER_NAME"
if [ "$(git branch --show-current)" = "master" ]; then
  git branch -m master main
fi

step "Generate SSH key to upload"
ssh-keygen -b 2048 -t rsa -f myhostkey -q -N ""

# temp fix
step "Make _build directory as a temporary fix for error which crops up"
mkdir -p _build/

# fix for SSH timeouts
export SSH_AUTH_SOCK=""

# add remote IP to file for ansible read
echo "${ACCESSIP}" > access.ip

# Create ansible site.yml to process once hosts are up
cat >site.yml<<"EOF"
---

- hosts: all
  tasks:
  - name: Build facts from stored UUID values
    set_fact:
      myhost_access_ip: "{{ lookup('file', 'access.ip') }}"
      myhost1_hostname: ldap1
      myhost2_hostname: ldap2
      myhost_nat_gateway: 10.100.1.1
      myhost1_ip_address: 10.100.1.3
      myhost2_ip_address: 10.100.1.4
      myhost_nameserver: 8.8.8.8
      myhost_ssh_key: "~/.ssh/myhostkey"
      myhost1_ssh_port: 12222
      myhost2_ssh_port: 12223
      datacenter_name: "samplerdc"
      gossip_key: "BBtPyNSRI+/iP8RHB514CZ5By3x1jJLu4SqTVzM4gPA="
      jails_interface: jailnet
      consul_base: consul-amd64-13_1
      consul_version: "2.2.1"
      consul_pot_name: consul-amd64-13_1_2_2_1
      consul_clone_name: consul-clone
      consul_url: https://potluck.honeyguide.net/consul
      consul_ip: 10.200.1.2
      consul_nodename: consul
      consul_bootstrap: 1
      consul_peers: 1.2.3.4
      openldap_base: openldap-amd64-13_1
      openldap_version: "1.6.15"
      openldap_pot_name: openldap-amd64-13_1_1_6_15
      openldap_clone_name: openldap-clone
      openldap_url: https://potluck.honeyguide.net/openldap
      openldap_ip: 10.200.1.10
      openldap_nodename: ldap1
      openldap_creds: "password"
      openldap_hostname: ldap1.local
      openldap_domain: ldap.local
      openldap_mount_in: "/mnt/data/jaildata/openldap"
      openldap_mount_path: "/mnt/"
      openldap_cron_path: "/mnt/openldap-data/backups"
      openldap_serverid: 001
      openldap_remoteip: 10.200.1.50
      openldap_genericuser: "matrixuser"
      openldap_genericpass: "matrixpass"
      openldap_spare_base: openldap-amd64-13_1
      openldap_spare_version: "1.6.15"
      openldap_spare_pot_name: openldap-spare-amd64-13_1_1_6_15
      openldap_spare_clone_name: openldap-spare-clone
      openldap_spare_url: https://potluck.honeyguide.net/openldap
      openldap_spare_ip: 10.200.1.50
      openldap_spare_nodename: ldap2
      openldap_spare_creds: "password"
      openldap_spare_hostname: ldap2.local
      openldap_spare_domain: ldap.local
      openldap_spare_mount_in: "/mnt/data/jaildata/openldapspare"
      openldap_spare_mount_path: "/mnt/"
      openldap_spare_cron_path: "/mnt/openldap-data/backups"
      openldap_spare_serverid: 002
      openldap_spare_remoteip: 10.200.1.10
      openldap_spare_genericuser: "matrixuser"
      openldap_spare_genericpass: "matrixpass"
      matrix_base: matrix-synapse-amd64-13_1
      matrix_version: "1.2.4"
      matrix_pot_name: matrix-synapse-amd64-13_1_1_2_4
      matrix_clone_name: matrix-clone
      matrix_url: https://potluck.honeyguide.net/matrix-synapse
      matrix_ip: 10.200.1.15
      matrix_nodename: matrix
      matrix_domain: matrix.local
      matrix_shared_secret: "secret"
      matrix_smtp_host: "localhost"
      matrix_smtp_port: 25
      matrix_smtp_user: "vagrant"
      matrix_smtp_pass: "vagrant"
      matrix_ldap_host: "10.200.1.10"
      matrix_ldap_username: "matrixuser"
      matrix_ldap_password: "matrixpass"
      matrix_ldap_domain: "matrix.local"
      matrix_mount_in: "/mnt/data/jaildata/matrix"
      matrix_mount_path: "/mnt"
      matrix_control_user: true
      matrix_control_sshkey: "~/pubkey.asc"
      matrix_control_sskkeyout: /root/importauthkey

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Enable root ssh logins and set keep alives
    become: yes
    become_user: root
    shell:
      cmd: |
        sed -i '' \
          -e 's|^#PermitRootLogin no|PermitRootLogin yes|g' \
          -e 's|^#Compression delayed|Compression no|g' \
          -e 's|^#ClientAliveInterval 0|ClientAliveInterval 20|g' \
          -e 's|^#ClientAliveCountMax 3|ClientAliveCountMax 5|g' \
          /etc/ssh/sshd_config

  - name: Restart sshd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: sshd
      state: restarted

  - name: Wait for port 22 to become open, wait for 5 seconds
    wait_for:
      port: 22
      delay: 5

  - name: Add hosts to /etc/hosts
    become: yes
    become_user: root
    shell:
      cmd: |
        cat <<EOH >> /etc/hosts
        {{ myhost1_ip_address }} {{ myhost1_hostname }}
        {{ myhost2_ip_address }} {{ myhost2_hostname }}
        EOH

  - name: Add dns to resolv.conf
    become: yes
    become_user: root
    copy:
      dest: /etc/resolv.conf
      content: |
        nameserver {{ myhost_nameserver }}
        nameserver 10.0.2.3

  - name: Create pkg config directory
    become: yes
    become_user: root
    file: path=/usr/local/etc/pkg/repos state=directory mode=0755

  - name: Create pkg config
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/pkg/repos/FreeBSD.conf
      content: |
        FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }

  - name: Upgrade package pkg
    become: yes
    become_user: root
    shell:
      cmd: "pkg upgrade -qy pkg"

  - name: Force package update
    become: yes
    become_user: root
    shell:
      cmd: "pkg update -fq"

  - name: Upgrade packages
    become: yes
    become_user: root
    shell:
      cmd: "pkg upgrade -qy"

  - name: Install common packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - bash
        - curl
        - nano
        - vim-tiny
        - sudo
        - python39
        - go119
        - gmake
        - rsync
        - tmux
        - jq
        - dmidecode
        - openntpd
        - pftop
        - openssl
        - nginx-full
        - nmap
      state: present

  - name: Enable openntpd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: openntpd
      enabled: yes

  - name: Start openntpd
    become: yes
    become_user: root
    ansible.builtin.service:
      name: openntpd
      state: started

  - name: Disable coredumps
    become: yes
    become_user: root
    sysctl:
      name: kern.coredump
      value: '0'

  - name: Create .ssh directory
    ansible.builtin.file:
      path: /home/vagrant/.ssh
      state: directory
      mode: '0700'
      owner: vagrant
      group: vagrant

  - name: Create root .ssh directory
    ansible.builtin.file:
      path: /root/.ssh
      state: directory
      mode: '0700'
      owner: root
      group: wheel

  - name: copy over ssh private key
    ansible.builtin.copy:
      src: myhostkey
      dest: /home/vagrant/.ssh/myhostkey
      owner: vagrant
      group: vagrant
      mode: '0600'

  - name: copy over ssh private key to root
    ansible.builtin.copy:
      src: myhostkey
      dest: /root/.ssh/myhostkey
      owner: root
      group: wheel
      mode: '0600'

  - name: copy over ssh public key
    ansible.builtin.copy:
      src: myhostkey.pub
      dest: /home/vagrant/.ssh/myhostkey.pub
      owner: vagrant
      group: vagrant
      mode: '0600'

  - name: copy over ssh public key to root
    ansible.builtin.copy:
      src: myhostkey.pub
      dest: /root/.ssh/myhostkey.pub
      owner: root
      group: wheel
      mode: '0600'

  - name: Append ssh pubkey to authorized_keys
    become: yes
    become_user: vagrant
    shell:
      chdir: /home/vagrant/
      cmd: |
        cat /home/vagrant/.ssh/myhostkey.pub >> /home/vagrant/.ssh/authorized_keys

  - name: Append ssh pubkey to authorized_keys for root
    become: yes
    become_user: root
    shell:
      chdir: /root/
      cmd: |
        cat /root/.ssh/myhostkey.pub >> /root/.ssh/authorized_keys

- hosts: ldap1
  gather_facts: yes
  tasks:
  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Create ssh client config
    become: yes
    become_user: vagrant
    copy:
      dest: /home/vagrant/.ssh/config
      content: |
        Host {{ myhost1_hostname }}
          # HostName {{ myhost1_ip_address }}
          HostName {{ myhost_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/myhostkey
          # Port 22
          Port {{ myhost1_ssh_port }}
          Compression no
          ServerAliveInterval 20

        Host {{ myhost2_hostname }}
          # HostName {{ myhost2_ip_address }}
          HostName {{ myhost_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/myhostkey
          # Port 22
          Port {{ myhost2_ssh_port }}
          Compression no
          ServerAliveInterval 20

  - name: Create ssh client config for root user
    become: yes
    become_user: root
    copy:
      dest: /root/.ssh/config
      content: |
        Host {{ myhost1_hostname }}
          # HostName {{ myhost1_ip_address }}
          HostName {{ myhost_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/myhostkey
          Port {{ myhost1_ssh_port }}
          ServerAliveInterval 20

        Host {{ myhost2_hostname }}
          # HostName {{ myhost2_ip_address }}
          HostName {{ myhost_nat_gateway }}
          StrictHostKeyChecking no
          User vagrant
          IdentityFile ~/.ssh/myhostkey
          Port {{ myhost2_ssh_port }}
          ServerAliveInterval 20

  - name: Wait for ssh to become available on ldap1
    become: yes
    become_user: root
    wait_for:
      host: "{{ myhost_nat_gateway }}"
      port: "{{ myhost1_ssh_port }}"
      delay: 10
      timeout: 120
      state: started

  - name: Run ssh-keyscan on ldap2 (mitigating an error that crops up otherwise)
    become: yes
    become_user: root
    shell:
      cmd: |
        ssh-keyscan -T 20 -p {{ myhost2_ssh_port }} {{ myhost_nat_gateway }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Wait for ssh to become available ldap2
    become: yes
    become_user: root
    wait_for:
      host: "{{ myhost_nat_gateway }}"
      port: "{{ myhost2_ssh_port }}"
      delay: 10
      timeout: 120
      state: started

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup ZFS datasets
    become: yes
    become_user: root
    shell:
      cmd: |
        zfs create -o mountpoint=/mnt/srv zroot/srv
        zfs create -o mountpoint=/mnt/data zroot/data
        zfs create -o mountpoint=/mnt/data/jaildata zroot/data/jaildata
        zfs create -o mountpoint=/mnt/data/jaildata/openldap zroot/data/jaildata/openldap
        zfs create -o mountpoint=/mnt/data/jaildata/openldapspare zroot/data/jaildata/openldapspare
        zfs create -o mountpoint=/mnt/data/jaildata/matrix zroot/data/jaildata/matrix

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Install needed packages
    become: yes
    become_user: root
    ansible.builtin.package:
      name:
        - consul
        - pot
        - potnet
        # - haproxy
      state: present

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Setup pot.conf
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/pot/pot.conf
      content: |
        POT_ZFS_ROOT=zroot/srv/pot
        POT_FS_ROOT=/mnt/srv/pot
        POT_CACHE=/var/cache/pot
        POT_TMP=/tmp
        POT_NETWORK=10.192.0.0/10
        POT_NETMASK=255.192.0.0
        POT_GATEWAY=10.192.0.1
        POT_EXTIF=untrusted

  - name: Initiate pot
    become: yes
    become_user: root
    shell:
      cmd: |
        pot init -v

  - name: Enable pot
    become: yes
    become_user: root
    ansible.builtin.service:
      name: pot
      enabled: yes

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Make consul directory
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /usr/local/etc/consul.d

  - name: Set consul.d permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d"
      state: directory
      mode: '0750'
      owner: consul
      group: wheel

  - name: Setup consul client agent.json
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/consul.d/agent.json
      content: |
        {
          "bind_addr": "{{ myhost1_ip_address }}",
          "client_addr": "127.0.0.1",
          "server": false,
          "node_name": "{{ openldap_nodename }}",
          "datacenter": "{{ datacenter_name }}",
          "log_level": "WARN",
          "data_dir": "/var/db/consul",
          "tls": {
            "defaults": {
              "verify_incoming": false,
              "verify_outgoing": false
            },
            "internal_rpc": {
              "verify_incoming": false,
              "verify_server_hostname": false
            }
          },
          "encrypt": "{{ gossip_key }}",
          "enable_syslog": true,
          "leave_on_terminate": true,
          "start_join": [ "{{ consul_ip }}" ],
          "telemetry": {
            "prometheus_retention_time": "24h"
          }
        }

  - name: Set agent.json permissions
    ansible.builtin.file:
      path: "/usr/local/etc/consul.d/agent.json"
      mode: '600'
      owner: consul
      group: wheel

  - name: change ownership on consul.d files
    become: yes
    become_user: root
    shell:
      cmd: |
        chown -R consul:wheel /usr/local/etc/consul.d/

  - name: Create consul log file
    become: yes
    become_user: root
    shell:
      cmd: |
        mkdir -p /var/log/consul
        touch /var/log/consul/consul.log

  - name: Enable consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      enabled: yes

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the consul pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ consul_base }} -t {{ consul_version }} -U {{ consul_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the consul pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone \
          -P {{ consul_pot_name }} \
          -p {{ consul_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ consul_ip }}"
        pot set-env -p {{ consul_clone_name }} \
          -E DATACENTER={{ datacenter_name }} \
          -E NODENAME={{ consul_nodename }} \
          -E IP={{ consul_ip }} \
          -E BOOTSTRAP={{ consul_bootstrap }} \
          -E PEERS={{ consul_peers }} \
          -E GOSSIPKEY={{ gossip_key }} 
        pot set-attr -p {{ consul_clone_name }} -A start-at-boot -V True
        pot start {{ consul_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: Start consul
    become: yes
    become_user: root
    ansible.builtin.service:
      name: consul
      state: started

  - name: download the openldap pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ openldap_base }} -t {{ openldap_version }} -U {{ openldap_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the openldap pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone \
          -P {{ openldap_pot_name }} \
          -p {{ openldap_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ openldap_ip }}"
        pot mount-in -p {{ openldap_clone_name }} -d {{ openldap_mount_in }} -m {{ openldap_mount_path }} 
        pot set-env -p {{ openldap_clone_name }} \
          -E NODENAME={{ openldap_nodename }} \
          -E DATACENTER={{ datacenter_name }} \
          -E IP={{ openldap_ip }} \
          -E GOSSIPKEY={{ gossip_key }} \
          -E CONSULSERVERS={{ consul_ip }} \
          -E DOMAIN={{ openldap_domain }} \
          -E MYCREDS={{ openldap_creds }} \
          -E HOSTNAME={{ openldap_hostname }} \
          -E CRONBACKUP={{ openldap_cron_path }} \
          -E DEFAULTGROUPS=Y \
          -E USERNAME={{ openldap_genericuser }} \
          -E PASSWORD={{ openldap_genericpass }} \
          -E SERVERID={{ openldap_serverid }} \
          -E REMOTEIP={{ openldap_spare_ip }}
        pot set-attr -p {{ openldap_clone_name }} -A start-at-boot -V True
        pot start {{ openldap_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the openldap spare pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone \
          -P {{ openldap_pot_name }} \
          -p {{ openldap_spare_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ openldap_spare_ip }}"
        pot mount-in -p {{ openldap_spare_clone_name }} -d {{ openldap_spare_mount_in }} -m {{ openldap_spare_mount_path }} 
        pot set-env -p {{ openldap_spare_clone_name }} \
          -E NODENAME={{ openldap_spare_nodename }} \
          -E DATACENTER={{ datacenter_name }} \
          -E IP={{ openldap_spare_ip }} \
          -E GOSSIPKEY={{ gossip_key }} \
          -E CONSULSERVERS={{ consul_ip }} \
          -E DOMAIN={{ openldap_domain }} \
          -E MYCREDS={{ openldap_spare_creds }} \
          -E HOSTNAME={{ openldap_spare_hostname }} \
          -E CRONBACKUP={{ openldap_spare_cron_path }} \
          -E DEFAULTGROUPS=Y \
          -E SERVERID={{ openldap_spare_serverid }} \
          -E REMOTEIP={{ openldap_ip }}
        pot set-attr -p {{ openldap_spare_clone_name }} -A start-at-boot -V True
        pot start {{ openldap_spare_clone_name }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: download the matrix-synapse pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot import -p {{ matrix_base }} -t {{ matrix_version }} -U {{ matrix_url }}

  - name: Wait for port 22 to become open, wait for 2 seconds
    wait_for:
      port: 22
      delay: 2

  - name: setup and start the matrix-synapse pot image
    become: yes
    become_user: root
    shell:
      cmd: |
        pot clone \
          -P {{ matrix_pot_name }} \
          -p {{ matrix_clone_name }} \
          -N alias -i "{{ jails_interface }}|{{ matrix_ip }}"
        pot mount-in -p {{ matrix_clone_name }} -d {{ matrix_mount_in }} -m {{ matrix_mount_path }}
        pot set-env -p {{ matrix_clone_name }} \
          -E DATACENTER={{ datacenter_name }} \
          -E CONSULSERVERS={{ consul_ip }} \
          -E GOSSIPKEY={{ gossip_key }} \
          -E NODENAME={{ matrix_nodename }} \
          -E IP={{ matrix_ip }} \
          -E DOMAIN={{ matrix_domain }} \
          -E ALERTEMAIL="solo@nowhere.net" \
          -E REGISTRATIONENABLE=false \
          -E MYSHAREDSECRET={{ matrix_shared_secret }} \
          -E SMTPHOST={{ matrix_smtp_host }} \
          -E SMTPPORT={{ matrix_smtp_port }} \
          -E SMTPUSER={{ matrix_smtp_user }} \
          -E SMTPPASS={{ matrix_smtp_pass }} \
          -E SMTPFROM="matrix@ldap1.local" \
          -E LDAPSERVER={{ openldap_ip }} \
          -E LDAPPASSWORD={{ matrix_ldap_password }} \
          -E LDAPDOMAIN={{ matrix_ldap_domain }} \
          -E CONTROLUSER=true \
          -E NOSSL=true \
          -E SSLEMAIL=none
        pot set-attr -p {{ matrix_clone_name }} -A start-at-boot -V True
        pot start {{ matrix_clone_name }}

  - name: Update nginx.conf with proxy
    become: yes
    become_user: root
    copy:
      dest: /usr/local/etc/nginx/nginx.conf
      content: |
        worker_processes  1;
        error_log /var/log/nginx/error.log;
        events {
          worker_connections 4096;
        }
        http {
          include mime.types;
          default_type application/octet-stream;
          sendfile on;
          keepalive_timeout 65;
          gzip off;
          server {
            listen 80;
            server_name {{ myhost1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            root /usr/local/www/sampler;
            index index.html;
            location / {
               try_files $uri $uri/ /index.html;
            }
          }
          server {
            listen 8080;
            server_name {{ myhost1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            root /usr/local/www/sampler;
            index index.html;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ openldap_ip }}:80;
            }
          }
          server {
            listen 9090;
            server_name {{ myhost1_hostname }};
            ignore_invalid_headers off;
            client_max_body_size 0;
            proxy_buffering off;
            root /usr/local/www/sampler;
            index index.html;
            location / {
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $http_host;
              proxy_connect_timeout 300;
              proxy_http_version 1.1;
              proxy_set_header Connection "";
              chunked_transfer_encoding off;
              proxy_buffering off;
              proxy_pass http://{{ matrix_ip }}:80;
            }
          }
        }

  - name: Create directory /usr/local/www/sampler
    ansible.builtin.file:
      path: /usr/local/www/sampler
      state: directory
      mode: '0755'
      owner: root
      group: wheel

  - name: Create default sampler index.html
    become: yes
    become_user: root
    copy:
      dest: /usr/local/www/sampler/index.html
      content: |
        <!DOCTYPE html>
        <html>
        <head>
        <title>Welcome to openldap-matrix-sampler!</title>
        <style>
        html { color-scheme: light dark; }
        body { width: 35em; margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif; }
        </style>
        </head>
        <body>
        <h1>Welcome to openldap-matrix-sampler!</h1>
        <p>Please choose from the following:</p>
        <ul>
          <li><a href="http://{{ myhost_access_ip }}:8080">LAM: LDAP Account Manager</a></li>
          <li><a href="http://{{ myhost_access_ip }}:9090">Matrix frontend (no SSL)</a></li>
        </ul>
        </body>
        </html>

  - name: Enable nginx
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nginx
      enabled: yes

  - name: Start nginx
    become: yes
    become_user: root
    ansible.builtin.service:
      name: nginx
      state: started


  # - name: Wait for port 22 to become open, wait for 2 seconds
  #   wait_for:
  #     port: 22
  #     delay: 2

# - hosts: ldap2
#   gather_facts: yes
#   tasks:
#   - name: Wait for port 22 to become open, wait for 2 seconds
#     wait_for:
#       port: 22
#       delay: 2

#   - name: Setup ZFS datasets
#     become: yes
#     become_user: root
#     shell:
#       cmd: |
#         zfs create -o mountpoint=/mnt/srv zroot/srv
#         zfs create -o mountpoint=/mnt/data zroot/data

#   - name: Install packages
#     become: yes
#     become_user: root
#     ansible.builtin.package:
#       name:
#         - consul
#         - node_exporter
#       state: present

#   - name: Wait for port 22 to become open, wait for 2 seconds
#     wait_for:
#       port: 22
#       delay: 2

#   - name: Make consul directory
#     become: yes
#     become_user: root
#     shell:
#       cmd: |
#         mkdir -p /usr/local/etc/consul.d

#   - name: Set consul.d permissions
#     ansible.builtin.file:
#       path: "/usr/local/etc/consul.d"
#       state: directory
#       mode: '0750'
#       owner: consul
#       group: wheel

# - hosts: ldap1
#   gather_facts: yes
#   tasks:
#   - name: Wait for port 22 to become open, wait for 2 seconds
#     wait_for:
#       port: 22
#       delay: 2

EOF

step "Create Vagrantfile"
cat >Vagrantfile<<EOV
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "ldap1", primary: true do |node|
    node.vm.hostname = 'ldap1'
    node.vm.boot_timeout = 600
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.ssh.forward_agent = false
    node.vm.communicator = "ssh"
    node.ssh.connect_timeout = 60
    node.ssh.keep_alive = true
    node.disksize.size = '32GB'
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = "8"
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["modifyvm", :id, "--audio", "none"]
      vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype3", "virtio"]
      vb.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = "virtio"
    node.vm.network :forwarded_port, guest: 22, host_ip: "${NETWORK}.1", host: 12222, id: "myhost1-ssh"
    node.vm.network :forwarded_port, guest_ip: "10.200.1.10", guest: 80, host_ip: "${NETWORK}.1", host: 8080, id: "myhost1-openldap"
    node.vm.network :forwarded_port, guest_ip: "10.200.1.15", guest: 80, host_ip: "${NETWORK}.1", host: 9090, id: "myhost1-matrix"
    end
    node.vm.network :private_network, ip: "${NETWORK}.3", auto_config: false
    node.vm.network :public_network, ip: "${ACCESSIP}", auto_config: false
    node.vm.provision "shell", run: "always", inline: <<-SHELL
      sysrc ipv6_network_interfaces="none"
      ifconfig vtnet0 name untrusted
      ifconfig vtnet1 "${NETWORK}.3" netmask 255.255.255.0 up
      ifconfig vtnet2 "${ACCESSIP}" netmask 255.255.255.0 up
      sysrc ifconfig_vtnet0_name="untrusted"
      sysrc ifconfig_untrusted="SYNCDHCP"
      sysrc ifconfig_vtnet1="inet ${NETWORK}.3 netmask 255.255.255.0"
      sysrc ifconfig_vtnet2="inet ${ACCESSIP} netmask 255.255.255.0"
      sysrc defaultrouter="${GATEWAY}"
      sysrc gateway_enable="YES"
      sed -i ".orig" -e "s|files mdns dns|files mdns_minimal [NOTFOUND=return] dns mdns|g" /etc/nsswitch.conf
      sysctl -w security.jail.allow_raw_sockets=1
      echo "security.jail.allow_raw_sockets=1" >> /etc/sysctl.conf
      sysctl -w net.inet.ip.forwarding=1
      echo "net.inet.ip.forwarding=1" >> /etc/sysctl.conf
      service netif restart && service routing restart
      ifconfig jailnet create vlan 1001 vlandev untrusted
      ifconfig jailnet inet 10.200.1.1/24 up
      ifconfig compute create vlan 1006 vlandev untrusted
      ifconfig compute inet 10.200.2.1/24 up
      sysrc vlans_untrusted="jailnet compute"
      sysrc create_args_jailnet="vlan 1001"
      sysrc ifconfig_jailnet="inet 10.200.1.1/24"
      sysrc create_args_compute="vlan 1006"
      sysrc ifconfig_compute="inet 10.200.2.1/24"
      sysrc static_routes="jailstatic computestatic"
      sysrc route_jailstatic="-net 10.200.1.0/24 10.200.1.1"
      sysrc route_computestatic="-net 10.200.2.0/24 10.200.2.1"
      service netif restart && service routing restart
      echo "checking DNS resolution with ping"
      ping -c 1 google.com || true
      sysrc clear_tmp_enable="YES"
    SHELL
  end
  config.vm.define "ldap2", primary: false do |node|
    node.vm.hostname = 'ldap2'
    node.vm.boot_timeout = 600
    node.vm.box = "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"
    node.vm.synced_folder '.', '/vagrant', disabled: true
    node.ssh.forward_agent = false
    node.vm.communicator = "ssh"
    node.ssh.connect_timeout = 60
    node.ssh.keep_alive = true
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = "4"
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--vrde", "off"]
      vb.customize ["modifyvm", :id, "--audio", "none"]
      vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
      vb.customize ["modifyvm", :id, "--nicpromisc1", "allow-all"]
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["setextradata", :id,
        "VBoxInternal/Devices/ahci/0/LUN#[0]/Config/IgnoreFlush", "0"]
      vb.default_nic_type = "virtio"
    node.vm.network :forwarded_port, guest: 22, host_ip: "${NETWORK}.1", host: 12223, id: "myhost2-ssh"
    end
    node.vm.network :private_network, ip: "${NETWORK}.4", auto_config: false
    node.vm.provision "shell", run: "always", inline: <<-SHELL
      sysrc ipv6_network_interfaces="none"
      ifconfig vtnet0 name untrusted
      ifconfig vtnet1 "${NETWORK}.4" netmask 255.255.255.0 up
      sysrc ifconfig_vtnet0_name="untrusted"
      sysrc ifconfig_untrusted="SYNCDHCP"
      sysrc ifconfig_vtnet1="inet ${NETWORK}.4 netmask 255.255.255.0"
      sysrc defaultrouter="${GATEWAY}"
      sysrc gateway_enable="YES"
      sed -i ".orig" -e "s|files mdns dns|files mdns_minimal [NOTFOUND=return] dns mdns|g" /etc/nsswitch.conf
      sysctl -w security.jail.allow_raw_sockets=1
      echo "security.jail.allow_raw_sockets=1" >> /etc/sysctl.conf
      service netif restart && service routing restart
      echo "checking DNS resolution with ping"
      ping -c 1 google.com || true
      sysrc clear_tmp_enable="YES"
    SHELL
    node.vm.provision 'ansible' do |ansible|
    ansible.compatibility_mode = '2.0'
    ansible.limit = 'all'
    ansible.playbook = 'site.yml'
    ansible.become = true
    ansible.verbose = ''
    ansible.config_file = 'ansible.cfg'
    ansible.raw_ssh_args = "-o ControlMaster=no -o IdentitiesOnly=yes -o ConnectionAttempts=20 -o ConnectTimeout=60 -o ServerAliveInterval=20"
    ansible.raw_arguments = [ "--timeout=1000" ]
    ansible.groups = {
      "all" => [ "ldap1", "ldap2" ],
        "all:vars" => {
        "ansible_python_interpreter" => "/usr/local/bin/python"
      },
    }
    end
  end
end
EOV

step "Create potman.ini"
cat >potman.ini<<EOP
[sampler]
name="${SAMPLER_NAME}"
vm_manager="vagrant"
freebsd_version="${FREEBSD_VERSION}"
network="${NETWORK}"
gateway="${GATEWAY}"
EOP

step "Creating ansible.cfg"
cat >ansible.cfg<<EOCFG
[defaults]
host_key_checking = False
timeout = 30
log_path = ansible.log
[ssh_connection]
retries=10
scp_if_ssh = True
EOCFG


step "Create gitignore file"
cat >.gitignore<<EOG
*~
.vagrant
_build
ansible.tgz
ansible.log
ansible.cfg
pubkey.asc
secret.asc
id_rsa
id_rsa.pub
myhostkey
myhostkey.pub
EOG

step "Success"

echo "Created sampler ${SAMPLER_NAME}"
