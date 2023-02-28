# Introduction
`openldap-matrix-sampler (aka `rcs`) borrows from [potman](https://github.com/bsdpot/potman), [minio-incinerator](https://github.com/bretton/minio-incinerator/), [minio-sampler](https://github.com/hnygd/minio-sampler), `clusterfurnace` and `cephsmelter` to build a virtualbox and vagrant demonstration host with `consul`, `openldap` and `matrix`.

Do not run in production! 

This is a testing environment to show `consul`, `openldap` and `matrix-synase` running on FreeBSD.

# Outline
This will bring up 1 server:
* myhost1 / ldap1 (8CPU, 8GB)
* myhost2 / ldap2 (4CPU, 4GB) (not actually in use)

This sampler instance will be running:
* FreeBSD base OS
* FreeBSD base pot for layered images
* Consul pot image
* Openldap pot image primary
* Openldap-spare pot image secondary (this would usually be on second host)
* Matrix-synapse pot image

This sampler has provision for two hosts but hasn't been configured for that yet.

A general recommendation is to host pot jails on a server with an internal IP range, behind a firewall & reverse proxy solution, such as OPNSense with HAProxy.

# Requirements
The host computer running `openldap-matrix-sampler needs at least 16 CPU threads, 16GB memory, plus 50GB disk space, preferably high speed SSD. The setup takes an hour or so with packbox step included.

# Overview

## Quickstart
To create your own sampler, init the VMs:

    git clone https://github.com/hnygd/openldap-matrix-sampler.git
    cd openldap-matrix-sampler

      (edit) config.ini and set ACCESSIP to a free IP on LAN

    export PATH=$(pwd)/bin:$PATH
    (optional: sudo chmod 777 /tmp)
    oms init mysample
    cd mysample
    oms packbox
    oms startvms
      vagrant ssh ldap1
      OR
      open http://ACCESSIP
      ...
    ...
    oms status
    ...

## Stopping

    oms stopvms

## Destroying

    oms destroyvms

## Dependencies

`openldap-matrix-sampler requires
- ansible
- bash
- git
- packer
- vagrant
- virtualbox

# Installation and Operation

Please see [Detailed Install FreeBSD & Linux](DETAILED-INSTALL.md)

# Usage

    Usage: oms command [options]

    Commands:
        destroyvms  -- Destroy VMs
        help        -- Show usage
        init        -- Initialize new openldap-matrix-sampler
        packbox     -- Create vm box image
        startvms    -- Start (and provision) VMs
        status      -- Show status
        stopvms     -- Stop VMs

## config.ini

### Access IP

A virtual interface is created with a free IP address from the LAN. You must provide this free IP address in `config.ini` in the `ACCESSIP` section.

## Landing Page

The default index page is `http://ACCESSIP` with links to the tools below.

## Applications

### LDAP Account Manager (LAM)

The LDAP Account manager is available at `http://ACCESSIP:8080` and offers a GUI to complicated LDAP configuration.

### Matrix Synapse

Matrix Synapse is available at `http://ACCESSIP:9090` and should say "it works" if all successful. 

This won't be a fully functioning, federated server, as no SSL is enabled in the sampler environment. You can enable this in your own environment for pot images.
