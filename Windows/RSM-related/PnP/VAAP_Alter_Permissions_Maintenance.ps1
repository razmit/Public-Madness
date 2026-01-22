# WELCOME TO VAAP-MAN
# VAAP_Alter_Permissions_Maintenance.ps1
#
# Purpose: Temporarily set list permissions to Read-Only for maintenance, with ability to restore
#          Also adds/removes maintenance banner on specific pages
# Exception: Preserves any groups/users with "Full Control" permission levels
#
# Usage:
#   Lock Mode (UAT):  .\VAAP_Alter_Permissions_Maintenance.ps1 -Environment UAT -MaintenanceStart "01/20/2026 11:30 AM" -MaintenanceEnd "01/20/2026 2:30 PM" [-DryRun]
#   Lock Mode (Prod): .\VAAP_Alter_Permissions_Maintenance.ps1 -Environment Prod -MaintenanceStart "01/20/2026 11:30 AM" -MaintenanceEnd "01/20/2026 2:30 PM" [-DryRun]
#   Restore Mode:     .\VAAP_Alter_Permissions_Maintenance.ps1 -Restore -Environment <UAT|Prod> [-DryRun]
#
# Parameters:
#   -Environment        : Target environment (UAT or Prod) - REQUIRED
#   -MaintenanceStart   : Maintenance window start time (required for Lock mode)
#   -MaintenanceEnd     : Maintenance window end time (required for Lock mode)
#   -Restore            : Restore permissions and remove banner
#   -DryRun             : Preview changes without applying them
#
# Output:
#   - CSV backup files in: %USERPROFILE%\Downloads\VAAP-Permissions\
#
# Features:
#   - Supports UAT and Prod environments with separate configurations
#   - Adds maintenance banner to specific pages when locking
#   - Removes banner when restoring
#   - Modifies permissions on specific VAAP lists (hardcoded GUIDs)
#   - Backs up original permissions before modification
#   - Restores permissions from latest backup CSV
#   - Preserves all Full Control permission assignments
#   - Progress indicators and detailed logging
#   - Safety confirmations before making changes


# LATEST PROD TEST: FAILED - 01/21/26

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("UAT", "Prod", "Dev")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [string]$MaintenanceStart,

    [Parameter(Mandatory=$false)]
    [string]$MaintenanceEnd,

    [switch]$Restore,
    [switch]$DryRun
)

# ============================================================================
# ENVIRONMENT CONFIGURATIONS
# ============================================================================

# UAT Configuration
$Global:UATConfig = @{
    SiteUrl         = "https://rsmnet.sharepoint.com/sites/Solutions-UAT/vaap"
    TargetListGuids = @(
        "35F63F45-F603-49DD-A4B3-1278A3BD36A7",
        "FB10536C-BE08-4165-AA7D-D822509DDD8E",
        "144DCEA7-5151-4E4F-9064-16969002D940",
        "52256769-CD2A-4622-8912-F40EAF74D7EB",
        "39C261AB-CC72-4932-9D6D-53F0380E76C5",
        "6E0204EF-C6C8-453C-83E4-F1CA4BE96B0B"
    )
    PageNames       = @(
        "Audit-Assist.aspx",
        "AuditAssistPortal.aspx",
        "Tracker.aspx"
    )
}

# Prod Configuration
$Global:ProdConfig = @{
    SiteUrl         = "https://rsmnet.sharepoint.com/sites/solutions/vaap"
    TargetListGuids = @(
        "8531C4BA-6AD0-4369-8F72-038A90585E11",
        "ACA202CE-BB34-4BC2-A91C-40BE0B04BBC0",
        "E055289A-9C09-4DC2-A546-6E2C9B87AFF2",
        "EDB1FB42-3E67-480D-813E-BE4B95DE7A53",
        "CEE3B8A5-E9E4-49A0-A346-62E195984783",
        "28CAD9EC-394F-4B43-8CC0-735D43BC47BB"
    )
    PageNames       = @(
        "Audit-Assist.aspx",
        "AuditAssistPortal.aspx",
        "Tracker.aspx"
    )
}

