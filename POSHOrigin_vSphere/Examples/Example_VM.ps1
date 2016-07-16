$DscConfigData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration Example_VM {
    param(
        [string[]]$NodeName = 'localhost',
        
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$vCenter,
        
        [Parameter(Mandatory)]
        [pscredential]$vCenterCredentials,

        [Parameter(Mandatory)]
        [string]$VMTemplate,

        [Parameter(Mandatory)]
        [string]$CustomizationSpec,

        [Parameter(Mandatory)]
        [int]$TotalvCPU,

        [Parameter(Mandatory)]
        [int]$CoresPerSocket,

        [Parameter(Mandatory)]
        [int]$vRAM,

        [Parameter(Mandatory)]
        [string]$Datacenter,

        [Parameter(Mandatory)]
        [string]$Cluster,

        [Parameter(Mandatory)]
        [string]$InitialDatastore,

        [Parameter(Mandatory)]
        [string]$Networks,

        [bool]$PowerOnAfterCreation = $true,

        [string]$Disks,

        [string]$Provisioners,

        [pscredential]$GuestCredentials,

        [pscredential]$DomainJoinCredentials
    )

    Import-DscResource -Name VM -ModuleName POSHOrigin_vSphere

    Node $NodeName {
        VM "Create$Name" {
            Name = $Name
            Ensure = 'Present'
            vCenter = $vCenter
            vCenterCredentials = $vCenterCredentials
            VMTemplate = $VMTemplate
            CustomizationSpec = $CustomizationSpec
            TotalvCPU = $TotalvCPU
            CoresPerSocket = $CoresPerSocket
            vRAM = $vRAM
            Datacenter = $Datacenter
            Cluster = $Cluster
            InitialDatastore = $InitialDatastore
            Networks = $Networks
            PowerOnAfterCreation = $PowerOnAfterCreation
            Disks = $Disks
            GuestCredentials = $GuestCredentials
            DomainJoinCredentials = $DomainJoinCredentials
            Provisioners = $Provisioners
        }
    }
}

$vCenterCred = Get-Credential
$guestCred = Get-Credential
$domainJoinCred = Get-Credential
$networks = @{
    portGroup = 'VLAN_500'
    ipAssignment = 'Static'
    ipAddress = '192.168.100.100'
    subnetMask = '255.255.255.0'
    defaultGateway = '192.168.100.1'
    dnsServers = @('192.168.50.50','192.168.50.60')
}
$disks = @{
    name = 'Hard disk 1'
    sizeGB = 50
    type = 'flat'
    format = 'Thick'
    volumeName = 'C'
    volumeLabel = 'NOS'
    blockSize = 4096
}
$Provisioners = @(
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
$netJson = $networks | ConvertTo-Json
$diskJson = $disks | ConvertTo-Json
$provJson = $provisioners | ConvertTo-Json

$params = @{
    Name =  'vm01'
    vCenter = 'vcenter01'
    vCenterCredentials = $vCenterCred
    VMTemplate = 'W2K12_R2_Std'
    TotalvCPU = 2
    CoresPerSocket = 1
    vRAM = 4
    Datacenter = 'datacenter01'
    Cluster = 'cluster01'
    CustomizationSpec = 'W2K12_R2'
    InitialDatastore = 'datastore01'
    PowerOnAfterCreation = $true
    Networks = $netJson
    Disks = $diskJson
    Provisioners = $provJson
    GuestCredentials = $guestCred
    DomainJoinCredentials = $domainJoinCred
}
Example_VM -ConfigurationData $DscConfigData @params