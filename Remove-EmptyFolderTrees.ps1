<#
.SYNOPSIS
    Removes empty folder trees from a SharePoint library.

.DESCRIPTION
    This script recursively scans a SharePoint library and removes folder trees
    that contain no files at any depth. Folders that contain at least one file
    anywhere in their tree structure are preserved.

.PARAMETER SiteUrl
    The URL of the SharePoint site (e.g., https://contoso.sharepoint.com/sites/sitename)

.PARAMETER LibraryName
    The name of the document library to clean up

.PARAMETER WhatIf
    Preview mode - shows what would be deleted without actually deleting

.EXAMPLE
    .\Remove-EmptyFolderTrees.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/mysite" -LibraryName "Documents" -WhatIf
    Preview what would be deleted without making changes

.EXAMPLE
    .\Remove-EmptyFolderTrees.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/mysite" -LibraryName "Documents"
    Remove all empty folder trees from the library

.NOTES
    Requires: PnP.PowerShell module
    Author: Claude
    Date: 2026-01-13
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [Parameter(Mandatory=$true)]
    [string]$LibraryName,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Check if PnP.PowerShell is available
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Error "PnP.PowerShell module is not installed. Install it with: Install-Module PnP.PowerShell -Scope CurrentUser"
    exit 1
}

# Import the module
Import-Module PnP.PowerShell -ErrorAction Stop

# Statistics tracking
$script:TotalFoldersScanned = 0
$script:EmptyTreesFound = 0
$script:EmptyTreesDeleted = 0
$script:FilesFound = 0

# Function to recursively check if a folder tree contains any files
function Test-FolderTreeHasFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderServerRelativeUrl
    )

    try {
        # Get all items in this folder (files and subfolders)
        $items = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderServerRelativeUrl -ItemType All -ErrorAction Stop

        # Check for files in current folder
        $files = $items | Where-Object { $_.TypedObject.ToString() -eq "Microsoft.SharePoint.Client.File" }
        if ($files.Count -gt 0) {
            $script:FilesFound += $files.Count
            return $true
        }

        # Recursively check subfolders
        $folders = $items | Where-Object { $_.TypedObject.ToString() -eq "Microsoft.SharePoint.Client.Folder" }
        foreach ($subfolder in $folders) {
            # Skip system folders
            if ($subfolder.Name -in @("Forms", "_cts", "_w")) {
                continue
            }

            $subfolderPath = "$FolderServerRelativeUrl/$($subfolder.Name)"
            if (Test-FolderTreeHasFiles -FolderServerRelativeUrl $subfolderPath) {
                return $true
            }
        }

        # No files found in this branch
        return $false
    }
    catch {
        Write-Warning "Error checking folder '$FolderServerRelativeUrl': $($_.Exception.Message)"
        # In case of error, assume it has files to be safe
        return $true
    }
}

# Function to recursively get all folders at all levels
function Get-AllFolders {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderServerRelativeUrl,

        [Parameter(Mandatory=$false)]
        [int]$Depth = 0
    )

    $results = @()

    try {
        $items = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderServerRelativeUrl -ItemType Folder -ErrorAction Stop

        foreach ($folder in $items) {
            # Skip system folders
            if ($folder.Name -in @("Forms", "_cts", "_w")) {
                continue
            }

            $folderPath = "$FolderServerRelativeUrl/$($folder.Name)"
            $script:TotalFoldersScanned++

            # Add current folder info
            $results += [PSCustomObject]@{
                Path = $folderPath
                Name = $folder.Name
                Depth = $Depth
            }

            # Recursively get subfolders
            $results += Get-AllFolders -FolderServerRelativeUrl $folderPath -Depth ($Depth + 1)
        }
    }
    catch {
        Write-Warning "Error getting folders from '$FolderServerRelativeUrl': $($_.Exception.Message)"
    }

    return $results
}

