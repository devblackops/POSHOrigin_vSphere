function _TestTags {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Tags
    )

    $result = $true

    # Get tag information from vCenter
    $desiredTags = $Tags | ConvertFrom-Json
    $tagAssignments = $vm | Get-TagAssignment -Verbose:$false
        
    # Verify that each desired tag in configuration is applied in vCenter
    # Apply if necessary
    foreach ($desiredTag in $desiredTags) {
        $match = $tagAssignments | Where-Object {($_.Tag.Category.Name -eq $desiredTag.Category) -and ($_.Tag.Name -eq $desiredTag.Name)}
        if (-not $match) {
            $result = $false
        }
    }
    
    # Remove any tag assignments in vCenter that are NOT in the desired tag list
    foreach ($tagAssignment in $tagAssignments) {
        $match = $desiredTags | Where-Object {($_.Category -eq $tagAssistnment.Tag.Category.Name) -and ($_.Name -eq $tagAssistnment.Tag.Name)}
        if (-not $match ) {
            $result = $false
        }
    }

    return $result
}