$Global:DevConfig = @{
    SiteUrl         = "https://rsmnet.sharepoint.com/sites/solutions-dev/vaap"
    TargetListGuids = @(
        "f64b3c30-e114-457f-b56d-6952748e1699"
        "edf92db5-42f6-40ee-82da-42764ba6aeb4"
        "07e691ae-957f-450b-be10-4b66bf418bb9"
        "86bf3d4a-5f3e-4db7-87d3-7d8e71ed9a9c"
        "e5c0eebe-ea01-4746-a5e9-dae3237abf13"
        "78e9298a-1c03-42af-8073-3f282a62fa6a"
    )
    PageNames = @(
        "Audit-Assist.aspx",
        "AuditAssistPortal.aspx",
        "Tracker.aspx"
    )
}

# Set active configuration based on environment parameter
$Global:Config = if ($Environment -eq "UAT") { $Global:UATConfig } elseif ($Environment -eq "Prod") { $Global:ProdConfig } elseif ($Environment -eq "Dev") {$Global:DevConfig}
$Global:SiteUrl = $Global:Config.SiteUrl
$Global:TargetListGuids = $Global:Config.TargetListGuids
$Global:PageNames = $Global:Config.PageNames

# Dynamic path to VAAP-Permissions folder
$Global:VaapFolder = Join-Path $env:USERPROFILE "Downloads\VAAP-Permissions"

# Banner backup file
$Global:BannerBackupFile = Join-Path $Global:VaapFolder "BannerBackup_${Environment}.json"

# ============================================================================
# FUNCTIONS
# ============================================================================

