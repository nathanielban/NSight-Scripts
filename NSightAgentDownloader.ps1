#Script Name: N-Able RMM Agent Installation Script
#Version: 1.0NB
#Last Modified: 1/23/22
#Author: Nathaniel Bannister
#Author Email: nbannister@commandnit.com

#N-Able RMM API Key:
$apikey = "Your API Key"
#Regional N-Able RMM Dashboard URL:
$serverURL = "www.am.remote.management"
#Toggle Debug Mode:
$debugMode = $false

$clientListURL = "https://$serverURL/api?apikey=$apikey&service=list_clients"
[xml]$xmlclients = (new-object System.Net.WebClient).DownloadString($clientListURL)
if($debugmode -eq $True){Write-Host $xmlclients.OuterXml}
$clients = $xmlclients.result.items.client
$ClientArray = @()
#Build a Powershell Array of the clients from the XML Array so that the data can be used in Out-GridView
foreach ($client in $clients) {
    $ClientArray += [pscustomobject]@{
        ClientName=$client.name.InnerText;
        ClientID=$client.clientid;
        ServerCount=$client.server_count;
        WorkstationCount=$client.workstation_count;
    }
}
if($debugmode -eq $True){Write-Host $ClientArray}
do {
    do {
        #Show the user the array of valid clients as a grid and allow them to pick one, passing the name and id of that site forward:
        $selectedClient = $ClientArray | Out-GridView -Title "Please select a client..." -PassThru | Select-Object
        $selectedCID = $selectedClient.ClientID
        
        #As agents can only belong to a single client and site, make sure they aren't picking more than one:
        if ($selectedCID -isnot [system.array]) {
            [void] [System.Windows.MessageBox]::Show( "Please only select one site at a time.", "Too many sites selected!", "OK", "Error" )
        } 
    } until($selectedCID -isnot [system.array])
    if($selectedSID -is [system.array]){
        $answer = [void] [System.Windows.MessageBox]::Show( "Please only select one site at a time.", "Too many sites selected!", "OK", "Error" )
    }
    if($null -eq $selectedSite.RegistrationToken){
        $answer = [void] [System.Windows.MessageBox]::Show( "$SelectedSiteName does not have a valid Registration Token. This happens when an agent install has never been downloaded for that customer. Try to download an agent from the N-Central UI and run this script again.", "No Registration Token Returned", "OK", "Error" )
    }
    #Prompt the user to verify the selected client and site are correct, and allow them to re-select if they made a mistake.
    $answer = [System.Windows.MessageBox]::Show( "You've selected the $selectedSiteName site of $selectedClientName. Select No to retry your selection.", " Proceed with agent installation?", "YesNoCancel", "Warning")
    if ($answer -eq "Cancel"){exit}
} until ($answer -eq "Yes")

#Set the download url with the selected Client and Site ID:
$agentURL = "https://$serverURL/api?apikey=$apikey&service=get_site_installation_package&endcustomerid=$selectedCID&siteid=$selectedSID&os=windows&type=remote_worker"
if($debugmode -eq $True){Write-Host $agentURL}
#Test that there is a folder in %TEMP% to download and extract the installer to:
if(!(Test-Path $env:temp\rmminstall)){New-Item -Path "$env:temp" -Name "rmminstall" -ItemType "directory"}
#Download and extract the agent:
$webclient = new-object System.Net.WebClient
$webclient.downloadfile($agentURL,"$env:temp\rmminstall\siteinstallpackage.zip")
Expand-Archive -Path "$env:temp\rmminstall\siteinstallpackage.zip" -DestinationPath "$env:temp\rmminstall\"
#Not ideal, but as the name of the agent changes with the current client and version find the name of the EXE file in the targeted folder starting with AGENT_
$agentInstaller = Get-ChildItem -Path "$env:temp\rmminstall\" | Where-Object { $_.FullName -match 'AGENT_' }
$agentInstallerPath = "$env:temp\rmminstall\$agentInstaller"
if($debugmode -eq $True){Write-Host $agentInstallerPath}
#Start the installer with the silent flag.
Start-Process -FilePath $agentInstallerPath -ArgumentList "/S" -Wait