# Main execution
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SharePoint Empty Folder Tree Remover" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Connect to SharePoint
    Write-Host "Connecting to SharePoint site: $SiteUrl" -ForegroundColor Yellow
    Connect-PnPOnline -Url $SiteUrl -Interactive
    Write-Host "Connected successfully!`n" -ForegroundColor Green

    # Get the library
    Write-Host "Accessing library: $LibraryName" -ForegroundColor Yellow
    $library = Get-PnPList -Identity $LibraryName -ErrorAction Stop
    $libraryUrl = $library.RootFolder.ServerRelativeUrl
    Write-Host "Library found: $libraryUrl`n" -ForegroundColor Green

    # Get all folders (from deepest to shallowest to avoid deletion issues)
    Write-Host "Scanning folder structure..." -ForegroundColor Yellow
    $allFolders = Get-AllFolders -FolderServerRelativeUrl $libraryUrl
    $allFolders = $allFolders | Sort-Object -Property Depth -Descending

    Write-Host "Found $($allFolders.Count) folders (excluding system folders)`n" -ForegroundColor Green

    if ($allFolders.Count -eq 0) {
        Write-Host "No folders to process. Exiting." -ForegroundColor Yellow
        Disconnect-PnPOnline
        exit 0
    }

    # Analyze folders for emptiness
    Write-Host "Analyzing folder trees for files..." -ForegroundColor Yellow
    $emptyTrees = @()

    $progressCount = 0
    foreach ($folder in $allFolders) {
        $progressCount++
        Write-Progress -Activity "Checking folders" -Status "Checking $($folder.Name)" -PercentComplete (($progressCount / $allFolders.Count) * 100)

        $hasFiles = Test-FolderTreeHasFiles -FolderServerRelativeUrl $folder.Path

        if (-not $hasFiles) {
            $emptyTrees += $folder
            $script:EmptyTreesFound++
        }
    }
    Write-Progress -Activity "Checking folders" -Completed

    # Display results
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "ANALYSIS RESULTS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total folders scanned: $script:TotalFoldersScanned" -ForegroundColor White
    Write-Host "Total files found: $script:FilesFound" -ForegroundColor White
    Write-Host "Empty folder trees: $script:EmptyTreesFound" -ForegroundColor Yellow
    Write-Host ""

    if ($emptyTrees.Count -eq 0) {
        Write-Host "No empty folder trees found. Nothing to delete!" -ForegroundColor Green
        Disconnect-PnPOnline
        exit 0
    }

    # Display empty trees
    Write-Host "Empty folder trees that will be removed:" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    foreach ($folder in $emptyTrees | Sort-Object -Property Depth, Path) {
        $indent = "  " * $folder.Depth
        Write-Host "$indent$($folder.Name)" -ForegroundColor Red
        Write-Host "$indent  ($($folder.Path))" -ForegroundColor DarkGray
    }
    Write-Host ""

    # WhatIf mode - exit without deleting
    if ($WhatIf) {
        Write-Host "[WHATIF MODE] No changes were made. Run without -WhatIf to actually delete these folders.`n" -ForegroundColor Magenta
        Disconnect-PnPOnline
        exit 0
    }

    # Confirm deletion
    Write-Host "WARNING: You are about to delete $($emptyTrees.Count) empty folder trees." -ForegroundColor Red
    $confirmation = Read-Host "Type 'DELETE' to proceed with deletion, or anything else to cancel"

    if ($confirmation -ne 'DELETE') {
        Write-Host "`nOperation cancelled by user. No changes made." -ForegroundColor Yellow
        Disconnect-PnPOnline
        exit 0
    }

    # Perform deletion
    Write-Host "`nDeleting empty folder trees..." -ForegroundColor Yellow
    $progressCount = 0

    foreach ($folder in $emptyTrees) {
        $progressCount++
        Write-Progress -Activity "Deleting folders" -Status "Deleting $($folder.Name)" -PercentComplete (($progressCount / $emptyTrees.Count) * 100)

        try {
            # Remove the folder
            Remove-PnPFolder -Name $folder.Path -Force -ErrorAction Stop
            $script:EmptyTreesDeleted++
            Write-Host "  [DELETED] $($folder.Path)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  [FAILED] Could not delete $($folder.Path): $($_.Exception.Message)"
        }
    }
    Write-Progress -Activity "Deleting folders" -Completed

    # Final summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "OPERATION COMPLETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Empty trees found: $script:EmptyTreesFound" -ForegroundColor White
    Write-Host "Successfully deleted: $script:EmptyTreesDeleted" -ForegroundColor Green
    Write-Host "Failed to delete: $($script:EmptyTreesFound - $script:EmptyTreesDeleted)" -ForegroundColor $(if ($script:EmptyTreesFound - $script:EmptyTreesDeleted -gt 0) { "Red" } else { "Green" })
    Write-Host ""

    # Disconnect
    Disconnect-PnPOnline
    Write-Host "Disconnected from SharePoint. Operation complete!`n" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    if (Get-PnPConnection -ErrorAction SilentlyContinue) {
        Disconnect-PnPOnline
    }
    exit 1
}
