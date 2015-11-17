#Requires -Version 5.0

enum Ensure {
    Absent
    Present
}

# Load any resource specific helper functions
function _TestSomething() {
    return $false
}

[DscResource()]
class vSphere_VM {
    [DscProperty(key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [int]$vRAM

    [DscProperty(NotConfigurable)]
    [datetime]$CreationTime

    [void]Set() {
        Write-Verbose -Message "************** Doing something with $($this.Name)"
    }

    [bool]Test() {
        if (_TestSomething) {
            return $true
        } else {
            return $false
        }
    }

    [vSphere_VM]Get() {
        $obj = [vSphere_VM]::new()
        $obj.Name = $this.Name
        $obj.vRAM = $this.vRAM
        $obj.CreationTime = Get-Date
        return $obj
    }
}

# Load all DSC resources
###### Loading class based resources this way doesn't appear to work ######
# https://connect.microsoft.com/PowerShell/feedback/details/1191366/authoring-dsc-resources-doesnt-work-in-nested-ps1-files
#$thisFolder = Split-Path -Path $PSCommandPath -Parent
#"$thisFolder\Resources\*.ps1" |
#    Resolve-Path |
#    ForEach-Object { Invoke-Expression $_.ProviderPath }