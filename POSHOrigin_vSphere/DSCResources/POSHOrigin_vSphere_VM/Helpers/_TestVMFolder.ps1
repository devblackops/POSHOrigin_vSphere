function _TestVMFolder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [string]$VMFolder
    )

    $path = _GetVMFolderPath -VM $VM

    # Normalize slashes and strip out any leading or training '/' 
    # so we can compare folder paths accurately
    $path = $path.Replace('\','/').Trim('/')
    $VMFolder = $VMFolder.Replace('\','/').Trim('/')

    if ($path -ne $VMFolder) {
        Write-Verbose -Message "VM folder path [$path] <> [$VMFolder]"
        return $false
    } else {
        return $true
    }
}