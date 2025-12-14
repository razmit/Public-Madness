# Function to connect to the requested site and retry if it failed
function Connect-IndicatedSite {
    param (
        [string]$SiteUrl
    )
    
    $failCounter = 1
    $maxRetries = 3
    $connected = $false
    
    do {
        try {
            $SiteUrl = $SiteUrl.TrimStart()
            Write-Host "Connecting to the site... (Attempt $failCounter of $maxRetries)" -ForegroundColor Yellow
            Connect-PnPOnline -Url $SiteUrl -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive
            Write-Host "Connection successful!" -ForegroundColor Green
            $connected = $true
            break # Exit upon success
        }
        catch {
            # Suppress verbose PnP auth errors (they're often transient)
            if ($_.Exception.Message -notlike "*parse near offset*" -and $_.Exception.Message -notlike "*ASCII digit*") {
                Write-Host "Connection attempt $($failCounter+1) failed: $($_.Exception.Message)" -ForegroundColor Red
            } else {
                Write-Host "Connection attempt $($failCounter+1) failed (authentication flow issue - retrying...)" -ForegroundColor Red
            }
            $failCounter++

            if ($failCounter -le $maxRetries) {
                Write-Host "Retrying in 2 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }   
    } while ($failCounter -le $maxRetries -and -not $connected) #Don't exit until all attempts were used and it's NOT connected | $connected = $false
    
    if (-not $connected) {
        Write-Host "All connection attempts failed. Unable to connect to $SiteUrl" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to ensure that the user has not left the input field empty or is malicious
function Test-UserInput {
    param (
        [string]$UserInput
    )
    
    Write-Output "Incoming text to validate: "$UserInput
    # Validate if the input is empty or not
    $UserInput = $UserInput.Trim()
    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        Write-Host -BackgroundColor Red -ForegroundColor White "The name can't be empty. Write something to search."
        
        return $false
    }
    else {
        # Validate that the input is at least 3 characters long
        if ($UserInput.Length -lt 3) {
            Write-Host -BackgroundColor Red -ForegroundColor White "The name to search has to be at least 3 characters long"
            return $false
        }
        else {
            return $true
        }
    }
    
}

function Start-Migration {
    param (
        $ValidGroups,
        $ValidMembers,
        $ValidPermissions,
        $DestinationSite,
        [switch]$DryRun
    )
    
    try {
        if ($DryRun) {
            Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
            Write-Host "║          DRY-RUN MODE - NO CHANGES WILL BE MADE        ║" -ForegroundColor Magenta
            Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta
        }

        $connected = Connect-IndicatedSite -SiteUrl $DestinationSite

        if (-not $connected) {
            throw "Failed to connect to destination site: $DestinationSite"
        }

        $successfulGroups = @()
        $failedGroups = @()
    
        foreach ($group in $ValidGroups) {
            # Write-Host "Title: $($group.Title) | Description: $($group.Description) | Owner: $($group.OwnerTitle)"
            try {

                if ($DryRun) {
                    Write-Host "[DRY-RUN] Would create group: $($group.Title)" -ForegroundColor Yellow
                    Write-Host "  Description: $($group.Description)" -ForegroundColor DarkGray
                    Write-Host "  Owner: $($group.OwnerTitle)" -ForegroundColor DarkGray
                    $newlyCreatedGroup = @{ Title = $group.Title }  # Mock object for dry-run
                } else {
                    # Keep the name of the newly created group
                    $newlyCreatedGroup = New-PnPGroup -Title $group.Title -Description $group.Description -Owner $group.OwnerTitle -ErrorAction Stop

                    # Catch if the group creation returned null
                    if ($null -eq $newlyCreatedGroup) {
                        throw "✗ Group creation returned null for group: $($group.Title)"
                    }

                    Write-Host "✓ Created group: $($group.Title)" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }

                $successfulGroups += $group.Title
                
                # Begin adding the members to the newly created group
                $memberCount = 0
                foreach ($member in $ValidMembers) {
                    foreach ($mem in $member["Members"]) {
                        try {
                            if ($DryRun) {
                                # Don't print individual members - too much output
                                $memberCount++
                            } else {
                                Add-PnPGroupMember -LoginName $mem -Group $newlyCreatedGroup -ErrorAction Stop
                                $memberCount++
                            }
                        }
                        catch {
                            Write-Host "✗ Failed to add member $mem to group $($group.Title). Error: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }

                if ($DryRun) {
                    Write-Host "[DRY-RUN] Would add $memberCount members to group: $($group.Title)" -ForegroundColor Yellow
                } else {
                    Write-Host "✓ Added $memberCount members to group: $($group.Title)" -ForegroundColor Cyan
                }

                Start-Sleep -Seconds 1

                # Begin adding the permissions to the newly created group
                $permCount = 0
                foreach ($perm in $ValidPermissions) {
                    foreach ($per in $perm["Permissions"]) {
                        try {
                            if ($DryRun) {
                                # Don't print individual permissions - too much output
                                $permCount++
                            } else {
                                Set-PnPGroupPermissions -Identity $newlyCreatedGroup -AddRole $per -ErrorAction Stop
                                $permCount++
                            }
                        }
                        catch {
                            Write-Host "✗ Failed to add permission $per to group $($group.Title). Error: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }

                if ($DryRun) {
                    Write-Host "[DRY-RUN] Would add $permCount permissions to group: $($group.Title)" -ForegroundColor Yellow
                } else {
                    Write-Host "✓ Added $permCount permissions to group: $($group.Title)" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "✗ Failed to create group $($group.Title). Error: $($_.Exception.Message)" -ForegroundColor Red
                $failedGroups += @{
                    GroupTitle = $group.Title
                    Error = $_.Exception.Message
                }
            }
        }
    
        # Print out the result
        Write-Host "`n=== Migration Summary ===" -ForegroundColor Cyan
        Write-Host "Successful: $($successfulGroups.Count)" -ForegroundColor Green
        Write-Host "Failed: $($failedGroups.Count)" -ForegroundColor Red
        
        # Print failed groups details - if any
        if ($failedGroups.Count -gt 0) {
            Write-Host "`nFailed Groups:" -ForegroundColor Yellow
            $failedGroups | ForEach-Object { Write-Host "  - $($_.GroupTitle): $($_.Error)" }
        }
        Start-Sleep -Seconds 2
        
        return @{
            Success = $successfulGroups
            Failed = $failedGroups
        }
    }
    catch {
        Write-Host "Critical error in Start-Migration: "$_.Exception.Message -ForegroundColor Red
        throw
    }
}

# Get all members of a group
function Get-GroupMembers {
    param (
        $GroupNames,
        $SourceSiteName
    )
    
    $connected = Connect-IndicatedSite -SiteUrl $SourceSiteName
    $groupsMembers = @()
    
    if (-not $connected) {
        throw "Failed to connect to the source site to get the group members: $SourceSiteName"
    }
    
    if ($null -eq $GroupNames) {
        Write-Host "No groups to get members from. Exiting function." -ForegroundColor Yellow
        throw
    }
    
    foreach ($group in $GroupNames) {
        try {
            $returnedMemberLoginName = Get-PnPGroupMember -Identity $group["Title"].ToString() | Select-Object -Property LoginName -ExpandProperty LoginName | Where-Object { $null -ne $_.LoginName }
        
            if ($null -eq $returnedMemberLoginName) {
                continue
            }
        
            $returnedMembers = @{
                Title   = $group["Title"]
                Members = $returnedMemberLoginName ?? "n/a"
            } 
            $groupsMembers += $returnedMembers
        }
        catch {
            Write-Host "Failed to get members for group: $($group["Title"]). Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    return $groupsMembers
}

# Helper function to transform source paths to destination paths (handles Classic → Modern flattening)
function Convert-SourcePathToDestination {
    param (
        [string]$SourcePath,          # e.g., "/sites/Teams/Audit/NPSG/MAPS/ProjectA"
        [string]$SourceRootUrl,       # e.g., "https://tenant.sharepoint.com/sites/Teams/Audit/NPSG/MAPS"
        [string]$DestinationRootUrl   # e.g., "https://tenant.sharepoint.com/sites/MAPS"
    )

    # Extract ServerRelativeUrl from full URLs if needed
    $sourceRootRelative = if ($SourceRootUrl -match "(https?://[^/]+)(.*)") { $matches[2] } else { $SourceRootUrl }
    $destRootRelative = if ($DestinationRootUrl -match "(https?://[^/]+)(.*)") { $matches[2] } else { $DestinationRootUrl }
    $sourcePathRelative = if ($SourcePath -match "(https?://[^/]+)(.*)") { $matches[2] } else { $SourcePath }

    # Remove trailing slashes for consistent matching
    $sourceRootRelative = $sourceRootRelative.TrimEnd('/')
    $destRootRelative = $destRootRelative.TrimEnd('/')
    $sourcePathRelative = $sourcePathRelative.TrimEnd('/')

    # If the source path IS the source root, return destination root
    if ($sourcePathRelative -eq $sourceRootRelative) {
        return $destRootRelative
    }

    # If the source path starts with the source root, replace it
    if ($sourcePathRelative.StartsWith($sourceRootRelative)) {
        # Get the relative portion after the source root
        $relativePortion = $sourcePathRelative.Substring($sourceRootRelative.Length)

        # Combine with destination root
        $destinationPath = "$destRootRelative$relativePortion"

        return $destinationPath
    }

    # If no match, return original path (shouldn't happen in normal operation)
    Write-Warning "Could not transform path: $SourcePath (source root: $sourceRootRelative)"
    return $sourcePathRelative
}

# Recursive helper function to scan folders and all nested subfolders
function Get-FoldersRecursively {
    param (
        [string]$FolderPath,
        [string]$ListId,
        [string]$ListTitle,
        [int]$Depth = 0
    )

    $foldersWithUniquePerms = @()
    $indent = "  " * ($Depth + 2)

    try {
        # Get all folders in the current folder
        $folders = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderPath -ItemType Folder -ErrorAction Stop

        foreach ($folder in $folders) {
            # Skip system folders at all levels
            if ($folder.Name -notin @("Forms", "_cts", "_w", "Attachments")) {
                try {
                    $folderItem = Get-PnPListItem -List $ListId -Id $folder.ListItemAllFields.Id -Includes HasUniqueRoleAssignments -ErrorAction Stop

                    if ($folderItem.HasUniqueRoleAssignments) {
                        Write-Host "$indent✓ Folder has unique permissions: $($folder.Name)" -ForegroundColor Green

                        $folderPerms = Get-PnPProperty -ClientObject $folderItem -Property RoleAssignments

                        $foldersWithUniquePerms += @{
                            Type = "Folder"
                            Title = $folder.Name
                            Url = $folder.ServerRelativeUrl
                            ListId = $ListId
                            ListTitle = $ListTitle
                            Permissions = $folderPerms
                            Depth = $Depth
                        }
                    }

                    # Recursively scan this folder's subfolders
                    $nestedFolders = Get-FoldersRecursively -FolderPath $folder.ServerRelativeUrl -ListId $ListId -ListTitle $ListTitle -Depth ($Depth + 1)
                    $foldersWithUniquePerms += $nestedFolders
                }
                catch {
                    Write-Host "$indent⚠ Warning: Could not scan folder '$($folder.Name)': $($_.Exception.Message)" -ForegroundColor DarkYellow
                }
            }
        }
    }
    catch {
        # Silently handle folders that can't be enumerated (usually means no subfolders or access issues)
        if ($_.Exception.Message -notlike "*does not exist*" -and $_.Exception.Message -notlike "*Cannot find*") {
            Write-Host "$indent⚠ Warning: Could not enumerate folders in path: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    return $foldersWithUniquePerms
}

# Scan for items with broken inheritance (lists, libraries, folders only - NO FILES)
function Get-ItemsWithBrokenInheritance {
    param (
        [string]$SiteUrl
    )

    Write-Host "`n=== Scanning for broken inheritance ===" -ForegroundColor Cyan
    Write-Host "Site: $SiteUrl" -ForegroundColor DarkCyan

    $itemsWithUniquePerms = @()

    try {
        # Get all lists in the site
        $lists = Get-PnPList | Where-Object {
            $_.Hidden -eq $false -and
            $_.Title -notlike "Limited Access*" -and
            $_.Title -notlike "SharingLinks*"
        }

        Write-Host "Found $($lists.Count) lists/libraries to scan..." -ForegroundColor Yellow

        foreach ($list in $lists) {
            Write-Host "  Scanning: $($list.Title)" -ForegroundColor DarkGray

            # Check if the list itself has unique permissions
            $listItem = Get-PnPList -Identity $list.Id -Includes HasUniqueRoleAssignments

            if ($listItem.HasUniqueRoleAssignments) {
                Write-Host "    ✓ List has unique permissions" -ForegroundColor Green

                # Get role assignments for the list itself
                $permissions = Get-PnPProperty -ClientObject $listItem -Property RoleAssignments

                $itemsWithUniquePerms += @{
                    Type = "List"
                    Title = $list.Title
                    Url = $list.RootFolder.ServerRelativeUrl
                    ListId = $list.Id
                    Permissions = $permissions
                }
            }

            # Scan folders in document libraries (recursively to handle nested folders)
            if ($list.BaseTemplate -eq 101) {  # Document Library
                try {
                    # Use recursive function to scan all folders at all levels
                    $foldersWithPerms = Get-FoldersRecursively -FolderPath $list.RootFolder.ServerRelativeUrl -ListId $list.Id -ListTitle $list.Title -Depth 0
                    $itemsWithUniquePerms += $foldersWithPerms
                }
                catch {
                    Write-Host "    Warning: Could not scan folders in $($list.Title): $($_.Exception.Message)" -ForegroundColor DarkYellow
                }
            }
        }

        Write-Host "`nScan complete! Found $($itemsWithUniquePerms.Count) items with unique permissions." -ForegroundColor Green
        return $itemsWithUniquePerms
    }
    catch {
        Write-Host "Error scanning for broken inheritance: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Apply item-level permissions to destination
function Set-ItemLevelPermissions {
    param (
        $SourceItems,
        [string]$SourceSiteUrl,
        [string]$DestinationSiteUrl,
        [switch]$DryRun
    )

    Write-Host "`n=== Applying Item-Level Permissions ===" -ForegroundColor Cyan

    $successCount = 0
    $failCount = 0
    $skippedCount = 0

    foreach ($item in $SourceItems) {
        try {
            Write-Host "`nProcessing: $($item.Type) - $($item.Title)" -ForegroundColor Yellow
            Write-Host "  URL: $($item.Url)" -ForegroundColor DarkGray

            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would apply permissions to this item" -ForegroundColor Magenta

                # Show what permissions would be applied
                foreach ($perm in $item.Permissions) {
                    $principal = Get-PnPProperty -ClientObject $perm -Property Member
                    $roles = Get-PnPProperty -ClientObject $perm -Property RoleDefinitionBindings

                    Write-Host "    [DRY-RUN] Permission: $($principal.Title) -> $($roles.Name -join ', ')" -ForegroundColor DarkYellow
                }

                $successCount++
            } else {
                # Get the destination item
                if ($item.Type -eq "List") {
                    # Match by Title (more reliable than ID after Sharegate migration)
                    $destList = Get-PnPList | Where-Object { $_.Title -eq $item.Title } | Select-Object -First 1

                    if ($null -eq $destList) {
                        Write-Host "  ✗ List '$($item.Title)' not found in destination" -ForegroundColor Red
                        $skippedCount++
                        continue
                    }

                    # Break inheritance if needed
                    if (-not $destList.HasUniqueRoleAssignments) {
                        Write-Host "  → Breaking inheritance..." -ForegroundColor Cyan
                        Set-PnPList -Identity $destList.Id -BreakRoleInheritance -CopyRoleAssignments
                    }

                    # Apply permissions
                    foreach ($perm in $item.Permissions) {
                        $principal = Get-PnPProperty -ClientObject $perm -Property Member
                        $roles = Get-PnPProperty -ClientObject $perm -Property RoleDefinitionBindings

                        foreach ($role in $roles) {
                            Set-PnPListPermission -Identity $destList.Id -User $principal.LoginName -AddRole $role.Name -ErrorAction Stop
                            Write-Host "    ✓ Applied: $($principal.Title) -> $($role.Name)" -ForegroundColor Green
                        }
                    }

                    $successCount++

                } elseif ($item.Type -eq "Folder") {
                    # Transform source folder URL to destination URL
                    $destFolderUrl = Convert-SourcePathToDestination -SourcePath $item.Url -SourceRootUrl $SourceSiteUrl -DestinationRootUrl $DestinationSiteUrl

                    Write-Host "  Transformed URL: $($item.Url) → $destFolderUrl" -ForegroundColor DarkGray

                    # Get folder in destination using transformed URL
                    $destFolder = Get-PnPFolder -Url $destFolderUrl -ErrorAction SilentlyContinue

                    if ($null -eq $destFolder) {
                        Write-Host "  ✗ Folder not found at destination URL: $destFolderUrl" -ForegroundColor Red
                        $skippedCount++
                        continue
                    }

                    # Get the list item for the folder (match list by Title)
                    $destList = Get-PnPList | Where-Object { $_.Title -eq $item.ListTitle } | Select-Object -First 1
                    $destFolderItem = Get-PnPListItem -List $destList.Id -Id $destFolder.ListItemAllFields.Id

                    # Break inheritance if needed
                    if (-not $destFolderItem.HasUniqueRoleAssignments) {
                        Write-Host "  → Breaking inheritance..." -ForegroundColor Cyan
                        Set-PnPListItemPermission -List $destList.Id -Identity $destFolderItem.Id -BreakRoleInheritance -CopyRoleAssignments
                    }

                    # Apply permissions
                    foreach ($perm in $item.Permissions) {
                        $principal = Get-PnPProperty -ClientObject $perm -Property Member
                        $roles = Get-PnPProperty -ClientObject $perm -Property RoleDefinitionBindings

                        foreach ($role in $roles) {
                            Set-PnPListItemPermission -List $destList.Id -Identity $destFolderItem.Id -User $principal.LoginName -AddRole $role.Name -ErrorAction Stop
                            Write-Host "    ✓ Applied: $($principal.Title) -> $($role.Name)" -ForegroundColor Green
                        }
                    }

                    $successCount++
                }
            }
        }
        catch {
            Write-Host "  ✗ Failed to apply permissions: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n=== Item-Level Permissions Summary ===" -ForegroundColor Cyan
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failCount" -ForegroundColor Red
    Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow

    return @{
        Success = $successCount
        Failed = $failCount
        Skipped = $skippedCount
    }
}

# Recursively get all subsites from a site
function Get-SubSitesRecursively {
    param (
        [string]$SiteUrl
    )

    Write-Host "`n=== Discovering Subsites ===" -ForegroundColor Cyan
    Write-Host "Scanning: $SiteUrl" -ForegroundColor DarkCyan

    $allSubsites = @()

    try {
        # Get immediate subsites
        $subsites = Get-PnPSubWeb

        if ($subsites.Count -gt 0) {
            Write-Host "Found $($subsites.Count) immediate subsites" -ForegroundColor Yellow

            foreach ($subsite in $subsites) {
                $subsiteInfo = @{
                    Title = $subsite.Title
                    Url = $subsite.Url
                    ServerRelativeUrl = $subsite.ServerRelativeUrl
                }
                $allSubsites += $subsiteInfo

                Write-Host "  ✓ Subsite: $($subsite.Title) ($($subsite.Url))" -ForegroundColor Green

                # Recursively get subsites of this subsite
                try {
                    Connect-PnPOnline -Url $subsite.Url -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive -ErrorAction SilentlyContinue
                    $nestedSubsites = Get-SubSitesRecursively -SiteUrl $subsite.Url
                    $allSubsites += $nestedSubsites
                }
                catch {
                    Write-Host "    Warning: Could not scan subsites of $($subsite.Title)" -ForegroundColor DarkYellow
                }
            }
        } else {
            Write-Host "No subsites found." -ForegroundColor DarkGray
        }

        return $allSubsites
    }
    catch {
        Write-Host "Error discovering subsites: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Migrate permissions for a single subsite
function Migrate-SubSitePermissions {
    param (
        [string]$SourceSubSiteUrl,
        [string]$DestinationSubSiteUrl,
        [switch]$DryRun
    )

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          SUBSITE MIGRATION                             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "SOURCE:      $SourceSubSiteUrl" -ForegroundColor Yellow
    Write-Host "DESTINATION: $DestinationSubSiteUrl" -ForegroundColor Yellow

    try {
        # Connect to SOURCE subsite
        Write-Host "`nConnecting to SOURCE subsite..." -ForegroundColor Cyan
        $null = Connect-IndicatedSite -SiteUrl $SourceSubSiteUrl

        # Get SOURCE groups
        $sourceGroups = Get-PnPGroup | Where-Object {
            ($_.Title -notlike "Limited Access System Group*") -and
            ($_.Title -notlike "SharingLinks*")
        }
        Write-Host "✓ Found $($sourceGroups.Count) groups in SOURCE subsite" -ForegroundColor Green

        # Connect to DESTINATION subsite
        Write-Host "Connecting to DESTINATION subsite..." -ForegroundColor Cyan
        $null = Connect-IndicatedSite -SiteUrl $DestinationSubSiteUrl

        # Get DESTINATION groups
        $destinationGroups = Get-PnPGroup | Where-Object {
            ($_.Title -notlike "Limited Access System Group*") -and
            ($_.Title -notlike "SharingLinks*")
        }
        Write-Host "✓ Found $($destinationGroups.Count) groups in DESTINATION subsite" -ForegroundColor Green

        # Compare and migrate
        $groupsToMigrate = Copy-SourceGroupsToDestination -SourceSiteGroups $sourceGroups -DestinationSiteGroups $destinationGroups

        if ($groupsToMigrate.Count -eq 0) {
            Write-Host "No groups to migrate for this subsite." -ForegroundColor Yellow
        } elseif ($groupsToMigrate.Count -ge 1) {
            Write-Host "Migrating $($groupsToMigrate.Count) groups..." -ForegroundColor DarkCyan

            if ($DryRun) {
                New-GroupInDestination -DestinationSiteName $DestinationSubSiteUrl -GroupsToCreate $groupsToMigrate -PassthroughSourceName $SourceSubSiteUrl -DryRun
            } else {
                New-GroupInDestination -DestinationSiteName $DestinationSubSiteUrl -GroupsToCreate $groupsToMigrate -PassthroughSourceName $SourceSubSiteUrl
            }
        }

        # Scan for broken inheritance in subsite
        $scanSubsiteItems = Read-Host "`nScan this subsite for broken inheritance? (Y/N)"

        if ($scanSubsiteItems.ToLower() -eq "y") {
            $null = Connect-IndicatedSite -SiteUrl $SourceSubSiteUrl
            $sourceItemsWithUniquePerms = Get-ItemsWithBrokenInheritance -SiteUrl $SourceSubSiteUrl

            if ($sourceItemsWithUniquePerms.Count -gt 0) {
                Write-Host "Found $($sourceItemsWithUniquePerms.Count) items with broken inheritance" -ForegroundColor Yellow

                $applySubsitePerms = Read-Host "Apply these permissions to DESTINATION subsite? (Y/N)"

                if ($applySubsitePerms.ToLower() -eq "y") {
                    $null = Connect-IndicatedSite -SiteUrl $DestinationSubSiteUrl

                    if ($DryRun) {
                        Set-ItemLevelPermissions -SourceItems $sourceItemsWithUniquePerms -SourceSiteUrl $SourceSubSiteUrl -DestinationSiteUrl $DestinationSubSiteUrl -DryRun
                    } else {
                        Set-ItemLevelPermissions -SourceItems $sourceItemsWithUniquePerms -SourceSiteUrl $SourceSubSiteUrl -DestinationSiteUrl $DestinationSubSiteUrl
                    }
                }
            } else {
                Write-Host "No broken inheritance found in this subsite." -ForegroundColor Green
            }
        }

        Write-Host "`n✓ Subsite migration complete!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error migrating subsite: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Export all permissions to CSV for audit trail
function Export-PermissionsToCSV {
    param (
        [string]$SiteUrl,
        [string]$SiteName,
        [string]$OutputPath = "C:\Users\E095713\Downloads\SiteCollection-Reports\"
    )

    Write-Host "`n=== Exporting Permissions to CSV ===" -ForegroundColor Cyan
    Write-Host "Site: $SiteUrl" -ForegroundColor DarkCyan

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeSiteName = $SiteName -replace '[\\/:*?"<>|]', '_'
    $exportFileName = "$OutputPath\Permissions-$safeSiteName-$timestamp.csv"

    $allPermissions = @()

    try {
        # Export site-level group permissions
        Write-Host "Exporting site-level group permissions..." -ForegroundColor Yellow

        $groups = Get-PnPGroup | Where-Object {
            ($_.Title -notlike "Limited Access System Group*") -and
            ($_.Title -notlike "SharingLinks*")
        }

        foreach ($group in $groups) {
            try {
                # Get group permissions
                $groupPerms = Get-PnPGroupPermissions -Identity $group.Title -ErrorAction SilentlyContinue

                if ($null -ne $groupPerms) {
                    foreach ($perm in $groupPerms) {
                        $allPermissions += [PSCustomObject]@{
                            Type = "Site-Level Group"
                            ItemURL = $SiteUrl
                            GroupGUID = $group.Id
                            GroupName = $group.Title
                            PermissionLevel = $perm.Name
                            Owner = $group.OwnerTitle
                            Description = $group.Description
                        }
                    }
                }
            }
            catch {
                Write-Host "  Warning: Could not export permissions for group $($group.Title)" -ForegroundColor DarkYellow
            }
        }

        # Export item-level permissions (broken inheritance)
        Write-Host "Exporting item-level permissions..." -ForegroundColor Yellow

        $itemsWithUniquePerms = Get-ItemsWithBrokenInheritance -SiteUrl $SiteUrl

        foreach ($item in $itemsWithUniquePerms) {
            foreach ($perm in $item.Permissions) {
                try {
                    $principal = Get-PnPProperty -ClientObject $perm -Property Member
                    $roles = Get-PnPProperty -ClientObject $perm -Property RoleDefinitionBindings

                    foreach ($role in $roles) {
                        $allPermissions += [PSCustomObject]@{
                            Type = "$($item.Type) - Broken Inheritance"
                            ItemURL = $SiteUrl + $item.Url
                            GroupGUID = if ($principal.Id) { $principal.Id } else { "N/A" }
                            GroupName = $principal.Title
                            PermissionLevel = $role.Name
                            Owner = "N/A"
                            Description = "Item: $($item.Title)"
                        }
                    }
                }
                catch {
                    Write-Host "  Warning: Could not export permission for item $($item.Title)" -ForegroundColor DarkYellow
                }
            }
        }

        # Export to CSV
        $allPermissions | Export-Csv -Path $exportFileName -NoTypeInformation -Encoding UTF8

        Write-Host "`n✓ Exported $($allPermissions.Count) permission entries" -ForegroundColor Green
        Write-Host "✓ File saved to: $exportFileName" -ForegroundColor Green

        return $exportFileName
    }
    catch {
        Write-Host "Error exporting permissions: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Get and migrate custom permission levels (role definitions)
function Copy-CustomPermissionLevels {
    param (
        [string]$SourceSiteUrl,
        [string]$DestinationSiteUrl,
        [switch]$DryRun
    )

    Write-Host "`n=== Copying Custom Permission Levels ===" -ForegroundColor Cyan

    try {
        # Connect to source and get all role definitions
        Write-Host "Scanning SOURCE for custom permission levels..." -ForegroundColor Yellow
        $null = Connect-IndicatedSite -SiteUrl $SourceSiteUrl

        $sourceRoles = Get-PnPRoleDefinition

        # Filter to custom roles (exclude built-in SharePoint roles)
        $builtInRoles = @("Full Control", "Design", "Edit", "Contribute", "Read", "Limited Access", "View Only", "Approve", "Manage Hierarchy", "Restricted Read")
        $customRoles = $sourceRoles | Where-Object { $_.Name -notin $builtInRoles }

        if ($customRoles.Count -eq 0) {
            Write-Host "No custom permission levels found in SOURCE." -ForegroundColor DarkGray
            return
        }

        Write-Host "Found $($customRoles.Count) custom permission levels:" -ForegroundColor Green
        $customRoles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

        # Connect to destination
        Write-Host "`nConnecting to DESTINATION..." -ForegroundColor Yellow
        $null = Connect-IndicatedSite -SiteUrl $DestinationSiteUrl

        $destinationRoles = Get-PnPRoleDefinition
        $createdCount = 0
        $skippedCount = 0

        foreach ($customRole in $customRoles) {
            # Check if role already exists in destination
            $existingRole = $destinationRoles | Where-Object { $_.Name -eq $customRole.Name }

            if ($existingRole) {
                Write-Host "  ⊙ '$($customRole.Name)' already exists in DESTINATION - skipping" -ForegroundColor DarkGray
                $skippedCount++
                continue
            }

            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would create permission level: $($customRole.Name)" -ForegroundColor Yellow
                Write-Host "    Description: $($customRole.Description)" -ForegroundColor DarkGray
                $createdCount++
            } else {
                try {
                    # Create the custom permission level in destination
                    Add-PnPRoleDefinition -RoleName $customRole.Name -Description $customRole.Description -Clone $customRole.Name -Connection (Get-PnPConnection) -ErrorAction Stop

                    Write-Host "  ✓ Created permission level: $($customRole.Name)" -ForegroundColor Green
                    $createdCount++
                }
                catch {
                    # If clone fails, try creating with base permissions
                    try {
                        # Get the base permissions from source
                        $null = Connect-IndicatedSite -SiteUrl $SourceSiteUrl
                        $sourceRole = Get-PnPRoleDefinition -Identity $customRole.Name
                        $basePermissions = $sourceRole.BasePermissions

                        # Switch back to destination and create
                        $null = Connect-IndicatedSite -SiteUrl $DestinationSiteUrl

                        # Create new role with the same permissions
                        $newRole = Add-PnPRoleDefinition -RoleName $customRole.Name -Description $customRole.Description

                        # Note: Setting specific BasePermissions requires more complex permission flags
                        # For now, we'll create the role and warn the user to verify permissions
                        Write-Host "  ✓ Created permission level: $($customRole.Name) (verify permissions manually)" -ForegroundColor Yellow
                        $createdCount++
                    }
                    catch {
                        Write-Host "  ✗ Failed to create permission level: $($customRole.Name)" -ForegroundColor Red
                        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkRed
                    }
                }
            }
        }

        Write-Host "`nPermission Levels Summary:" -ForegroundColor Cyan
        Write-Host "Created: $createdCount" -ForegroundColor Green
        Write-Host "Skipped: $skippedCount" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "Error copying custom permission levels: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Get the permissions of the requested group

function Get-GroupsPermissions {
    param (
        $SiteName,
        $GroupNames
    )
    $groupData = @()
    
    if ($null -eq $SiteName) {
        Write-Host "Get-GroupsPermissions: No site name provided. Exiting function." -ForegroundColor Yellow
        return
    }
    
    if ($null -eq $GroupNames) {
        Write-Host "Get-GroupsPermissions: No groups to get permissions from. Exiting function." -ForegroundColor Yellow
        return
    }
    
    $successfulGroupPermsAcquired = @()
    $failedGroupPermsAcquired = @()
    
    # Get all permissions for each group
    foreach ($group in $GroupNames) {
        try {
            $groupPermissions = Get-PnPGroupPermissions -Identity $group["Title"].ToString() | Select-Object -Property Name -ExpandProperty Name
        
            if ($null -eq $groupPermissions) {
                $failedGroupPermsAcquired += $group["Title"]
                continue
            }
        
            $returnedPerms = @{
                Title       = $group["Title"]
                Permissions = $groupPermissions
            }        
            $groupData += $returnedPerms
            $successfulGroupPermsAcquired += $group["Title"]
        }
        catch {
            write-Host "Get-GroupPermissions: Failed to get permissions for group: $($group["Title"]). Error: $($_.Exception.Message)" -ForegroundColor Red
            $failedGroupPermsAcquired += $group["Title"]
        }
    }
    
    Write-Host "Group data count: "$groupData.Count -ForegroundColor Green
    Write-Host "Successfully acquired permissions for $($successfulGroupPermsAcquired.Count) groups." -ForegroundColor Green

    if ($failedGroupPermsAcquired.Count -gt 0) {
        Write-Host "Failed to acquire permissions for $($failedGroupPermsAcquired.Count) groups:" -ForegroundColor Red
        $failedGroupPermsAcquired | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }

    return $groupData

}

# Function to create a new group in the DESTINATION site
function New-GroupInDestination {
    param (
        $DestinationSiteName,
        $GroupsToCreate,
        $PassthroughSourceName,
        [switch]$DryRun
    )
    
    # Connect to destination site
    $connected = Connect-IndicatedSite -SiteUrl $DestinationSiteName
    
    if (-not $connected) {
        Write-Host "Failed to connect to destination site: $DestinationSiteName in order to create a new group." -ForegroundColor Red
        return
    }
    
    $groupData = @()
    
    if ($null -eq $GroupsToCreate) {
        Write-Host "No groups to create. Exiting function." -ForegroundColor Yellow
        return
    }
    
    foreach ($group in $GroupsToCreate) {
        # Extract only the properties I want to transfer
        $groupInfo = @{
            Title       = $group.Title ?? ""
            OwnerTitle  = $group.OwnerTitle ?? ""
            Description = $group.Description ?? ""
            Id          = $group.Id ?? $null
        }
        
        $groupData += $groupInfo
        
        Write-Host "Extracted - Title: $($groupInfo.Title) | Owner: $($groupInfo.OwnerTitle)" -ForegroundColor Green
    }
    
    Write-Host "`nSummary: Processed $($groupData.Count) groups" -ForegroundColor Cyan
    
    try {
        $groupsMembers = Get-GroupMembers -GroupNames $groupData -SourceSiteName $PassthroughSourceName    
    }
    catch {
        Write-Host "New-GroupInDestination: Failed to get group members from source site: $PassthroughSourceName" -ForegroundColor Red
        throw
    }
    
    try {
        $groupsPermissions = Get-GroupsPermissions -GroupNames $groupData -SiteName $PassthroughSourceName
    }
    catch {
        Write-Host "New-GroupInDestination: Failed to get group permissions from source site: $PassthroughSourceName" -ForegroundColor Red
        throw
    }
    
    
    <#
        We have 3 lists:
        * $groupData => contains the information about the existing groups in the SOURCE
        * $groupsMembers => Contains the members of the existing groups
        * $groupsPermissions => Contains the permissions of the existing groups
        
        We have to compare the lists to make sure all of the Title fields lign up. The $groupsPermissions list is the authority, since groups with NO permissions have been removed from it. No permissions = Group not important and shouldn't be migrated.
        Omnisiah help us.
    #>
    
    # Authoritative list of Titles
    $validGroupTitles = $groupsPermissions | ForEach-Object { $_.Title }
    
    # Matching list of Titles from Groups
    $filteredGroups = $groupData | Where-Object { $_.Title -in $validGroupTitles }
    
    # Matching list of Titles from Members
    $filteredMembers = $groupsMembers | Where-Object { $_.Title -in $validGroupTitles }
    
    Write-Host "Ready to migrate with $($validGroupTitles.Count). Trust in the Omnisiah. "

    # Send everything to start the copying
    if ($DryRun) {
        Start-Migration -ValidGroups $filteredGroups -ValidMembers $filteredMembers -ValidPermissions $groupsPermissions -DestinationSite $DestinationSiteName -DryRun
    } else {
        Start-Migration -ValidGroups $filteredGroups -ValidMembers $filteredMembers -ValidPermissions $groupsPermissions -DestinationSite $DestinationSiteName
    }
}

# Function to determine which groups are already in destination and which ones aren't

function Copy-SourceGroupsToDestination {
    param (
        $SourceSiteGroups,
        $DestinationSiteGroups
    )
    
    if ($null -eq $SourceSiteGroups) {
        Write-Host "Copy-SourceGroupsToDestination: No source site groups provided. Exiting function." -ForegroundColor Yellow
        return
    }
    
    if ($null -eq $DestinationSiteGroups) {
        Write-Host "Copy-SourceGroupsToDestination: No destination site groups provided. Exiting function." -ForegroundColor Yellow
        return
    }
    
    # Only keep the groups that are NOT already in the destination site
    $sourceNames = $SourceSiteGroups.Title
    $destinationNames = $DestinationSiteGroups.Title
    
    $differences = Compare-Object -ReferenceObject $destinationNames -DifferenceObject $sourceNames | Where-Object { $_.SideIndicator -eq "=>" }
    
    $groupsToMigrate = $SourceSiteGroups | Where-Object { $_.Title -in $differences.InputObject }
    
    if ($groupsToMigrate.Count -eq 0) {
        return 0
    }
    
    return $groupsToMigrate
    
}

<#
    Function to acquire the permission groups of the chosen sites, both SOURCE and DESTINATION
#>
function Search-RequestedSites {
    param (
        [string]$SourceSiteName,
        [string]$DestinationSiteName,
        [switch]$DryRun
    )
    $sourceSearched = $false
    $destinationSearched = $false
    $sourceGroups = @()
    $destinationGroups = @()
    
    do {
        
        foreach ($param in $PSBoundParameters.Keys) {
            try {
                if ($param -eq "SourceSiteName") {
                    Write-Host "`n--- Connecting to SOURCE site ---" -ForegroundColor Cyan
                    $connectionResult = Connect-IndicatedSite -SiteUrl $PSBoundParameters[$param]

                    if (-not $connectionResult) {
                        throw "Failed to connect to SOURCE site"
                    }

                    $sourceGroups = Get-PnPGroup | Where-Object { ($_.Title -notlike "Limited Access System Group*") -and ($_.Title -notlike "SharingLinks*") } | Sort-Object -Property Id
                    $sourceSearched = $true
                    Write-Host "✓ SOURCE site groups retrieved: $($sourceGroups.Count)" -ForegroundColor Green
                }
                elseif ($param -eq "DestinationSiteName") {
                    Write-Host "`n--- Connecting to DESTINATION site ---" -ForegroundColor Cyan
                    $connectionResult = Connect-IndicatedSite -SiteUrl $PSBoundParameters[$param]

                    if (-not $connectionResult) {
                        throw "Failed to connect to DESTINATION site"
                    }

                    $destinationGroups = Get-PNPGroup | Where-Object { ($_.Title -notlike "Limited Access System Group*") -and ($_.Title -notlike "SharingLinks*") } | Sort-Object -Property Id
                    $destinationSearched = $true
                    Write-Host "✓ DESTINATION site groups retrieved: $($destinationGroups.Count)" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "A connection to the site could not be completed. Error: "$_.Exception.Message -ForegroundColor Red
            }
        }
        
    } while (-not ($sourceSearched -and $destinationSearched))
    
    if (($sourceSearched -and $destinationSearched) -and ($null -ne $sourceGroups -and $null -ne $destinationGroups)) {
        Write-Host "Groups and permissions acquired for both sites. Moving to migration..." -ForegroundColor Yellow

        # First, copy custom permission levels before migrating groups
        Write-Host "`n--- Checking for Custom Permission Levels ---" -ForegroundColor Cyan
        if ($DryRun) {
            Copy-CustomPermissionLevels -SourceSiteUrl $SourceSiteName -DestinationSiteUrl $DestinationSiteName -DryRun
        } else {
            Copy-CustomPermissionLevels -SourceSiteUrl $SourceSiteName -DestinationSiteUrl $DestinationSiteName
        }

        $groupsToMigrate = Copy-SourceGroupsToDestination -SourceSiteGroups $sourceGroups -DestinationSiteGroups $destinationGroups
        
        if ($groupsToMigrate.Count -eq 0) {
            Write-Host "There are no differences between the sites. All groups are the same between the two." -ForegroundColor Yellow
            return
        }
        elseif ($groupsToMigrate.Count -ge 1) {
            Write-Host "There are $($groupsToMigrate.Count) groups to migrate. This might take a while..." -ForegroundColor DarkCyan

            if ($DryRun) {
                New-GroupInDestination -DestinationSiteName $DestinationSiteName -GroupsToCreate $groupsToMigrate -PassthroughSourceName $SourceSiteName -DryRun
            } else {
                New-GroupInDestination -DestinationSiteName $DestinationSiteName -GroupsToCreate $groupsToMigrate -PassthroughSourceName $SourceSiteName
            }
        }

        # Now scan for item-level permissions (broken inheritance)
        Write-Host "`n`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "ITEM-LEVEL PERMISSIONS (Broken Inheritance)" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

        $scanItemPerms = Read-Host "Do you want to scan for items with broken inheritance? (Y/N)"

        if ($scanItemPerms.ToLower() -eq "y") {
            # Scan source site
            Write-Host "`nScanning SOURCE site for broken inheritance..." -ForegroundColor Yellow
            $null = Connect-IndicatedSite -SiteUrl $SourceSiteName
            $sourceItemsWithUniquePerms = Get-ItemsWithBrokenInheritance -SiteUrl $SourceSiteName

            if ($sourceItemsWithUniquePerms.Count -gt 0) {
                Write-Host "`nFound $($sourceItemsWithUniquePerms.Count) items with unique permissions in SOURCE." -ForegroundColor Yellow

                $applyPerms = Read-Host "Do you want to apply these permissions to DESTINATION? (Y/N)"

                if ($applyPerms.ToLower() -eq "y") {
                    # Connect to destination and apply permissions
                    $null = Connect-IndicatedSite -SiteUrl $DestinationSiteName

                    if ($DryRun) {
                        Set-ItemLevelPermissions -SourceItems $sourceItemsWithUniquePerms -SourceSiteUrl $SourceSiteName -DestinationSiteUrl $DestinationSiteName -DryRun
                    } else {
                        Set-ItemLevelPermissions -SourceItems $sourceItemsWithUniquePerms -SourceSiteUrl $SourceSiteName -DestinationSiteUrl $DestinationSiteName
                    }
                } else {
                    Write-Host "Skipping item-level permissions migration." -ForegroundColor Yellow
                }
            } else {
                Write-Host "No items with broken inheritance found in SOURCE site." -ForegroundColor Green
            }
        } else {
            Write-Host "Skipping broken inheritance scan." -ForegroundColor Yellow
        }

        # Subsite migration
        Write-Host "`n`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "SUBSITE MIGRATION" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

        $migrateSubsites = Read-Host "Do you want to migrate subsites? (Y/N)"

        if ($migrateSubsites.ToLower() -eq "y") {
            # Discover SOURCE subsites
            Write-Host "`nDiscovering SOURCE subsites..." -ForegroundColor Yellow
            $null = Connect-IndicatedSite -SiteUrl $SourceSiteName
            $sourceSubsites = Get-SubSitesRecursively -SiteUrl $SourceSiteName

            if ($sourceSubsites.Count -gt 0) {
                Write-Host "`nFound $($sourceSubsites.Count) subsites in SOURCE" -ForegroundColor Green

                # Discover DESTINATION subsites
                Write-Host "Discovering DESTINATION subsites..." -ForegroundColor Yellow
                $null = Connect-IndicatedSite -SiteUrl $DestinationSiteName
                $destinationSubsites = Get-SubSitesRecursively -SiteUrl $DestinationSiteName

                Write-Host "Found $($destinationSubsites.Count) subsites in DESTINATION" -ForegroundColor Green

                # Match subsites using path transformation (handles Classic → Modern flattening)
                foreach ($sourceSubsite in $sourceSubsites) {
                    # Transform source subsite URL to expected destination URL
                    $expectedDestUrl = Convert-SourcePathToDestination -SourcePath $sourceSubsite.ServerRelativeUrl -SourceRootUrl $SourceSiteName -DestinationRootUrl $DestinationSiteName

                    Write-Host "`n--- SUBSITE MAPPING ---" -ForegroundColor Cyan
                    Write-Host "SOURCE:   $($sourceSubsite.Title)" -ForegroundColor Yellow
                    Write-Host "  URL: $($sourceSubsite.ServerRelativeUrl)" -ForegroundColor DarkGray
                    Write-Host "EXPECTED DESTINATION:" -ForegroundColor Yellow
                    Write-Host "  URL: $expectedDestUrl" -ForegroundColor DarkGray

                    # Try to find matching destination subsite by transformed URL
                    $matchingDestSubsite = $destinationSubsites | Where-Object {
                        $_.ServerRelativeUrl -eq $expectedDestUrl
                    } | Select-Object -First 1

                    if ($null -ne $matchingDestSubsite) {
                        Write-Host "✓ MATCHED:" -ForegroundColor Green
                        Write-Host "  DESTINATION: $($matchingDestSubsite.Title) ($($matchingDestSubsite.Url))" -ForegroundColor Green

                        $migrateThisSubsite = Read-Host "Migrate this subsite pair? (Y/N)"

                        if ($migrateThisSubsite.ToLower() -eq "y") {
                            if ($DryRun) {
                                Migrate-SubSitePermissions -SourceSubSiteUrl $sourceSubsite.Url -DestinationSubSiteUrl $matchingDestSubsite.Url -DryRun
                            } else {
                                Migrate-SubSitePermissions -SourceSubSiteUrl $sourceSubsite.Url -DestinationSubSiteUrl $matchingDestSubsite.Url
                            }
                        } else {
                            Write-Host "Skipped subsite: $($sourceSubsite.Title)" -ForegroundColor DarkGray
                        }
                    } else {
                        Write-Host "✗ NO MATCH FOUND" -ForegroundColor Red
                        Write-Host "  Expected destination URL: $expectedDestUrl" -ForegroundColor DarkYellow
                        Write-Host "  This subsite may not exist in DESTINATION yet." -ForegroundColor DarkYellow
                        Write-Host "  Sharegate should create subsites during content migration." -ForegroundColor DarkYellow
                    }
                }

                Write-Host "`n✓ All subsites processed!" -ForegroundColor Green
            } else {
                Write-Host "No subsites found in SOURCE site." -ForegroundColor DarkGray
            }
        } else {
            Write-Host "Skipping subsite migration." -ForegroundColor Yellow
        }

        # Export permissions for audit trail
        Write-Host "`n`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "PERMISSIONS EXPORT (Audit Trail)" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

        $exportPerms = Read-Host "Do you want to export permissions to CSV for audit trail? (Y/N)"

        if ($exportPerms.ToLower() -eq "y") {
            # Export SOURCE permissions
            Write-Host "`nExporting SOURCE site permissions..." -ForegroundColor Yellow
            $null = Connect-IndicatedSite -SiteUrl $SourceSiteName
            $sourceExportFile = Export-PermissionsToCSV -SiteUrl $SourceSiteName -SiteName "SOURCE"

            # Export DESTINATION permissions
            Write-Host "`nExporting DESTINATION site permissions..." -ForegroundColor Yellow
            $null = Connect-IndicatedSite -SiteUrl $DestinationSiteName
            $destExportFile = Export-PermissionsToCSV -SiteUrl $DestinationSiteName -SiteName "DESTINATION"

            Write-Host "`n✓ Audit trail complete!" -ForegroundColor Green
            Write-Host "  SOURCE:      $sourceExportFile" -ForegroundColor Cyan
            Write-Host "  DESTINATION: $destExportFile" -ForegroundColor Cyan
        } else {
            Write-Host "Skipping permissions export." -ForegroundColor Yellow
        }

        Write-Host "`n`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║          MIGRATION COMPLETE!                           ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    }
    else {
        Write-Host "Groups could not be acquired from either of the sites. Terminating..." -ForegroundColor Red
        exit
    }
}

# Search for the SOURCE site that the user wants
function Get-SearchedSourceSite {
    
    param(
        $CSVFileOfSites
    )
    try {
        # To determine if *any* site was found at all
        $validSite = $true
        # Validate if the input is empty or too short
        :urlsearch do {
            :inputverification do {
                [string]$sourceSiteToSearch = Read-Host "Please enter the URL of the site you want to use as a SOURCE. A partial URL is fine, too"
            
                $isValid = Test-UserInput -UserInput $sourceSiteToSearch
            } while (-not $isValid)
            
            try {
                # Import the recently created CSV file of all of the site collections to search for the one that the user wrote, even if it's a partial name
                $foundSourceSite = Import-Csv -Path $CSVFileOfSites | Where-Object { $_.Url -like "*$sourceSiteToSearch*" } | Select-Object Status, Url -ErrorAction Stop
            }
            catch {
                write-Host "Error importing CSV: $($_.Exception.Message)" -ForegroundColor Red
            }

            # Store the chosen site
            $chosenSourceSite

            # Determine if the results are empty because no site is named like what the user requested
            if ($null -eq $foundSourceSite) {
                Write-Host "No sites were found with that name. Try with something else." -ForegroundColor DarkYellow -BackgroundColor DarkCyan 
                $validSite = $false
                continue
            }
            elseif ($foundSourceSite.Count -gt 1) {
                # Check if the results return anything other than 1 match
                Write-Host "The name you wrote returned several matches. At the end of the list, write the number of the SOURCE site you want to select: " 
    
                # Display all results in a more visual style
                for ($i = 0; $i -lt $foundSourceSite.Count; $i++) {
                    $normalNum = $i + 1
                    Write-Host "($normalNum)" $foundSourceSite[$i].Url -ForegroundColor DarkCyan -BackgroundColor DarkGray
                }
    
                $confirmedSite = Read-Host "Select one of the SOURCE sites shown in the list of matches for what you wrote"
    
                $chosenSourceSite = $foundSourceSite[$confirmedSite - 1].Url
                $validSite = $true
            }
            else {
                # In case there's only 1 result
                $chosenSourceSite = $foundSourceSite.Url
            }

            Write-Host "The chosen SOURCE site is: "$chosenSourceSite -ForegroundColor DarkCyan -BackgroundColor DarkGray
            
            return $chosenSourceSite
        } while (-not $validSite)
        
        
    }
    catch {
        Write-Host "Failed to find the requested SOURCE site. Error: " -ForegroundColor Red
        # Generic catch for any other error
        Write-Host "Unexpected error occurred:" -ForegroundColor Red
        Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Search for the DESTINATION site that the user wants
function Get-SearchedDestinationSite {
    
    param(
        $CSVFileOfSites
    )
    try {
        # To determine if *any* site was found at all
        $validSite = $true
        # Validate if the input is empty or too short
        :urlsearch do {
            :inputverification do {
                [string]$destinationSiteToSearch = Read-Host "Please enter the URL of the site you want to use as a DESTINATION. A partial URL is fine, too"
            
                $isValid = Test-UserInput -UserInput $destinationSiteToSearch
            } while (-not $isValid)
            
            try {
                # Import the recently created CSV file of all of the site collections to search for the one that the user wrote, even if it's a partial name
                $foundDestinationSite = Import-Csv -Path $CSVFileOfSites | Where-Object { $_.Url -like "*$destinationSiteToSearch*" } | Select-Object Status, Url -ErrorAction Stop
            }
            catch {
                Write-Host "Error importing CSV: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Store the chosen site
            $chosenDestinationSite

            # Determine if the results are empty because no site is named like what the user requested
            if ($null -eq $foundDestinationSite) {
                Write-Host "No sites were found with that name. Try with something else." -ForegroundColor DarkYellow -BackgroundColor DarkCyan 
                $validSite = $false
                continue
            }
            elseif ($foundDestinationSite.Count -gt 1) {
                # Check if the results return anything other than 1 match
                Write-Host "The name you wrote returned several matches. At the end of the list, write the number of the DESTINATION site you want to select: " 
    
                # Display all results in a more visual style
                for ($i = 0; $i -lt $foundDestinationSite.Count; $i++) {
                    $normalNum = $i + 1
                    Write-Host "($normalNum)" $foundDestinationSite[$i].Url -ForegroundColor DarkCyan -BackgroundColor DarkGray
                }
    
                $confirmedSite = Read-Host "Select one of the DESTINATION sites shown in the list of matches for what you wrote"
    
                $chosenDestinationSite = $foundDestinationSite[$confirmedSite - 1].Url
                $validSite = $true
            }
            else {
                # In case there's only 1 result
                $chosenDestinationSite = $foundDestinationSite.Url
            }

            Write-Host "The chosen DESTINATION site is: "$chosenDestinationSite -ForegroundColor DarkCyan -BackgroundColor DarkGray
            
            return $chosenDestinationSite
        } while (-not $validSite)
        
        
    }
    catch {
        Write-Host "Failed to find the requested DESTINATION site." -ForegroundColor Red
        # Generic catch for any other error
        Write-Host "Unexpected error occurred:" -ForegroundColor Red
        Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Execute only on Wednesdays
if ((Get-Date).DayOfWeek -eq 'Wednesday') {
    
    $todayDate = Get-Date -Format "dd-MM-yyyy"
    
    # Expected path of file
    $pathToCheck = "C:\Users\E095713\Downloads\SiteCollection-Reports\SiteCollections-TenantWide-" + $todayDate + ".csv" 
    # Check if that wednesday's file doesn't already exist
    if (Test-Path -Path $pathToCheck) {
        Write-Host "Today's file has already been generated. Continuing with existing file."
    }
    else {
        Write-Host "It's Wednesday! Brace yourself, the report is being generated. Praise the Omnisiah."
    
        $connectionResult = Start-Process powershell.exe -ArgumentList '-File', .\Export_tenant_sites_to_csv.ps1 -Wait
        
        Write-Output $connectionResult
        
        if (-not $connectionResult.Success) {
            Write-Host "Failed to connect: "$connectionResult.Message -ForegroundColor DarkYellow
            exit
        }
    }
}

<# 
  ______       _                            _       _   
 |  ____|     | |                          (_)     | |  
 | |__   _ __ | |_ _ __ _   _   _ __   ___  _ _ __ | |_ 
 |  __| | '_ \| __| '__| | | | | '_ \ / _ \| | '_ \| __|
 | |____| | | | |_| |  | |_| | | |_) | (_) | | | | | |_ 
 |______|_| |_|\__|_|   \__, | | .__/ \___/|_|_| |_|\__|
                         __/ | | |                      
                        |___/  |_|                      
#>

# ASCII Art because why not
Clear-Host

$menu = @'
+--------------------------------------------------+
|                                                  |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣤⣤⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀               |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⠟⠉⠉⠉⠉⠉⠉⠉⠙⠻⢶⣄⠀⠀⠀⠀⠀               |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠙⣷⡀⠀⠀⠀               |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡟⠀⣠⣶⠛⠛⠛⠛⠛⠛⠳⣦⡀⠀⠘⣿⡄⠀⠀               |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⠁⠀⢹⣿⣦⣀⣀⣀⣀⣀⣠⣼⡇⠀⠀⠸⣷⠀⠀               |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡏⠀⠀⠀⠉⠛⠿⠿⠿⠿⠛⠋⠁⠀⠀⠀⠀ ⣿                |
|              ⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⢻⡇              |
|             ⣸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⢸⡇⠀             |
|     ⠀⠀⠀⠀⠀⠀⠀⠀⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   ⢸⣧      ⠀      |
|     ⠀⠀⠀⠀⠀⠀⠀⢸⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   ⠈⣿      ⠀      |
|     ⠀⠀⠀⠀⠀⠀⠀⣾⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀ ⣿      ⠀      |
|     ⠀⠀⠀⠀⠀⠀⠀⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀  ⠀⠀⠀ ⠀⣿      ⠀      |
|     ⠀⠀⠀⠀⠀⠀⢰⣿⠀⠀⠀⠀⣠⡶⠶⠿⠿⠿⠿⢷⣦⠀⠀⠀⠀⠀    ⣿⠀             |
|     ⠀⠀⣀⣀⣀⠀⣸⡇⠀⠀⠀⠀⣿⡀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀  ⠀⣿⠀             |
|     ⣠⡿⠛⠛⠛⠛⠻⠀⠀⠀⠀⠀⢸⣇⠀⠀⠀⠀⠀⠀⣿⠇⠀⠀⠀⠀⠀ ⠀ ⣿⠀             |
|     ⢻⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⡟⠀⠀⢀⣤⣤⣴⣿⠀⠀⠀⠀⠀⠀  ⠀⣿⠀             |
|     ⠈⠙⢷⣶⣦⣤⣤⣤⣴⣶⣾⠿⠛⠁⢀⣶⡟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡟⠀               |
|                    ⠈⣿⣆⡀⠀⠀⠀⠀⠀⠀⢀⣠⣴⡾⠃⠀              |  
|                  ⠀⠀⠈⠛⠻⢿⣿⣾⣿⡿⠿⠟⠋⠁⠀⠀⠀               |
|                                                  |
|              MIGRATION-MAN v1.0                  |
|                                                  |
|  Welcome to Migration-Man, your SharePoint       |
|  migration magician.                             |
|                                                  |
+--------------------------------------------------+
'@

Write-Host $menu -ForegroundColor Cyan

$optionsMenu = @'

+--------------------------------------------------+
|                                                  |
|  Press [Enter] to begin or type 'Exit' to quit.  |
|                                                  |
+--------------------------------------------------+
'@

# Variable to determine if we should keep the script running
$keepRunning = $true

do {
    try {
        Write-Host $optionsMenu -ForegroundColor Cyan
        $enteredOption = Read-Host "Your choice? "
        
        if ($enteredOption.ToLower() -eq "exit") {
            Write-Host "Exiting Migration-Man. Powodzenia!" -ForegroundColor Yellow
            $keepRunning = $false
            exit
        }
        Write-Host "Starting Migration-Man..." -ForegroundColor Green
        Start-Sleep -Seconds 1

        # Ask user if they want to run in dry-run mode
        Write-Host "`nDo you want to run in DRY-RUN mode? (Preview changes without making them)" -ForegroundColor Cyan
        Write-Host "[Y] Yes (Dry-Run) | [N] No (Live Migration)" -ForegroundColor Cyan
        $dryRunChoice = Read-Host "Your choice"
        $useDryRun = $dryRunChoice.ToLower() -eq "y"

        if ($useDryRun) {
            Write-Host "`n*** DRY-RUN MODE ENABLED - No changes will be made ***`n" -ForegroundColor Magenta
        } else {
            Write-Host "`n*** LIVE MIGRATION MODE - Changes will be applied ***`n" -ForegroundColor Green
        }

        # Get the latest created CSV file. Since these are supposed to run every Wednesday, the one chosen will always be the most up to date. The resulting file name will have the full path (FullName)
        $latestFile = Get-ChildItem -Path "C:\Users\E095713\Downloads\SiteCollection-Reports\" -Attributes !D *.* | Sort-Object -Descending -Property CreationTime | Select-Object -First 1 -ExpandProperty FullName
        
        # Variable to store the selected SOURCE site
        $resultOfSearchingForSourceSite = Get-SearchedSourceSite -CSVFileOfSites $latestFile 
        
        
        # Variable to store the selected DESTINATION site
        $resultOfSearchingForDestinationSite = Get-SearchedDestinationSite -CSVFileOfSites $latestFile

        # Send both site names to the function for getting their permission groups
        if ($useDryRun) {
            Search-RequestedSites -SourceSiteName $resultOfSearchingForSourceSite -DestinationSiteName $resultOfSearchingForDestinationSite -DryRun
        } else {
            Search-RequestedSites -SourceSiteName $resultOfSearchingForSourceSite -DestinationSiteName $resultOfSearchingForDestinationSite
        }
    }
    catch {
        Write-Host "Critical error: "$_.Exception.Message -ForegroundColor Red
        exit
    }
} while ($keepRunning)