# Initialize VAAP-Permissions folder structure
function Initialize-VaapFolder {
    try {
        if (-not (Test-Path $Global:VaapFolder)) {
            New-Item -Path $Global:VaapFolder -ItemType Directory -Force | Out-Null
            Write-Host "✓ Created VAAP-Permissions folder: $Global:VaapFolder" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Using VAAP-Permissions folder: $Global:VaapFolder" -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Host "✗ Failed to initialize VAAP-Permissions folder: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to connect to a SharePoint site with retry logic
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
            Write-Host "Connecting to site... (Attempt $failCounter of $maxRetries)" -ForegroundColor Yellow
            Connect-PnPOnline -Url $SiteUrl -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive
            Write-Host "✓ Connection successful!" -ForegroundColor Green
            $connected = $true
            break
        }
        catch {
            if ($_.Exception.Message -notlike "*parse near offset*" -and $_.Exception.Message -notlike "*ASCII digit*") {
                Write-Host "Connection attempt $failCounter failed: $($_.Exception.Message)" -ForegroundColor Red
            } else {
                Write-Host "Connection attempt $failCounter failed (authentication flow issue - retrying...)" -ForegroundColor Red
            }
            $failCounter++

            if ($failCounter -le $maxRetries) {
                Write-Host "Retrying in 2 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    } while ($failCounter -le $maxRetries -and -not $connected)

    if (-not $connected) {
        Write-Host "✗ All connection attempts failed for $SiteUrl" -ForegroundColor Red
        return $false
    }

    return $true
}

# Get list by GUID with error handling
function Get-TargetList {
    param (
        [string]$ListGuid
    )

    try {
        $list = Get-PnPList -Identity $ListGuid -Includes Title,RoleAssignments,HasUniqueRoleAssignments -ErrorAction Stop
        Write-Host "  ✓ Found list: $($list.Title) (GUID: $ListGuid)" -ForegroundColor Green
        return $list
    }
    catch {
        Write-Host "  ✗ Failed to retrieve list with GUID: $ListGuid" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        return $null
    }
}

# Get the latest backup CSV file
function Get-LatestBackupCsv {
    try {
        $csvFiles = Get-ChildItem -Path $Global:VaapFolder -Filter "VAAP_PermissionsBackup_${Environment}_*.csv" |
                    Sort-Object LastWriteTime -Descending

        if ($csvFiles.Count -eq 0) {
            Write-Host "✗ No backup CSV files found for $Environment in: $Global:VaapFolder" -ForegroundColor Red
            return $null
        }

        $latestCsv = $csvFiles[0]
        Write-Host "✓ Found latest backup: $($latestCsv.Name)" -ForegroundColor Green
        Write-Host "  Created: $($latestCsv.LastWriteTime)" -ForegroundColor DarkGray

        return $latestCsv.FullName
    }
    catch {
        Write-Host "✗ Error finding backup CSV: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Check if a role assignment has Full Control permissions
function Test-HasFullControl {
    param (
        $RoleDefinitions
    )

    foreach ($role in $RoleDefinitions) {
        if ($role.Name -like "*Full Control*") {
            return $true
        }
    }
    return $false
}

# Add maintenance banner to a page
function Add-MaintenanceBanner {
    param (
        [string]$PageName,
        [string]$MaintenanceStart,
        [string]$MaintenanceEnd,
        [switch]$DryRun
    )

    try {
        # Format the dates
        $startDate = [DateTime]::Parse($MaintenanceStart)
        $endDate = [DateTime]::Parse($MaintenanceEnd)
        $dateRange = "$($startDate.ToString('MM/dd/yyyy hh:mm tt')) - $($endDate.ToString('h:mm tt')) CT"

        # Get the page
        $pagePath = "SitePages/$PageName"

        if ($DryRun) {
            Write-Host "    [DRY-RUN] Would add banner to: $PageName" -ForegroundColor Magenta
            return @{ Success = $true; PageName = $PageName; Action = "Add" }
        }

        # Check if page exists
        $page = Get-PnPPage -Identity $PageName -ErrorAction Stop

        # Create banner HTML
        $bannerHtml = @"
<div style="text-align: center; padding: 20px; background-color: #fff; border: 2px solid #d32f2f; margin-bottom: 20px;">
    <h1 style="color: #d32f2f; font-size: 36px; margin: 0 0 10px 0; font-weight: bold;">IMPORTANT!</h1>
    <p style="font-size: 18px; margin: 10px 0; color: #333;">Audit Assist will be down for maintenance on:</p>
    <p style="font-size: 20px; margin: 10px 0; font-weight: bold; color: #000;">$dateRange</p>
    <p style="font-size: 16px; margin: 10px 0; color: #333;">During the maintenance window, the Portal will be <em>read-only</em>, and you will not be able to save your changes.</p>
</div>
"@

        # Try to add a new section at the top for the banner
        try {
            Add-PnPPageSection -Page $PageName -SectionTemplate OneColumn -Order 1 -ErrorAction Stop
            Add-PnPPageTextPart -Page $PageName -Text $bannerHtml -Section 1 -Column 1 -ErrorAction Stop
        }
        catch {
            # If adding section fails (e.g., page has complex layout), try alternative approach
            Write-Host "    ⚠ Standard section add failed, trying alternative method..." -ForegroundColor Yellow

            # Try adding to section 2 instead (push existing content further down)
            try {
                Add-PnPPageSection -Page $PageName -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 0 -ErrorAction Stop
                Add-PnPPageTextPart -Page $PageName -Text $bannerHtml -Section 1 -Column 1 -ErrorAction Stop
            }
            catch {
                # Last resort: add to bottom and warn user
                Write-Host "    ⚠ Could not add banner at top, adding to bottom of page..." -ForegroundColor Yellow
                Add-PnPPageTextPart -Page $PageName -Text $bannerHtml -ErrorAction Stop
            }
        }

        # Publish the page
        Set-PnPPage -Identity $PageName -Publish -ErrorAction Stop

        Write-Host "    ✓ Added banner to: $PageName" -ForegroundColor Green

        return @{
            Success = $true
            PageName = $PageName
            Action = "Add"
            StartTime = $MaintenanceStart
            EndTime = $MaintenanceEnd
        }
    }
    catch {
        Write-Host "    ✗ Failed to add banner to: $PageName - $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; PageName = $PageName; Error = $_.Exception.Message }
    }
}

# Remove maintenance banner from a page
function Remove-MaintenanceBanner {
    param (
        [string]$PageName,
        [switch]$DryRun
    )

    try {
        if ($DryRun) {
            Write-Host "    [DRY-RUN] Would remove banner from: $PageName" -ForegroundColor Magenta
            return @{ Success = $true; PageName = $PageName; Action = "Remove" }
        }

        # Get the page
        $page = Get-PnPPage -Identity $PageName -ErrorAction Stop

        # Get all text web parts
        $controls = $page.Controls | Where-Object { $_.Type.Name -eq "ClientSideText" }

        $removed = $false
        foreach ($control in $controls) {
            # Check if this is our maintenance banner (contains "IMPORTANT!" text)
            if ($control.Text -like "*IMPORTANT!*" -and $control.Text -like "*read-only*") {
                Remove-PnPPageComponent -Page $PageName -InstanceId $control.InstanceId -Force -ErrorAction Stop
                $removed = $true
                Write-Host "    ✓ Removed banner from: $PageName" -ForegroundColor Green
                break
            }
        }

        if (-not $removed) {
            Write-Host "    ⚠ No maintenance banner found on: $PageName" -ForegroundColor Yellow
        }

        # Publish the page
        Set-PnPPage -Identity $PageName -Publish -ErrorAction Stop

        return @{
            Success = $true
            PageName = $PageName
            Action = "Remove"
            BannerFound = $removed
        }
    }
    catch {
        Write-Host "    ✗ Failed to remove banner from: $PageName - $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; PageName = $PageName; Error = $_.Exception.Message }
    }
}

# Process banners for all pages
function Invoke-BannerOperation {
    param (
        [ValidateSet("Add", "Remove")]
        [string]$Operation,
        [string]$MaintenanceStart,
        [string]$MaintenanceEnd,
        [switch]$DryRun
    )

    Write-Host "`n--- ${Operation}ing Maintenance Banners ---" -ForegroundColor Cyan
    Write-Host "Pages to process: $($Global:PageNames.Count)" -ForegroundColor Yellow

    $results = @()

    foreach ($pageName in $Global:PageNames) {
        Write-Host "`n→ Processing page: $pageName" -ForegroundColor Cyan

        if ($Operation -eq "Add") {
            $result = Add-MaintenanceBanner -PageName $pageName -MaintenanceStart $MaintenanceStart -MaintenanceEnd $MaintenanceEnd -DryRun:$DryRun
        }
        else {
            $result = Remove-MaintenanceBanner -PageName $pageName -DryRun:$DryRun
        }

        $results += $result
    }

    # Save banner operation details for restore
    if ($Operation -eq "Add" -and -not $DryRun) {
        $backupData = @{
            Environment = $Environment
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            MaintenanceStart = $MaintenanceStart
            MaintenanceEnd = $MaintenanceEnd
            Pages = $Global:PageNames
        }
        $backupData | ConvertTo-Json | Set-Content -Path $Global:BannerBackupFile
        Write-Host "`n✓ Banner metadata saved for restore" -ForegroundColor Green
    }

    # Remove banner backup file after restore
    if ($Operation -eq "Remove" -and -not $DryRun) {
        if (Test-Path $Global:BannerBackupFile) {
            Remove-Item $Global:BannerBackupFile -Force
            Write-Host "`n✓ Banner metadata cleanup complete" -ForegroundColor Green
        }
    }

    $successCount = ($results | Where-Object { $_.Success -eq $true }).Count
    $failCount = ($results | Where-Object { $_.Success -eq $false }).Count

    Write-Host "`n  Banner Operation Summary:" -ForegroundColor Cyan
    Write-Host "    Successful: $successCount" -ForegroundColor Green
    Write-Host "    Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })

    return $results
}

# Process list permissions in Lock mode
function Invoke-LockList {
    param (
        [string]$ListGuid,
        [switch]$DryRun
    )

    $backupEntries = @()
    $lockedCount = 0
    $preservedCount = 0
    $failCount = 0

    # Get the list
    $list = Get-TargetList -ListGuid $ListGuid
    if (-not $list) {
        Write-Host "  ✗ Skipping list due to retrieval failure`n" -ForegroundColor Red
        return $backupEntries
    }

    # Check if list has unique permissions
    if (-not $list.HasUniqueRoleAssignments) {
        Write-Host "  ⚠ Warning: List '$($list.Title)' inherits permissions from parent" -ForegroundColor Yellow
        Write-Host "    This script only works on lists with broken inheritance" -ForegroundColor Yellow
        return $backupEntries
    }

    Write-Host "`n  --- Analyzing List Permissions ---" -ForegroundColor Cyan
    Write-Host "  List: $($list.Title)" -ForegroundColor DarkCyan

    # Get all role assignments
    $roleAssignments = $list.RoleAssignments

    if ($roleAssignments.Count -eq 0) {
        Write-Host "  ⚠ No role assignments found on this list" -ForegroundColor Yellow
        return $backupEntries
    }

    Write-Host "  Found $($roleAssignments.Count) role assignment(s)" -ForegroundColor DarkGray

    # Process each role assignment
    foreach ($roleAssignment in $roleAssignments) {
        try {
            # Get the principal (group or user)
            $principal = Get-PnPProperty -ClientObject $roleAssignment -Property Member -ErrorAction Stop
            $roleDefinitions = Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings -ErrorAction Stop

            $principalTitle = $principal.Title
            $principalType = $principal.PrincipalType.ToString()
            $principalId = $principal.Id

            # Get permission level names
            $permissionLevels = ($roleDefinitions | ForEach-Object { $_.Name }) -join ","

            # Check if has Full Control
            $hasFullControl = Test-HasFullControl -RoleDefinitions $roleDefinitions

            if ($hasFullControl) {
                Write-Host "    ✓ Preserve Full Control: $principalTitle ($permissionLevels)" -ForegroundColor Green
                $preservedCount++
            }
            else {
                # Backup current permissions
                $backupEntries += [PSCustomObject]@{
                    ListGuid         = $ListGuid
                    ListTitle        = $list.Title
                    PrincipalType    = $principalType
                    PrincipalTitle   = $principalTitle
                    PrincipalId      = $principalId
                    PermissionLevels = $permissionLevels
                }

                if ($DryRun) {
                    Write-Host "    [DRY-RUN] Would set to Read: $principalTitle (Current: $permissionLevels)" -ForegroundColor Magenta
                    $lockedCount++
                }
                else {
                    # Determine if this is a group or user for proper parameter usage
                    $isGroup = ($principalType -eq "SharePointGroup")

                    # Remove existing permission levels
                    foreach ($role in $roleDefinitions) {
                        if ($isGroup) {
                            Set-PnPListPermission -Identity $ListGuid -Group $principalTitle -RemoveRole $role.Name -ErrorAction Stop
                        }
                        else {
                            Set-PnPListPermission -Identity $ListGuid -User $principalTitle -RemoveRole $role.Name -ErrorAction Stop
                        }
                    }

                    # Add Read permission
                    if ($isGroup) {
                        Set-PnPListPermission -Identity $ListGuid -Group $principalTitle -AddRole "Read" -ErrorAction Stop
                    }
                    else {
                        Set-PnPListPermission -Identity $ListGuid -User $principalTitle -AddRole "Read" -ErrorAction Stop
                    }
                    Write-Host "    ✓ Set to Read: $principalTitle (Was: $permissionLevels)" -ForegroundColor Green
                    $lockedCount++
                }
            }
        }
        catch {
            Write-Host "    ✗ Failed to process: $principalTitle - $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n  Summary for '$($list.Title)':" -ForegroundColor Cyan
    Write-Host "    Locked to Read: $lockedCount" -ForegroundColor Yellow
    Write-Host "    Preserved: $preservedCount" -ForegroundColor Green
    Write-Host "    Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })

    return $backupEntries
}

# Main Lock mode function
function Invoke-LockMode {
    param (
        [string]$MaintenanceStart,
        [string]$MaintenanceEnd,
        [switch]$DryRun
    )

    Write-Host "`n--- Starting Lock Mode ---" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Yellow
    Write-Host "Target Site: $Global:SiteUrl" -ForegroundColor Yellow
    Write-Host "Lists to process: $($Global:TargetListGuids.Count)" -ForegroundColor Yellow

    # Step 1: Add banners
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           STEP 1: ADD MAINTENANCE BANNERS               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    $bannerResults = Invoke-BannerOperation -Operation "Add" -MaintenanceStart $MaintenanceStart -MaintenanceEnd $MaintenanceEnd -DryRun:$DryRun

    # Step 2: Lock permissions
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           STEP 2: LOCK LIST PERMISSIONS                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    $allBackupEntries = @()

    foreach ($listGuid in $Global:TargetListGuids) {
        Write-Host "`n→ Processing list: $listGuid" -ForegroundColor Cyan

        $backupEntries = Invoke-LockList -ListGuid $listGuid -DryRun:$DryRun
        $allBackupEntries += $backupEntries
    }

    # Export backup CSV
    if ($allBackupEntries.Count -gt 0) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvPath = Join-Path $Global:VaapFolder "VAAP_PermissionsBackup_${Environment}_$timestamp.csv"

        try {
            $allBackupEntries | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "`n✓ Permissions backup exported to: $csvPath" -ForegroundColor Green
            Write-Host "  Total entries backed up: $($allBackupEntries.Count)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "`n✗ Failed to export backup CSV: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`n⚠ No permissions were modified (nothing to backup)" -ForegroundColor Yellow
    }

    # Final summary
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              LOCK MODE COMPLETE                         ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green

    if ($DryRun) {
        Write-Host "`n⚠️  This was a DRY-RUN. No changes were made." -ForegroundColor Yellow
        Write-Host "Run without -DryRun to apply changes." -ForegroundColor Yellow
    }
}

# Restore permissions from CSV
function Invoke-RestoreMode {
    param (
        [string]$CsvPath,
        [switch]$DryRun
    )

    # Step 1: Restore permissions
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         STEP 1: RESTORE LIST PERMISSIONS                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    try {
        $backup = Import-Csv $CsvPath -ErrorAction Stop

        if ($backup.Count -eq 0) {
            Write-Host "✗ Backup CSV is empty." -ForegroundColor Red
            return
        }

        Write-Host "✓ Loaded $($backup.Count) permission entries from backup" -ForegroundColor Green

        # Group by list
        $listGroups = $backup | Group-Object -Property ListGuid

        Write-Host "`n=== Lists in Backup ===" -ForegroundColor Cyan
        foreach ($listGroup in $listGroups) {
            $listTitle = ($listGroup.Group | Select-Object -First 1).ListTitle
            Write-Host "  • $listTitle - $($listGroup.Count) permission(s)" -ForegroundColor DarkGray
        }

        Write-Host "`n--- Starting Restoration ---`n" -ForegroundColor Cyan

        $totalSuccess = 0
        $totalFailed = 0

        foreach ($listGroup in $listGroups) {
            $listGuid = $listGroup.Name
            $listTitle = ($listGroup.Group | Select-Object -First 1).ListTitle

            Write-Host "→ Processing list: $listTitle (GUID: $listGuid)" -ForegroundColor Cyan

            # Get the list
            $list = Get-TargetList -ListGuid $listGuid
            if (-not $list) {
                Write-Host "  ✗ Skipping list due to retrieval failure" -ForegroundColor Red
                $totalFailed += $listGroup.Count
                continue
            }

            # Restore each permission
            foreach ($item in $listGroup.Group) {
                try {
                    $principalTitle = $item.PrincipalTitle
                    $permissionLevels = $item.PermissionLevels -split ","

                    if ($DryRun) {
                        Write-Host "    [DRY-RUN] Would restore: $principalTitle -> $($item.PermissionLevels)" -ForegroundColor Magenta
                        $totalSuccess++
                    }
                    else {
                        # Get current permissions for this principal
                        $currentRoles = @()
                        try {
                            $roleAssignment = $list.RoleAssignments | Where-Object {
                                $member = Get-PnPProperty -ClientObject $_ -Property Member
                                $member.Title -eq $principalTitle
                            } | Select-Object -First 1

                            if ($roleAssignment) {
                                $roleDefinitions = Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings
                                $currentRoles = $roleDefinitions | ForEach-Object { $_.Name }
                            }
                        }
                        catch {
                            # Principal might not have any roles currently
                        }

                        # Determine if this is a group or user for proper parameter usage
                        $isGroup = ($item.PrincipalType -eq "SharePointGroup")

                        # Filter out system-managed permission levels that cannot be manually granted
                        $systemPermissions = @("Limited Access", "Web-Only Limited Access")
                        $restorablePermissions = $permissionLevels | Where-Object {
                            $perm = $_.Trim()
                            $perm -ne "" -and $perm -notin $systemPermissions
                        }

                        # Check if any permissions were filtered out
                        $filteredPerms = $permissionLevels | Where-Object { $_.Trim() -in $systemPermissions }
                        if ($filteredPerms.Count -gt 0) {
                            Write-Host "    ⚠ Skipping system-managed permissions: $($filteredPerms -join ', ')" -ForegroundColor DarkYellow
                        }

                        # Remove current permissions
                        foreach ($role in $currentRoles) {
                            if ($isGroup) {
                                Set-PnPListPermission -Identity $listGuid -Group $principalTitle -RemoveRole $role -ErrorAction Stop
                            }
                            else {
                                Set-PnPListPermission -Identity $listGuid -User $principalTitle -RemoveRole $role -ErrorAction Stop
                            }
                        }

                        # Add back original permissions (excluding system-managed ones)
                        foreach ($permission in $restorablePermissions) {
                            if ($isGroup) {
                                Set-PnPListPermission -Identity $listGuid -Group $principalTitle -AddRole $permission -ErrorAction Stop
                            }
                            else {
                                Set-PnPListPermission -Identity $listGuid -User $principalTitle -AddRole $permission -ErrorAction Stop
                            }
                        }

                        Write-Host "    ✓ Restored: $principalTitle -> $($item.PermissionLevels)" -ForegroundColor Green
                        $totalSuccess++
                    }
                }
                catch {
                    Write-Host "    ✗ Failed to restore: $($item.PrincipalTitle) - $($_.Exception.Message)" -ForegroundColor Red
                    $totalFailed++
                }
            }

            Write-Host ""
        }

        Write-Host "`n=== Permission Restoration Summary ===" -ForegroundColor Cyan
        Write-Host "Successfully restored: $totalSuccess" -ForegroundColor Green
        Write-Host "Failed: $totalFailed" -ForegroundColor Red
    }
    catch {
        Write-Host "✗ Error during restoration: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Step 2: Remove banners
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         STEP 2: REMOVE MAINTENANCE BANNERS              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    $bannerResults = Invoke-BannerOperation -Operation "Remove" -MaintenanceStart "" -MaintenanceEnd "" -DryRun:$DryRun

    # Final summary
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║           RESTORATION COMPLETE                          ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

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
|              VAAP-MAN v2.4                  |
|                                                  |
|  Welcome to VAAP-MAN, your VAAP       |
|  maintenance magician.                             |
|                                                  |
+--------------------------------------------------+
'@

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   VAAP PERMISSIONS & BANNER MAINTENANCE SCRIPT          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host $menu -ForegroundColor DarkCyan

Write-Host "`nEnvironment: $Environment" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n⚠️  DRY-RUN MODE - NO CHANGES WILL BE MADE ⚠️`n" -ForegroundColor Yellow -BackgroundColor DarkRed
}

# Validate maintenance times for Lock mode
if (-not $Restore) {
    if ([string]::IsNullOrWhiteSpace($MaintenanceStart) -or [string]::IsNullOrWhiteSpace($MaintenanceEnd)) {
        Write-Host "`n✗ Error: -MaintenanceStart and -MaintenanceEnd are required for Lock mode" -ForegroundColor Red
        Write-Host "  Example: -MaintenanceStart '01/20/2026 11:30 AM' -MaintenanceEnd '01/20/2026 2:30 PM'" -ForegroundColor Yellow
        exit 1
    }

    # Validate date formats
    try {
        $startDate = [DateTime]::Parse($MaintenanceStart)
        $endDate = [DateTime]::Parse($MaintenanceEnd)

        if ($endDate -le $startDate) {
            Write-Host "`n✗ Error: Maintenance end time must be after start time" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "`n✗ Error: Invalid date format. Use format like: 01/20/2026 11:30 AM" -ForegroundColor Red
        exit 1
    }
}

# Validate list GUIDs
if ($Global:TargetListGuids.Count -eq 0) {
    Write-Host "`n✗ Error: No list GUIDs configured for $Environment environment" -ForegroundColor Red
    Write-Host "  Please add list GUIDs to the configuration at the top of the script" -ForegroundColor Yellow
    exit 1
}

# Initialize folder structure
$folderReady = Initialize-VaapFolder
if (-not $folderReady) {
    Write-Host "`n✗ Cannot proceed without VAAP-Permissions folder. Exiting." -ForegroundColor Red
    exit 1
}

# Connect to site
Write-Host "`nConnecting to: $Global:SiteUrl" -ForegroundColor Cyan
$connected = Connect-IndicatedSite -SiteUrl $Global:SiteUrl
if (-not $connected) {
    Write-Host "`n✗ Failed to connect to site. Exiting." -ForegroundColor Red
    exit 1
}

# RESTORE MODE
if ($Restore) {
    Write-Host "`n=== RESTORE MODE ===" -ForegroundColor Yellow

    # Get latest backup CSV
    $csvPath = Get-LatestBackupCsv
    if (-not $csvPath) {
        Write-Host "`n✗ Cannot proceed without backup CSV. Exiting." -ForegroundColor Red
        exit 1
    }

    # Confirm restoration
    if (-not $DryRun) {
        $confirm = Read-Host "`n⚠️  WARNING: This will restore list permissions and remove banners. Proceed? (Y/N)"
        if ($confirm.ToLower() -ne "y") {
            Write-Host "`n✗ Restoration cancelled by user." -ForegroundColor Red
            exit 0
        }
    }

    # Restore permissions and remove banners
    Invoke-RestoreMode -CsvPath $csvPath -DryRun:$DryRun

    if ($DryRun) {
        Write-Host "`n⚠️  This was a DRY-RUN. No changes were made." -ForegroundColor Yellow
    }
}
# LOCK MODE
else {
    Write-Host "`n=== LOCK MODE ===" -ForegroundColor Yellow
    Write-Host "Maintenance Window: $MaintenanceStart - $MaintenanceEnd" -ForegroundColor Yellow

    # Confirm lock
    if (-not $DryRun) {
        $confirm = Read-Host "`n⚠️  WARNING: This will add banners and set permissions to Read-Only on $($Global:TargetListGuids.Count) list(s). Proceed? (Y/N)"
        if ($confirm.ToLower() -ne "y") {
            Write-Host "`n✗ Lock operation cancelled by user." -ForegroundColor Red
            exit 0
        }
    }

    # Add banners and lock lists
    Invoke-LockMode -MaintenanceStart $MaintenanceStart -MaintenanceEnd $MaintenanceEnd -DryRun:$DryRun
}

Write-Host ""
