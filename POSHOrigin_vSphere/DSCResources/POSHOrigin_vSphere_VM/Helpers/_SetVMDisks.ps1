function _SetVMDisks {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DiskSpec
    )

    $configDisks = ConvertFrom-Json -InputObject $DiskSpec -Verbose:$false
    $vmDisks = @($vm | Get-HardDisk -Verbose:$false)
    Write-Debug -Message "Configuration disk count: $($configDisks.Count)"
    Write-Debug -Message "VM disk count: $($vmDisks.Count)"

    $changed = $false
    foreach ($disk in $configDisks) {

        $vmDisk = $vmDisks | Where-Object {$_.Name.ToLower() -eq $disk.Name.ToLower() }

        # Add VM disk
        if ($vmDisk -eq $null) {
            try {
                $datastore = $vm | Get-Datastore -Verbose:$false | Select-Object -first 1
                Write-Verbose -Message "Creating disk [$($disk.Name) - $($disk.SizeGB) GB] on datastore [$($datastore.Name)]"
                $params = @{
                    VM = $vm
                    CapacityGB = $disk.SizeGB
                    DiskType = $disk.Type
                    StorageFormat = $disk.format
                    Datastore = $datastore
                    Verbose = $false
                    Confirm = $false
                    WarningAction = 'SilentlyContinue'
                }
                New-Harddisk @params
                $changed = $true
            } catch {
                Write-Error -Message 'There was a problem creating the disk.'
                Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
                Write-Error -Exception $_
            }
        } else {
            # Resize VM disk
            if ($vmDisk.CapacityGB -lt $disk.SizeGB) {
                Write-Verbose "Resizing disk [$($vmDisk.Name)] to [$($disk.SizeGB)] GB"
                $vmDisk | Set-Harddisk -CapacityGB $disk.SizeGB -Verbose:$false -Confirm:$false
                $changed = $true
            } elseIf ($vmDisks.CapacityGB -gt $disk.SizeGB) {
                Write-Warning -Message "The current disk size [$($vmDisk.CapacityGB) GB] is greater than the desired disk size [$($disk.SizeGB) GB]. Can not shrink VM disks"
            }
        }
    }

    return $changed
}