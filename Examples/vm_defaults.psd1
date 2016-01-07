@{
    ensure = 'present'
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
        ipAssignment = 'DHCP'
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
    secrets = @{
        vCenter = @{
            resolver = 'pscredential'
            options = @{
                username = '<your vcenter username>'
                password = '<your password here>'
            }
        }
        guest = @{
            resolver = 'pscredential'
            options = @{
                username = 'administrator'
                password = '<your password here>'
            }
        }
        domainJoin = @{
            resolver = 'pscredential'
            options = @{
                username = 'administrator'
                password = '<your password here>'
            }
        }
    }
    provisioners = @(
        @{
            name = 'DomainJoin'
            options = @{
               domain = 'mydomain.com'
               oupath = 'ou=servers, dc=mydomain, dc=com'
           }
        }
    )
}