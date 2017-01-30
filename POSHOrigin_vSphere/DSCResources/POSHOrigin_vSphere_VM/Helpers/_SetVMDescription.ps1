
function _SetVMDescription {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Description
    )

    Write-Verbose -Message "Setting description to [$Description]"
    $VM | Set-VM -Notes $Description -Verbose:$false -Debug:$false
}
