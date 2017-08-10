function _FormatGuestDisk {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $disk,

        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$PSSession,

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
    
    try {
        # Online the disk
        if ($disk.IsOffline -eq $true) {
            Write-Verbose -Message "Onlining disk [$($disk.Number)]"
            $onlineDiskParams = @{
                Session = $PSSession
                ArgumentList = $disk
                Verbose = $false
                ScriptBlock = {
                    $args[0] | Set-Disk -IsOffline $false
                    $d = ($args[0] | Get-Disk)
                    if ($d.IsOffline) {
                        $d | Set-Disk -IsReadOnly $false
                    }
                    return ($args[0] | Get-Disk)
                }
            }
            $disk = Invoke-Command @onlineDiskParams
        } else {
            Write-Debug -Message "Disk $($disk.Number) is already online"
        }

        if ($disk.PartitionStyle -eq 0) {

            # Format the disk
            $formatParams = @{
                Session = $PSSession
                ArgumentList = @($disk, $VolumeName, $VolumeName, $AllocationUnitSize, $PartitionStyle )
                ScriptBlock = {
                    $verbosePreference = $using:VerbosePreference

                    # Initialize disk
                    Write-Verbose -Message "Initializing disk [$($args[0].Number)] with [$($args[4])]"
                    $d = $args[0] | Initialize-Disk -PartitionStyle $args[4] -Verbose:$false -PassThru

                    # Create partition
                    Write-Verbose -Message "Creating partition [$($args[1])] on disk [$($d.Number)]"
                    $p = $d | New-Partition -DriveLetter $args[1] -UseMaximumSize -Verbose:$false

                    # Format the volume
                    Write-Verbose -Message "Formating volume [$($args[2])] on disk [$($args[0].Number)] with allocation unit size [$($args[3])]"
                    $fv = @{
                        FileSystem = 'NTFS'
                        NewFileSystemLabel = $args[2]
                        AllocationUnitSize = $args[3]
                        Force = $true
                        Verbose = $false
                        Confirm = $false
                    }
                    $p | Format-Volume @fv | Out-Null
                }
            }
            Invoke-Command @formatParams
        } else {

            # Get partitions
            $getPartitionParams = @{
                Session = $PSSession
                ArgumentList = $disk
                ScriptBlock = { 
                    @($args[0] | Get-Partition | Where-Object {$_.Type -ne 'Reserved' -and $_.IsSystem -eq $false})
                }
            }
            $partition = Invoke-Command @getPartitionParams

            # Format partition
            if ($partition.Count -eq 0) {
                $formatParams = @{
                    Session = $PSSession
                    ArgumentList = @($disk, $config.VolumeName, $config.VolumeLabel, $config.BlockSize)
                    Verbose = $false 
                    ScriptBlock = {
                        $verbosePreference = $using:VerbosePreference

                        # Set disk to read/write
                        Write-Verbose -Message "Setting disk [$($args[0].Number)] to read/write"
                        $args[0] | Set-Disk -IsReadOnly $false

                        # Create partition
                        Write-Verbose -Message "Creating partition [$($args[1])] on disk [$($args[0].Number)]"
                        $p = $args[0] | New-Partition -DriveLetter $args[1] -UseMaximumSize

                        # Format volume
                        Write-Verbose -Message "Formating volume [$($args[1])] on disk [$($args[0].Number)] with allocation unit size [$($args[3])]"
                        $fv = @{
                            FileSystem = 'NTFS'
                            NewFileSystemLabel = $args[2]
                            AllocationUnitSize = $args[3]
                            Force = $true
                            Verbose = $false
                            Confirm = $false
                        }
                        $p | Format-Volume @fv | Out-Null
                    }
                }
                Invoke-Command @formatParams
            }
        }
    } catch {
        Write-Error -Message 'There was a problem configuring the guest disks'
        Write-Error -Message "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
        write-Error $_
    }
}
