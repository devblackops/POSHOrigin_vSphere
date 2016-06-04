[![Build status](https://ci.appveyor.com/api/projects/status/trhenhq5sll9jca1?svg=true)](https://ci.appveyor.com/project/devblackops/poshorigin-vsphere)

# POSHOrigin_vSphere
POSHOrigin_vSphere is a set of PowerShell 5 based DSC resources for managing VMware vSphere objects via DSC.

## Overview
POSHOrigin_vSphere is a set of PowerShell 5 based DSC resources for managing VMware vSphere objects via DSC. These resources are designed to be used 
with [POSHOrigin](https://github.com/devblackops/POSHOrigin) as a Infrastructure as Code framework, but can be used natively by standard DSC 
configurations as well. Integration with [POSHOrigin](https://github.com/devblackops/POSHOrigin) is accomplished via a separate 'Invoke.ps1' script 
included in the module.

## Resources
* **VM** - Manages an virtual machine

### VM

Created, modifies, or deletes a virtual machine

Parameters
----------

| Name                  | Type         | Required | Description
| :---------------------|:-------------|:---------|:-----------|
| Name                  | string       | True     | Name of VM to create
| Ensure                | string       | False    | Denotes if resource should exist or not exist.
| vCenter               | string       | True     | FQDN of the vCenter to connect to
| VMTemplate            | string       | True     | Name of VM template to deploy from
| CustomizationSpec     | string       | True     | Name of customization specification to apply to VM
| TotalvCPU             | int          | True     | Total number of vCPUs
| CoresPerSocket        | int          | True     | Number of Cores per virtual socket
| vRAM                  | int          | True     | Total vRAM in GB
| Datacenter            | string       | True     | Name of virtual datacenter for VM
| Cluster               | string       | False     | Name of cluster to deploy VM into. *[see Deployment locations](#deploymentlocations)*
| ResourcePool          | string       | False    | Name of the resource pool to deploy VM into. *[see Deployment locations](#deploymentlocations)*
| VMHost                | string       | False    | Name of the VM host to deploy the VM onto. *[see Deployment locations](#deploymentlocations)*
| vApp                  | string       | False    | Name of the vApp to deploy the VM into. *[see Deployment locations](#deploymentlocations)*
| VMFolder              | string       | False    | Path of VM folder to place VM in
| Tags                  | string       | False    | JSON string representing an array of hashes for tag categories and tag names
| UpdateTools           | bool         | False    | Indicates if VM tools should be updated / installed on the VM
| InitialDatastore      | string       | True     | Name of datastore or datastore cluster to deploy VM in
| PowerOnAfterCreation  | bool         | False    | Indicates if VM should be powered on after creation. Default is **True**
| IPAMFqdn              | string       | False    | InfoBlox FQDN to allocate IP from
| Disks                 | string       | False    | JSON string of disks to provision on VM [[see Disks](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#disks)]
| Networks              | string       | True     | JSON string of NICs to apply to VM [[see Networks](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#networks)]
| Provisioners          | string       | False    | JSON string of provisioners to apply on VM after deployment [[see provisioners](https://github.com/devblackops/POSHOrigin/wiki/vSphere:VM#provisioners)]
| vCenterCredentials    | pscredential | True     | vCenter credential with rights to manage VMs
| GuestCredentials      | pscredential | False    | Guest credentials for VM
| IPAMCredentials       | pscredential | False    | InfoBlox credentials with rights to allocate IPs
| DomainJoinCredentials | pscredential | False    | Active Directory credentials with rights to join machines to the domain


#### <a name="deploymentlocations"></a>Deployment location options
The options below are valid DSC properties for VM deployment location. 
> **ONLY ONE MAY BE USED PER VM CONFIGURATION**. 
Using more than one option will produce a runtime error.

* Cluster
* ResourcePool
* VMHost
* vApp

###Tags
The tags parameter specified an array of tags to apply to the VM. Parameters expected are below.

A couple of points:

1. The tag categories must already be defined in vCenter. The DSC resource **WILL NOT** create them. This is because the vCenter admin can setup category properties such as multiplicity and scope that they probably don't want the DSC resource to be messing with them.
2. The DSC resource **WILL** create the tags provided the category already exists.
3. The DSC resource will remove the tag associations from the VM when they are not in the DSC configuration but the tags themselves **WILL NOT** be removed because the tags may be assigned to other objects in vCenter.

| Name         | Type    | Required | Description
| :-----------|:--------|:---------|:-----------|
| Category    | string  | True     | The tag category
| Name        | string  | True     | The name of the tag


```powershell
tags = @(
    @{ category = 'Application'; Name = 'My Awesome App' }
    @{ category = 'Environment'; Name = 'Prod' }
    @{ category = 'BU'; Name = 'Engineering' }
    @{ category = 'BU'; Name = 'Sales' }
)
```

###Disks
The disks parameter specifies an array of VM disk configurations for the VM resource. Parameters expected are below. Each disk configuration will result in one hard disk being added to the VM.

| Name        | Type    | Required | Description
| :-----------|:--------|:---------|:-----------|
| Name        | string  | True     | Name of the virtual hard disk. (Hard disk 1, Hard disk 2, etc)
| SizeGB      | int     | True     | Size in GB for the VMDK
| Type        | string  | True     | Type of VM disk to provision. **'flat'** is the only supported option right now.
| Format      | string  | True     | Storage format for the VMDK. Valid options are **'thick'**, **'thin'**, and **'thickeagerzero'**
| VolumeName  | string  | True     | Volume name to give disk inside the guest OS. (**'C'**, **'D'**, etc)
| VolumeLabel | string  | True     | Volume label to give disk inside the guest OS. (**'NOS'**, **'Databases'**, etc)
| BlockSize   | int     | False    | Allocation unit size in **bytes** to format volume inside guest OS. Default value is **4096**

```powerShell
disks = @(
    @{
        name = 'Hard disk 1'
        sizeGB = 50
        type = 'flat'
        format = 'Thick'
        volumeName = 'C'
        volumeLabel = 'NOS'
        blockSize = 4096
    }
    @{
        name = 'Hard disk 2'
        sizeGB = 100
        type = 'flat'
        format = 'Thick'
        volumeName = 'D'
        volumeLabel = 'Databases'
        blockSize = 65536
    }
)
```

###Networks
The networks parameter specifies an array of VM network configurations for the VM resource. Parameters expected are below. Each network configuration will result in one virtual NIC being added to the VM.

| Name           | Type     | Required | Description
| :--------------|:---------|:---------|:-----------|
| PortGroup      | string   | True     | Name of the virtual hard disk. (Hard disk 1, Hard disk 2, etc)
| IPAssignment   | string   | True     | IP assignment method. Valid values are **'Static'**, **'DHCP'**, and **'IPNextAvailable'**
| Network        | string   | False    | InfoBlox network name to request an available IP from. **ONLY VALID WHEN 'IPAssignment' is set to 'IPAMNextAvailable'**
| IPAddress      | string   | False    | IP address for NIC. **ONLY VALID WHEN 'IPAssignment' is set to 'Static'**
| SubnetMask     | string   | False    | Subnet mask for NIC. **ONLY VALID WHEN 'IPAssignment' is set to 'Static'**
| DefaultGateway | string   | False    | Default gateway for NIC. **ONLY VALID WHEN 'IPAssignment' is set to 'Static'**
| DNSServers     | string[] | False     | Array of DNS servers to apply on NIC. **NOT VALID WHEN 'IPAssignment' is set to 'DHCP'**

######Static IP assignment
```powerShell
networks = @{
    portGroup = 'VLAN_500'
    ipAssignment = 'Static'
    ipAddress = '192.168.100.100'
    subnetMask = '255.255.255.0'
    defaultGateway = '192.168.100.1'
    dnsServers = @('192.168.50.50','192.168.50.60')
}
```

######DHCP IP assignment
```powerShell
networks = @{
    portGroup = 'VLAN_500'
    ipAssignment = 'DHCP'
}
```

######Automatic IP from IPAM
```powerShell
networks = @{
    portGroup = 'VLAN_500'
    network = '192.168.100.0/24'
    ipAssignment = 'IPAMNextAvailable'
    dnsServers = @('192.168.50.50','192.168.50.60')
}
```

###Provisioners

Provisioners are tasks that execute on the VM after it has been deployed. These are meant to assist in bootstrapping the VM but are not meant to fully manage the configuration of the guest OS.

**DomainJoin**

Joins the VM to the specific Active Directory domain after provisioning.

| Name   | Type   | Required | Description
| :------|:-------|:---------|:-----------|
| Domain | string | True     | The name of the Active Directory domain to join the computer to
| OUPath | string | True     | The distinguished path to the OU to join the computer to

```powerShell
Provisioners = @(
    @{
       name = 'DomainJoin'
       options = @{
           domain = 'mydomain.com'
           oupath = 'ou=servers, dc=mydomain, dc=com'
       }
    }
)
```

**Chef**

Bootstraps the Chef client on the VM after provisioning. Also registers the Chef client with the specific organization and applies the specified run list, attributes, and environment.

| Name         | Type        | Required | Description
| :------------|:------------|:---------|:-----------|
| NodeName     | string      | True     | Name to assign the node in Chef
| Url          | string      | True     | URL for the Chef organization
| Source       | string      | True     | URL to the Chef client MSI file to install
| ValidatorKey | string      | True     | URL to the Chef validator .pem file that has rights to joins nodes to the organization
| Cert         | string      | True     | URL to the certificate to add to Chef's 'trusted_certs' folder
| RunList      | hashtable[] | False    | Set of recipes or roles to assign to the node
| Environment  | string      | False    | Chef environment to assign the node to
| Attributes   | hashtable   | False    | Hashtable of attributes to assign to the node

```powerShell
Provisioners = @(
    @{
       name = 'Chef'
       options = @{
          nodeName = 'vm01.mydomain.com'
          url = 'https://chefsvr.mydomain.com/organizations/myorg'
          source = '<URL to Chef MSI file>'
          validatorKey = '<URL to organization validator .pem file>'
          cert = '<URL to issuing CA .crt file>'
          runList = @(
             @{ role = 'base::setup_base' }
             @{ recipe = 'myapp::default' }
          )
          environment = 'prod'
          attributes = @{
             myapp = @{
                prop1 = 42
                prop2 = 'something string'
                prop3 = @('item1', 'item2')
             }
          }
       }
    }
)
```


## POSHOrigin Example

This example shows how to use the **VM** resource within the context of a [POSHOrigin](https://github.com/devblackops/POSHOrigin) configuration file.

```PowerShell
resource 'POSHOrigin_vSphere:VM' 'VM01' @{
    ensure = 'present'
    description = 'Test VM'
    vCenter = 'vcenter01.local'
    datacenter = 'datacenter01'
    cluster = 'cluster01'
    vmFolder = 'vdc01/folder01'
    vmTemplate = 'W2K12_R2_Std'
    customizationSpec = 'W2K12_R2'
    powerOnAfterCreation = $true
    totalvCPU = 2
    coresPerSocket = 1
    vRAM = 4
    initialDatastore = 'datastore01'
    updateTools = $true
    tags = @(
        @{ category = 'Application'; Name = 'My Awesome App' }
        @{ category = 'Environment'; Name = 'Prod' }
        @{ category = 'BU'; Name = 'Engineering' }
        @{ category = 'BU'; Name = 'Sales' }
    )
    networks = @{
        portGroup = 'VLAN_500'
        ipAssignment = 'Static'
        ipAddress = '192.168.100.100'
        subnetMask = '255.255.255.0'
        defaultGateway = '192.168.100.1'
        dnsServers = @('192.168.50.50','192.168.50.60')
    }
    disks = @(
        @{
            name = 'Hard disk 1'
            sizeGB = 50
            type = 'flat'
            format = 'Thick'
            volumeName = 'C'
            volumeLabel = 'NOS'
            blockSize = 4096
        }
    )
    vCenterCredentials = Get-POSHOriginSecret 'pscredential' @{
        username = '<your vcenter username>'
        password = '<your password here>'
    }
    guestCredentials = Get-POSHOriginSecret 'pscredential' @{
        username = 'administrator'
        password = '<your password here>'
    }
    domainJoinCredentials = Get-POSHOriginSecret 'pscredential' @{
        username = 'administrator'
        password = '<you password here>'
    }
    provisioners = @(
        @{
            name = 'DomainJoin'
            options = @{
               domain = 'mydomain.com'
               oupath = 'ou=servers, dc=mydomain, dc=com'
           }
        }
        @{
            name = 'Chef'
            options = @{
                nodeName = 'vm01.mydomain.com'
                url = 'https://chefsvr.mydomain.com/organizations/myorg'
                source = '<URL to Chef MSI file>'
                validatorKey = '<URL to organization validator .pem file>'
                cert = '<URL to issuing CA .crt file>'
                runList = @(
                    @{ role = 'base::setup_base' }
                    @{ recipe = 'myapp::default' }
                )
                environment = 'prod'
                attributes = @{
                    myapp = @{
                        prop1 = 42
                        prop2 = 'something string'
                        prop3 = @('item1', 'item2')
                    }
                }
            }
        }
    )
}
```