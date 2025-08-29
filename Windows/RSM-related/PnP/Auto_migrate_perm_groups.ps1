<#
    Get all the permission groups from the requested site. Can be SOURCE or DESTINATION.
#>

function Get-AllGroupsFromRequestedSite {
    param (
        [string]$TargetSiteGroups,
        [string]$TypeOfSite
    )
    
    Write-Host "There are several permission groups inside the site collection. At the end of the list, write the number of the $TypeOfSite permissions group you want to select: " 
    
    Write-Output "Passed groups: "$TargetSiteGroups

    # Display all results in a more visual style
    for ($i = 0; $i -lt $TargetSiteGroups.Count; $i++) {
        # $normalNum = $sourceSiteGroups | Select-Object -ExpandProperty Id -SkipIndex ($sourceSiteGroups.Count - $i)
        Write-Host "$($TargetSiteGroups[$i].Id)" $TargetSiteGroups[$i].Title -ForegroundColor White -BackgroundColor DarkGray
    }
    
    $confirmedGroup = Read-Host "Select one of the $TypeOfSite sites shown in the list of matches for what you wrote"
    
    $chosenSourceGroup = $TargetSiteGroups | Where-Object { $_.Id -eq $confirmedGroup }

    Write-Output "The chosen SOURCE group is: "$chosenSourceGroup
}

<# 
    Function to acquire the permission groups of the chosen sites, both SOURCE and DESTINATION
#>
function Search-RequestedSite {
    param (
        [string]$SourceSiteName,
        [string]$DestinationSiteName
    )
    
    Write-Output "Source site name: "$SourceSiteName
    
    # Connect to the SOURCE site 
    Connect-PnPOnline -Url $SourceSiteName -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive
    
    Get-PnPGroup
    # Get the SOURCE site permission groups. These are exclusively SHAREPOINT GROUPS, not AD groups
    $sourceSiteGroups = Get-PnPGroup | Sort-Object -Property Id 
    
    Write-Output "Source site groups: "$sourceSiteGroups
    
    Get-AllGroupsFromRequestedSite -TargetSiteGroups $sourceSiteGroups -TypeOfSite "source"
    
    
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
    
        Start-Process powershell.exe -ArgumentList '-File', .\Export_tenant_sites_to_csv.ps1 -Wait
    }
}
<#
    Section to handle the choosing of the SOURCE site for the permissions groups
#>

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
        
        [string]$sourceSiteToSearch = Read-Host "Please enter the URL of the site you want to use as a SOURCE. A partial URL is fine, too"

        # Get the latest created CSV file. Since these are supposed to run every Wednesday, the one chosen will always be the most up to date. The resulting file name will have the full path (FullName)
        $latestFile = Get-ChildItem -Path "C:\Users\E095713\Downloads\SiteCollection-Reports\" -Attributes !D *.* | Sort-Object -Descending -Property CreationTime | Select-Object -First 1 -ExpandProperty FullName

        # Import the recently created CSV file of all of the site collections to search for the one that the user wrote, even if it's a partial name
        $foundSourceSite = Import-Csv -Path $latestFile | Where-Object { $_.Url -like "*$sourceSiteToSearch*" } | Select-Object Status, Url

        # Store the chosen site
        $chosenSourceSite

        # Check if the results return anything other than 1 match
        if ($foundSourceSite.Count -ne 1) {
            Write-Host "The name you wrote returned several matches. At the end of the list, write the number of the SOURCE site you want to select: " 
    
            # Display all results in a more visual style
            for ($i = 0; $i -lt $foundSourceSite.Count; $i++) {
                $normalNum = $i + 1
                Write-Host "($normalNum)" $foundSourceSite[$i].Url -ForegroundColor DarkCyan -BackgroundColor DarkGray
            }
    
            $confirmedSite = Read-Host "Select one of the SOURCE sites shown in the list of matches for what you wrote"
    
            $chosenSourceSite = $foundSourceSite[$confirmedSite - 1].Url
        }
        else {
            # In case there's only 1 result
            $chosenSourceSite = $foundSourceSite.Url
        }

        Write-Host "The chosen SOURCE site is: "$chosenSourceSite

        <#
        Section to handle the DESTINATION site for the copying of the permisions groups
        i.e. where the SOURCE site was migrated to
        #>

        [string]$destinationSiteToSearch = Read-Host "Please enter the URL of the site you want to use as a DESTINATION. A partial URL is fine, too"

        $foundDestinationSite = Import-Csv -Path $latestFile | Where-Object { $_.Url -like "*$destinationSiteToSearch*" } | Select-Object Status, Url

        $chosenDestinationSiteName

        # Check if the results return anything other than 1 match
        if ($foundDestinationSite.Count -ne 1) {
            Write-Host "The name you wrote returned several matches. At the end of the list, write the number of the DESTINATION site you want to select: " 
    
            # Display all results in a more visual style
            for ($i = 0; $i -lt $foundDestinationSite.Count; $i++) {
                $normalNum = $i + 1
                Write-Host "($normalNum)" $foundDestinationSite[$i].Url -ForegroundColor DarkCyan -BackgroundColor DarkGray
            }
    
            $confirmedSite = Read-Host "Select one of the DESTINATION sites shown in the list of matches for what you wrote"
    
            $chosenDestinationSiteName = $foundDestinationSite[$confirmedSite - 1].Url
        }
        else {
            # In case there's only 1 result
            $chosenDestinationSiteName = $foundDestinationSite.Url
        }

        Write-Host "The chosen DESTINATION site is: "$chosenDestinationSiteName

        # Send both site names to the function
        Search-RequestedSite -SourceSiteName $chosenSourceSite -DestinationSiteName $chosenDestinationSiteName
    }
    catch {
    
    }
} while ($keepRunning)
