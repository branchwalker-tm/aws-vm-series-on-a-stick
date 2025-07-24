# AWS VM-Series On-a-Stick

A Terraform set that deploys a VM-Series Firewall in AWS with an Ubuntu EC2 instance behind it. A Python script that configures the firewall to allow SSH traffic to and from the Ubuntu intance.

## Python Version
`pan-os-python` has a dependency on `disutils` which was deprecated in Python 3.12, so you'll need to use Python 3.11 in the meantime. Use `pyenv` or something similar to accomodate this:

1. ```echo -e ''if command -v pyenv 1>/dev/null 2>&1; then eval "$(pyenv init -)"\nfi' >>> ~/.bash_profile```
2. Restart your terminal
3. ```pyenv local 3.11.9```
4.```python -m venv venv```
5.```source venv/bin/activate```
6.```pip install pan-os-python```

## Other requirements
Ensure you have the following installed on your machine:
* AWS CLI
* Terraform

Additionally, you'll want to makesure you've got your `aws_ssh_keypair.pem` located in the root of your working directory

## How to use
From the working directory, run `terraform init`, `terraform plan` and `terraform apply --auto-approve`
Once the environment has been built, simply run `python panos-config.py` and the golden config will be built, pushed to the firewall, and committed
After the commit, you can access the Ubuntu machine by running: `ssh -i <aws_ssh_keypair.pem> ubuntu@<untrust_public_ip>` and you are good to go

