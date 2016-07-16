resource 'vsphere:vm' 'VM01' @{
    ensure = 'present'
    description = 'Test VM'
    vCenter = 'vcenter01.local'
    datacenter = 'datacenter01'
    cluster = 'cluster01'
    vmTemplate = 'W2K12_R2_Std'
    customizationSpec = 'W2K12_R2'
    powerOnAfterCreation = $true
    totalvCPU = 2
    coresPerSocket = 1
    vRAM = 4
    initialDatastore = 'datastore01'
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
    Provisioners = @(
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
                    'myapp.prop1' = 42
                    'myapp.prop2' = 'something'
                }
            }
        }
    )
}