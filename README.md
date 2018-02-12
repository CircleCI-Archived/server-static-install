# Static Installer

## Pre-Requisites

### Services VM

- Running Ubuntu 14.04
- Minimum 32 GB RAM
- Minimum 4 CPU (8 preferred)
- Can route to Nomad Client on ports:
    - 
- Can be routed to by developers on ports:
    - 443
    - 80
    - 7171
    - 8081
- Can be routed to by admins on ports:
    - 22
    - 8800

### (n) Nomad Client VMs

- Running Ubuntu 14.04
- Minimum 4 CPU
- Minimum 8 GB RAM
- Access to any docker registries that are required
- Can route to Services VM on Ports:
    - 4647
    - 8585
    - 7171
    - 3001
- Can be routed to by developers (for sshing into builds):
    - 64535-65535

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
