function _SetTags {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $vm,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Tags
    )
    
    $desiredTags = $Tags | ConvertFrom-Json
    $tagAssignments = $vm | Get-TagAssignment -Verbose:$false
    $tagCategories = Get-TagCategory -Verbose:$false
    $vCenterTags = $tagCategories | Get-Tag -Verbose:$false 
    
    # Verify that each desired tag in configuration is applied in vCenter
    # Apply if necessary
    foreach ($desiredTag in $desiredTags) {
        $match = $tagAssignments | Where-Object {($_.Tag.Category.Name -eq $desiredTag.Category) -and ($_.Tag.Name -eq $desiredTag.Name)}
        if (-not $match) {
            
            # Validate the desired tag category is valid in vCenter
            $tagCategory = $tagCategories | where Name -eq $desiredTag.Category                
            if ($tagCategory) {
                # Do we already have a tag for this?
                $tag = $vCenterTags | Where-Object {$_.Name -eq $desiredTag.Name -and $_.Category.Name -eq $desiredTag.Category}
                if ($null -eq $tag) {
                    # Create tag
                    $tag = New-Tag -Name $desiredTag.Name -Category $tagCategory -Verbose:$false
                }
                Write-Verbose -Message "Assigning tag [$($desiredTag.Category)/$($desiredTag.Name)]"
                $vm | New-TagAssignment -Tag $tag -Verbose:$false 
            } else {
                Write-Error -Message "Unable to find tag category [$($desiredTag.Category)] in vCenter"
            }
        }
    }
    
    # Remove any tag assignments in vCenter that are NOT in the desired tag list
    foreach ($tagAssignment in $tagAssignments) {
        $match = $desiredTags | Where-Object {($_.Category -eq $tagAssistnment.Tag.Category.Name) -and ($_.Name -eq $tagAssistnment.Tag.Name)}
        if (-not $match ) {
            # Remove tag assignment in vCenter
            Write-Verbose -Message "Remove tag [$($tagAssignment.Tag.Category.Name)/]"
            $tagAssignment | Remove-TagAssignment -Verbose:$false
        }
    }
}