import panos
import json
import subprocess
import logging
import sys

from panos.firewall import Firewall
from panos.network import ManagementProfile, Zone, EthernetInterface, VirtualRouter, StaticRoute
from panos.policies import Rulebase, SecurityRule, NatRule

##################################################
#							Define functions									#
#################################################

def get_terraform_outputs():
    try:
        command = ["terraform", "output", "-json"]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            encoding='utf-8'
        )

        outputs = json.loads(result.stdout)
        return outputs

    except FileNotFoundError:
        print("Error: 'terraform' command not found. Is Terraform installed and in your PATH?")
        return None
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform out: {e.stderr}")
        return None
    except json.JSONDecodeError:
        print("Error: Could not decode JSON from terraform output.")
        return None

def get_first_host(cidr_block):
    untrust_cidr = untrust_subnet_cidr.split('/')[0]
    parts = untrust_cidr.split('.')
    parts[-1] = '1'
    return ".".join(parts)

def change_admin_pass():
		try:
				result = subprocess.run(['bash', pass_script], check=True, stdout=subprocess.DEVNULL)
				print("\nChanging admin password on the firewall.")
				print(f"Bash script return code: {result.returncode}")

		except FileNotFoundError:
				print(f"Error: The script at '{pass_script}' was not found.")
		except FileNotFoundError:
				print(f"Error: The script at '{pass_script}' was not found.")
		except subprocess.CalledProcessError as e:
				print(f"Error: The script failed with return code {e.returncode}")
		except Exception as e:
				print(f"An unexpected error occurred: {e}")

###################################################
#							Define variables									 #
##################################################

# Get Terraform outputs from the statefile and assign them to variables
terraform_outputs = get_terraform_outputs()
vmseries_mgmt_ip = terraform_outputs['vmseries_mgmt_public_ip']['value']
untrust_subnet_cidr = terraform_outputs['untrust_subnet_cidr']["value"]
vmseries_untrust_private_ip = terraform_outputs['vmseries_untrust_private_ip']["value"]
ubuntu_private_ip = terraform_outputs['ubuntu_tester_private_ip']["value"]
untrust_gateway = get_first_host(untrust_subnet_cidr)
admin_pass = terraform_outputs['admin_password']['value']

# Define the admin password update shell script
pass_script = "./admin_pass.sh"

# Instantiate the firewall object
fw = Firewall(f'{vmseries_mgmt_ip}', 'admin', f'{admin_pass}')

# Instantiate the rulebase object
rulebase = Rulebase()

# Build the config
allow_ping = ManagementProfile(
            name = 'allow-ping',
            ping = True
        )

untrust_zone = Zone(
            name = 'untrust',
            mode = 'layer3',
            interface = ['ethernet1/1']
        )

trust_zone = Zone(
            name = 'trust',
            mode = 'layer3',
            interface = ['ethernet1/2']
        )

eth1 = EthernetInterface(
            name = 'ethernet1/1',
            mode = 'layer3',
            management_profile = allow_ping,
            enable_dhcp = True,
            create_dhcp_default_route = True,
        )

eth2 = EthernetInterface(
            name = 'ethernet1/2',
            mode = 'layer3',
            management_profile = allow_ping,
            enable_dhcp = True,
            create_dhcp_default_route = False
        )

vr = VirtualRouter(
						name = 'default',
						interface = ['ethernet1/1', 'ethernet1/2']
				)

default_route = StaticRoute(
            name = 'default-out',
            destination = '0.0.0.0/0',
            nexthop_type = 'ip-address',
            nexthop = untrust_gateway,
            interface = 'ethernet1/1'
        )

nat2ubuntu = NatRule(
            name = 'NAT2Ubuntu',
            nat_type = 'ipv4',
            fromzone = ['untrust'],
            tozone = ['untrust'],
            destination = [vmseries_untrust_private_ip],
            destination_translated_address = ubuntu_private_ip
        )

nat2external = NatRule(
            name = 'NAT2External',
            nat_type = 'ipv4',
            fromzone = ['trust'],
            tozone = ['untrust'],
            source_translation_type = 'dynamic-ip-and-port',
            source_translation_address_type = 'translated-address',
            source_translation_translated_addresses = [vmseries_untrust_private_ip]
        )

mgmt_rule = SecurityRule( 
            name = 'AllowManagement',
            fromzone = ['untrust'],
            tozone = ['trust'],
            destination = [vmseries_untrust_private_ip],
            application = ['ping','ssh'],
            action = 'allow',
            log_start = False,
            log_end = True
        )

web_rule = SecurityRule(
            name = 'AllowExternal',
            fromzone = ['trust'],
            tozone = ['untrust'],
            destination = ['any'],
            application = ['any'],
            action = 'allow',
            log_start = False,
            log_end = True,
            virus = 'default',
            spyware = 'default',
            vulnerability = 'default'
        )

##################################################
#               Execute the config               #
#               TODO: Add validation logic       #
##################################################

# Login to the firewall and change the admin password
change_admin_pass()

# Add child objects to their parents
vr.add(default_route)
rulebase.add(nat2ubuntu)
rulebase.add(nat2external)
rulebase.add(mgmt_rule)
rulebase.add(web_rule)


# Add all top-level objects to the firewall object
fw.add(allow_ping)
fw.add(untrust_zone)
fw.add(trust_zone)
fw.add(eth1)
fw.add(eth2)
fw.add(vr)
fw.add(rulebase)

# Create the objects and push them to the firewall
allow_ping.create()
eth1.create()
eth2.create()
untrust_zone.create()
trust_zone.create()
vr.create()
rulebase.create()

# Commit all staged changes at once
print("Sending configuration to the firewall...")
fw.commit(sync=True)

print("Commit successful! The new configuration is now active.")
