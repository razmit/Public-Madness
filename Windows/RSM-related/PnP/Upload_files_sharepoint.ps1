# Site to where the file is going to be uploaded

$url = "https://rsmnet.sharepoint.com/sites/RolinForgeworld" 

# Standard connection command 
Connect-PnPOnline -Url $url -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -interactive

# File to be uploaded
$filePath = "C:\Users\E095713\Downloads\SiteCollection-Reports\SiteCollections-TenantWide-25-08-2025.csv"

# Upload the file

Add-PnPFile -Folder "Machine Litanies/Test-Automation" -Path $filePath