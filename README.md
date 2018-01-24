# Static Installer

## Pre-Requisites

### Services VM

- Running Ubuntu 14.04
- Minimum 32 GB RAM
- Minimum 8 CPU

### (n) Nomad Client VMs

- Running Ubuntu 14.04
- Minimum 4 CPU
- Minimum 8 GB RAM
- Can route to Services VM on Ports:
    - 4000-600
- Can be routed to by developers (for sshing into builds):
    - ...

## Usage

### Services

- Copy init script
- sudo su
- run init script
- navigate to the public ip of the host on port 8800 (https)

### Nomad Client

- Copy init script
- sudo su
- run init script with env var NOMAD_SERVER_ADDRESS set to the routable ip of the services box
