$testName = "Joe Smith"
$splitString = $testName.Split()
$newName = "$($splitString[1]), $($splitString[0])"

Write-Output $newName

$siteToConnect = https://rsmnet.sharepoint.com/sites/iws_leadershiphub

Connect-PnPOnline -Url $siteToConnect -clientId f6666fe0-04e6-419a-b4bb-4025060af8f5 -Interactive

