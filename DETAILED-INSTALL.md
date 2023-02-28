# Detailed Installation

## FreeBSD

### Did you upgrade from 13.0 to 13.1?
Please see the [ERRATA](ERRATA.md) file for info on fixing a broken upgrade.

### Install for FreeBSD
Install packages, start services and configure permissions and networks
```
pkg install bash git packer py39-ansible py39-packaging vagrant virtualbox-ose
service vboxnet enable
    
(sudo) pw groupmod vboxusers -m <username>

mkdir -p /usr/local/etc/vbox
vi /usr/local/etc/vbox/networks.conf
```

(add, with asterisk; this is extremely broad)
```
* 0.0.0.0/0
```

Symlink to expected file ([may be fixed in future](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=266845#c2))
```
mkdir -p /etc/vbox
ln -s /usr/local/etc/vbox/networks.conf /etc/vbox/networks.conf
```

Add to /etc/rc.conf because the host needs to be a router for private networks in Virtualbox to get internet access
```
gateway_enable="YES"
```

Restart networking (may pause ssh session for a bit)
```
sudo service netif restart && sudo service routing restart
```

Start virtualbox networking
```
service vboxnet start
```

edit .profile, add the following, adjusting for username
```
PATH=/home/<username>/openldap-matrix-sampler/bin:$PATH; export PATH
```

Download and configure openldap-matrix-sampler:
```
git clone https://github.com/hnygd/openldap-matrix-sampler.git
cd openldap-matrix-sampler

  (edit) config.ini and set ACCESSIP to a free IP on LAN

export PATH=$(pwd)/bin:$PATH
(optional: sudo chmod 777 /tmp else packer error)
oms init mysample
cd mysample
oms packbox
oms startvms

  VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 vagrant ssh ldap1
```

## Ubuntu 20.04 with Virtualbox
Install necessary packages
```
sudo apt-get install curl wget -y
sudo apt-get install ruby-full -y   # Ubuntu 20.04 is Ruby 2.7

sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update
sudo apt-get install git -y

sudo apt-get install ansible virtualbox -y

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer vagrant
```

Download and configure openldap-matrix-sampler:
```
git clone https://github.com/hnygd/openldap-matrix-sampler.git
cd openldap-matrix-sampler

  (edit) config.ini and set ACCESSIP to a free IP on LAN

export PATH=$(pwd)/bin:$PATH
oms init mysample
cd mysample
oms packbox
oms startvms

  VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 vagrant ssh ldap1
```

