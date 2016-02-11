# Taken with love from http://www.lucd.info/2012/05/18/folder-by-path/
# with a few minor modifications

function _GetVMFolderByPath{
    <#
    .SYNOPSIS  Retrieve folders by giving a path
    .DESCRIPTION The function will retrieve a folder by it's
        path. The path can contain any type of leave (folder or datacenter).
    .NOTES  Author:  Luc Dekens
    .PARAMETER Path
        The path to the folder.
        This is a required parameter.
    .EXAMPLE
        PS> Get-FolderByPath -Path 'Folder1/Datacenter/Folder2'
    #> 
    param(
        [CmdletBinding()]
        [parameter(Mandatory)]
        [System.String[]]$Path
    )

    process{
        if ((Get-PowerCLIConfiguration).DefaultVIServerMode -eq 'Multiple') {
            $vcs = $defaultVIServers
        } else{
            $vcs = $defaultVIServers[0]
        }

        foreach($vc in $vcs) {
            foreach($strPath in $Path) {
                # Normalize slashes and strip out any leading or training '/' 
                $strPath = $strPath.Replace('\','/').Trim('/')

                $root = Get-Folder -Name Datacenters -Server $vc -Verbose:$false
                $strPath.Split('/') | Foreach-Object {
                    $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion -Verbose:$false
                    if ((Get-Inventory -Location $root -NoRecursion -Verbose:$false | Select -ExpandProperty Name) -contains "vm"){
                        $root = Get-Inventory -Name 'vm' -Location $root -Server $vc -NoRecursion -Verbose:$false
                    }
                }
                $root | Where-Object {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]} | Foreach-Object {
                    Get-Folder -Name $_.Name -Location $root.Parent -Server $vc -Verbose:$false
                }
            }
        }
    }
}
