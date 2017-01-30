
function _TestVMDescription {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $VM,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Description
    )

    if ($VM.Notes -eq $Description) {
        return $true
    } else {
        Write-Verbose -Message "VM description [$($VM.Notes)] <> [$Description]"
        return $false
    }
}
