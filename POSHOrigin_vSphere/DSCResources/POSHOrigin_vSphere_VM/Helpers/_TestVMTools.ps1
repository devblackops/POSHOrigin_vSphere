function _TestVMTools {
    [cmdletbinding()]
    param(
        $VM
    )
    
    # Possible values indicating tools need to be installed/updated
    $old = @('guestToolsNeedUpgrade', 'guestToolsNotInstalled')
    
    if ($VM.ExtensionData.Guest.ToolsVersionStatus -notin $old) {
        return $true
    } else {
        return $false
    }
}