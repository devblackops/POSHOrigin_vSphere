function _FormatGuestDisk {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $disk,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $session,

        [ValidateSet('GPT', 'MBR')]
        [string]$PartitionStyle = 'GPT',

        [Parameter(Mandatory)]
        [string]$VolumeName,

        [string]$VolumeLabel = [string]::empty,

        [ValidateSet(4096, 8192, 16386, 32768, 65536)]
        [int]$AllocationUnitSize = 4096
    )

    Write-Debug -Message ($disk | fl * | Out-String)
    Write-Debug -Message "Looking at disk $($disk.Number)"

    # Online the disk
    if ($disk.IsOffline -eq $true) {
        Write-Verbose -Message "Onlining disk [$($disk.Number)]"
        Invoke-Command -Session $session -ScriptBlock { $args[0] | Set-Disk -IsOffline $false } -ArgumentList $disk -Verbose:$false
    } else {
        Write-Debug -Message "Disk $($disk.Number) is already online"
    }

    if ($disk.PartitionStyle -eq 0) {
        $cmd = {
            Write-Verbose -Message "Initializing disk [$($args[0])] with $PartitionStyle"
            $d = $args[0] | Initialize-Disk -PartitionStyle $PartitionStyle -Verbose:$false -PassThru

            Write-Verbose -Message "Creating partition [$($args[1])] on disk [$($disk.Number)]"
            $p = New-Partition -DriveLetter $args[1] -UseMaximumSize -Verbose:$false

            Write-Verbose -Message "Formating volume [$($args[2])] on disk [$($args[0])] with allocation unit size [$($args[3])]"
            $p | Format-Volume -FileSystem NTFS -NewFileSystemLabel $args[2] -AllocationUnitSize $args[3] -Force -Verbose:$false -Confirm:$false | Out-Null
        }
        Invoke-Command -Session $session -ScriptBlock $cmd -ArgumentList @($disk, $VolumeName, $VolumeName, $AllocationUnitSize )
    } else {
        $partition = Invoke-Command -Session $session -ScriptBlock { @($args[0] | Get-Partition | Where-Object {$_.Type -ne 'Reserved' -and $_.IsSystem -eq $false}) } -ArgumentList $disk
        if ($partition.Count -eq 0) {
            $cmd = {
                Write-Verbose -Message "Creating partition [$($args[1])] on disk [$($args[0])]"
                $p = $args[0] | New-Partition -DriveLetter $args[1] -UseMaximumSize

                Write-Verbose -Message "Formating volume [$($args[1])] on disk [$($args[0])] with allocation unit size [$($args[3])]"
                $p | Format-Volume -FileSystem NTFS -NewFileSystemLabel $args[2] -AllocationUnitSize $args[3] -Force -Verbose:$false -Confirm:$false | Out-Null
            }
            Invoke-Command -Session $session -ScriptBlock $cmd -ArgumentList @($disk, $config.VolumeName, $config.VolumeLabel, $config.BlockSize) -Verbose:$false 
        }
    }
}