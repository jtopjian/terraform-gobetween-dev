#!/bin/bash
set -x

sudo sed -i -e 's/127.0.0.1 localhost/127.0.0.1 localhost gobetween-tests/' /etc/hosts
sudo add-apt-repository -y ppa:ubuntu-lxc/lxd-git-master
sudo apt-get update -qq
sudo apt-get install -y lxd
#sudo apt-get install -y build-essential pkg-config lxc-dev
sudo apt-get install -y build-essential
sudo lxc config set core.https_address [::]
sudo lxc config set core.trust_password the-password
sudo lxc storage create default dir source=/mnt
sudo lxc profile device add default root disk path=/ pool=default
sudo lxc network create lxdbr0 ipv6.address=none ipv4.address=192.168.244.1/24 ipv4.nat=true
sudo lxc network attach-profile lxdbr0 default eth0
sudo usermod -a -G lxd ubuntu
sudo chown -R ubuntu: /home/ubuntu/.config

lxc launch ubuntu c1 --config user.gobetween.label="web" --config user.gobetween.port=80
lxc launch ubuntu c2 --config user.gobetween.label="web" --config user.gobetween.port=80
lxc exec c1 -- apt-get update -qq
lxc exec c1 -- apt-get install -y apache2
lxc exec c2 -- apt-get update -qq
lxc exec c2 -- apt-get install -y apache2

sudo wget -O /usr/local/bin/gimme https://raw.githubusercontent.com/travis-ci/gimme/master/gimme
sudo chmod +x /usr/local/bin/gimme

cat >> ~/.bashrc <<EOF
eval "\$(/usr/local/bin/gimme 1.8)"
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin
EOF

eval "$(/usr/local/bin/gimme 1.8)"
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

go get github.com/yyyar/gobetween/...

cat > ~/gobetween.toml <<EOF
[logging]
level = "debug"
output = "stdout"

[api]
enabled = true
bind = ":8888"
cors = false

  [api.basic_auth]
  login = "admin"
  password = "1111"

[defaults]
max_connections = 0
client_idle_timeout = "0"
backend_idle_timeout = "0"
backend_connection_timeout = "0"


[servers]
[servers.web_servers]
bind = ":80"
protocol = "tcp"

  [servers.web_servers.discovery]
  kind = "lxd"
  lxd_server_address = "https://gobetween-tests:8443"
  lxd_container_label_key = "user.gobetween.label"
  lxd_container_port_key = "user.gobetween.port"
  lxd_container_label_value = "web"
  lxd_server_remote_password = "the-password"
  lxd_accept_server_cert = true
  lxd_generate_client_certs = true
EOF

exit 0
