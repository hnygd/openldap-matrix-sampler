# FreeBSD

## Hosts which underwent an upgrade from 13.0 to 13.1

On hosts which have upgraded from 13.0 to 13.1, the virtualbox driver gives the following error:
```
VBoxHeadless: Error -1908 in suplibOsInit!
VBoxHeadless: Kernel driver not installed

VBoxHeadless: Tip! Make sure the kernel module is loaded. It may also help to reinstall VirtualBox.
```

With the September quarterlies, and Virtualbox version 6.1.36, you will need to remove the driver and uninstall Virtualbox, then reboot.

```
kldunload vboxdrv
pkg delete -f virtualbox-ose virtualbox-ose-kmod 
```

Now reboot, and log back in as root.

```
pkg install -y virtualbox-ose virtualbox-ose-kmod
kldload vboxdrv
mkdir -p /etc/vbox
mkdir -p /usr/local/etc/vbox
echo "* 0.0.0.0/0" > /usr/local/etc/vbox/networks.conf
ln -s /usr/local/etc/vbox/networks.conf /etc/vbox/networks.conf
service vboxnet restart
```

The `packbox` and `startvms` commands should work fine now.

## Conflicting dependency issues with Vagrant plugins

The plugin `vagrant-disksize` may start to give errors about "Conflicting dependency chains" on a host which upgraded. Attempts to fix by upgrading gems only make the problem worse.

The solution is to install a fresh FreeBSD-13.1 system with quarterlies packages and run through detailed install again. The plugin install works correctly then.

## FreeBSD 13.1 uses /usr/local/etc/vbox

While most `virtualbox` installations make use of `/etc/vbox`, including older FreeBSD versions 12.x, 13.0, from FreeBSD 13.1 `/usr/local/etc/vbox/` is used and `/etc/box/` shouldn't exist.

However if `/etc/vbox` doesn't exist there is an error. You can create the directory and symlink across `/usr/local/etc/vbox/networks.conf`, and you'll still get an error as follows. You can safely ignore it.
```
packer-builder-virtualbox-iso plugin: stderr: WARNING: Directory /etc/vbox found, but ignored. VirtualBox
configuration files are stored in /usr/local/etc/vbox/.
```
## Vagrant gem error

It's possible `vagrant` stops running because `gem` plugins versions are higher than `vagrant` is expecting.

For example you may get the error:
```
/usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1453:in `rescue in block in activate_dependencies': Could not find 'net-sftp' (~> 3.0) among 62 total gem(s) (Gem::MissingSpecError)
Checked in 'GEM_PATH=/home/username/.local/share/gem/ruby/3.0:/usr/local/lib/ruby/gems/3.0' at: /usr/local/lib/ruby/gems/3.0/specifications/vagrant-2.3.2.gemspec, execute `gem env` for more information
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1450:in `block in activate_dependencies'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1439:in `each'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1439:in `activate_dependencies'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1421:in `activate'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:286:in `block in activate_bin_path'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:285:in `synchronize'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:285:in `activate_bin_path'
	from /usr/local/bin/vagrant:25:in `<main>'
```

or this error:
```
/usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1453:in `rescue in block in activate_dependencies': Could not find 'net-scp' (~> 3.0.0) among 62 total gem(s) (Gem::MissingSpecError)
Checked in 'GEM_PATH=/usr/home/username/.local/share/gem/ruby/3.0:/usr/local/lib/ruby/gems/3.0' at: /usr/local/lib/ruby/gems/3.0/specifications/vagrant-2.3.2.gemspec, execute `gem env` for more information
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1450:in `block in activate_dependencies'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1439:in `each'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1439:in `activate_dependencies'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems/specification.rb:1421:in `activate'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:286:in `block in activate_bin_path'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:285:in `synchronize'
	from /usr/local/lib/ruby/site_ruby/3.0/rubygems.rb:285:in `activate_bin_path'
	from /usr/local/bin/vagrant:25:in `<main>'
```

One working solution is to edit `/usr/local/lib/ruby/gems/3.0/specifications/vagrant-2.3.2.gemspec` as follows.

Change
```
    s.add_runtime_dependency(%q<net-sftp>.freeze, ["~> 3.0"])
    s.add_runtime_dependency(%q<net-scp>.freeze, ["~> 3.0.0"])
```

to
```
    s.add_runtime_dependency(%q<net-sftp>.freeze, [">= 3.0"])
    s.add_runtime_dependency(%q<net-scp>.freeze, [">= 3.0.0"])
```

This might not be a good thing, but it gets vagrant working again.