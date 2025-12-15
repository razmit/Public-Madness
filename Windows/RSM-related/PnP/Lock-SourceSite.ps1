# Lock-SourceSite.ps1
#
# Purpose: Set all groups in source site to Read-Only permissions after successful migration
# Exception: Preserves full control for groups with "Owners" in the name and site collection admins
#
# Usage:
#   .\Lock-SourceSite.ps1 -SiteUrl "https://tenant.sharepoint.com/sites/SourceSite" [-DryRun]
#
# Parameters:
#   -SiteUrl   : The source SharePoint site URL to lock down
#   -DryRun    : (Optional) Preview changes without applying them
#
# Author: Created for RSM SharePoint migration project
# Date: 2025

param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [switch]$DryRun
)

# ============================================================================
# AUTHENTICATION
# ============================================================================

# PnP OAuth Client ID (same as migration script)
$ClientId = "f6666fe0-04e6-419a-b4bb-4025060af8f5"

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           SOURCE SITE LOCKDOWN SCRIPT                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n⚠️  DRY-RUN MODE - NO CHANGES WILL BE MADE ⚠️`n" -ForegroundColor Yellow -BackgroundColor DarkRed
}

Write-Host "`nTarget Site: $SiteUrl" -ForegroundColor Cyan

# TODO: Add connection function
# TODO: Add group filtering logic
# TODO: Add permission modification logic
# TODO: Add summary reporting

Write-Host "`n✓ Script template created!" -ForegroundColor Green
Write-Host "Ready to build out the functionality..." -ForegroundColor DarkGray
