function _TestVMPowerState {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [bool]$PowerOnAfterCreation
    )

    switch ($PowerOnAfterCreation) {
        $true {
            return ($PowerOnAfterCreation -and ($vm.PowerState -eq 'PoweredOn'))
        }
        $false {
            return (($PowerOnAfterCreation -eq $false) -and ($vm.PowerState -ne 'PoweredOn'))
        }
    }
}