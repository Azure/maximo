#!/usr/bin/env python3

import json
import base64
import sys
import os
import glob
from dotmap import DotMap
import yaml
from collections import OrderedDict

resource_group = sys.argv[1]
infra_id = sys.argv[2]

with open('openshift/99_cloud-creds-secret.yaml') as crfile:
    yamls = yaml.load(crfile, Loader=yaml.BaseLoader)
    crfile.close()
    yamls['data']['azure_resource_prefix'] = base64.b64encode(bytes(infra_id, 'utf-8')).decode('utf-8')
    yamls['data']['azure_resourcegroup'] = base64.b64encode(bytes(resource_group, 'utf-8')).decode('utf-8')
    with open('openshift/99_cloud-creds-secret.yaml', 'w') as crout:
        yaml.dump(yamls, crout, default_flow_style=False)
        crout.close()

with open('manifests/cloud-provider-config.yaml') as file:
    yamlx = yaml.load(file, Loader=yaml.BaseLoader)
    file.close()
    jsondata = yamlx['data']['config']
    jsonx = json.loads(jsondata, object_pairs_hook=OrderedDict)
    config = DotMap(jsonx)
    config.resourceGroup = resource_group
    config.vnetName = "airgap-vnet"
    config.vnetResourceGroup = "airgap-maximo"
    config.subnetName = "workers"
    config.securityGroupName = "airgap-vnet-nsg"
    config.routeTableName = ""
    config.cloudProviderRateLimit = False
    config.azure_resourcegroup = resource_group
    jsondata = json.dumps(dict(**config.toDict()), indent='\t')
    jsonstr = str(jsondata)
    yamlx['data']['config'] = jsonstr + '\n'
    yamlx['metadata']['creationTimestamp'] = None
    yamlstr = yaml.dump(yamlx, default_style='\"', width=4096)
    yamlstr = yamlstr.replace('!!null "null"', 'null')
    with open('manifests/cloud-provider-config.yaml', 'w') as outfile:
        outfile.write(yamlstr)
        outfile.close()

with open('manifests/cluster-infrastructure-02-config.yml') as file:
    yamlx = yaml.load(file, Loader=yaml.BaseLoader)
    file.close()
    yamlx['status']['platformStatus']['azure']['resourceGroupName'] = resource_group
    yamlx['status']['platformStatus']['azure']['networkResourceGroupName'] = "airgap-maximo"
    yamlx['status']['platformStatus']['azure']['virtualNetwork'] = "airgap-vnet"
    yamlx['status']['platformStatus']['azure']['controlPlaneSubnet'] = "control"
    yamlx['status']['platformStatus']['azure']['computeSubnet'] = "workers"
    yamlx['status']['infrastructureName'] = infra_id
    yamlx['metadata']['creationTimestamp'] = None
    with open('manifests/cluster-infrastructure-02-config.yml', 'w') as outfile:
        yaml.dump(yamlx, outfile, default_flow_style=False)
        outfile.close()