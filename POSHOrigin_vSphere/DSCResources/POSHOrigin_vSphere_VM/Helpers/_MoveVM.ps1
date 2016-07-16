function _MoveVM {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [string]$VMFolder
    )

    $folder = _GetVMFolderByPath -Path $VMFolder -ErrorAction SilentlyContinue
    if ($folder) {
        Write-Verbose -Message "Moving VM to destination [$VMFolder]"
        try {
            Move-VM -VM $VM -Destination $folder -Confirm:$false -Verbose:$false
        } catch {
            Write-Error 'There was a problem moving the VM'
            Write-Error "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
            Write-Error $_
        }
    } else {
        Write-Warning -Message "Unable to resolve VM folder [$VMFolder]. VM will not be moved."
    }
}
