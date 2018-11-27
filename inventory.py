#!/usr/bin/env python
import argparse
import json
import os
import yaml


parser = argparse.ArgumentParser()
parser.add_argument('--list', action='store_true')
parser.add_argument('--host', action='store')
args = parser.parse_args()


if args.list:
    print(json.dumps({
        "all": {
            "hosts": ['manager'],
        },
    }))

elif args.host:
    volumes = []
    compose_yaml = yaml.load(open('docker-compose.yml', 'r').read())
    for volume, spec in compose_yaml['volumes'].items():
        if spec['external']:
            volume = {
                'name': spec['name']
            }
            volume.update(spec['labels'])
            volumes.append(volume)

    print(json.dumps({
        'ansible_host': os.environ['QA_CLUSTER_IP'],
        'volumes': volumes,
        'ansible_ssh_extra_args': "-o StrictHostKeyChecking=no",
        'ansible_python_interpreter': '/usr/bin/python3',
        'ansible_ssh_private_key_file': 'keys/id_rsa',
    }))
