#enum Ensure {
#    Absent
#    Present
#}

#Write-Host 'Running'

# Load any resource specific helper functions
#function _TestSomething() {
#    return $false
#}

#[DscResource()]
#class vSphere_VM {
#    [DscProperty(key)]
#    [string]$Name

#    [DscProperty(Mandatory)]
#    [Ensure]$Ensure = [Ensure]::Present

#    [DscProperty(Mandatory)]
#    [string]$vRAM

#    [DscProperty(NotConfigurable)]
#    [datetime]$CreationTime

#    [void]Set() {
#        Write-Verbose -Message "************** Doing something with $($this.Name)"
#    }

#    [bool]Test() {
#        if (_TestSomething) {
#            return $true
#        } else {
#            return $false
#        }
#    }

#    [vSphere_VM]Get() {
#        $obj = [vSphere_VM]::new()
#        $obj.Name = $this.Name
#        $obj.vRAM = $this.vRAM
#        $obj.CreationTime = Get-Date
#        return $obj
#    }
#}