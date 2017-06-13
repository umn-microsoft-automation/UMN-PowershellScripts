#region Primer variables
# only need when connecting to a remote Container Host.  all docker commands use $dkrRemote but if you are running locally just leave this variable blank and it works fine
$cHost = ''
$dkrRemote = "-H tcp://$($cHost):2375"
#endregion

#region quick links
Enter-PSSession $cHost # connect to container host
Enter-PSSession -ContainerId $cid -RunAsAdministrator # connect to container, double hop issue does not apply

docker $dkrRemote rm $cid -f # remove current container
docker $dkrRemote ps -aq | % {docker $dkrRemote rm $_ -f} ## Kill all running containsers
#endregion

## START HERE

################################## start a container and keep it running ##################################
$ps = "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/windows-server-container-tools/Wait-Service/Wait-Service.ps1' -OutFile 'c:\Wait-Service.ps1';c:\Wait-Service.ps1 -ServiceName WinRm -AllowServiceRestart"
($cid = docker $dkrRemote run -d $dockerArgs microsoft/windowsservercore powershell.exe -executionpolicy bypass $ps )
($name = (((docker $dkrRemote ps --no-trunc -a| Select-String $cid).ToString()).Normalize()).Split(" ")[-1]) # some commands only seem to work with the name, not CID

## copy file or folder to a container, for example a powershell script you want to run
$cPath = 'C:\Users\ContainerAdministrator\Documents' ## path to where you want files on container
$local = 'temp.zip' #whatever you want copied over
docker $dkrRemote cp -L $local $cid`:$cPath
# lets validate it copied over
docker $dkrRemote exec $($name) powershell.exe -executionpolicy bypass "Get-ChildItem -Path $cPath"
###
# There are 3 ways to send commands to a container, each has its pros/cons
# 1) use docker exec like above > docker $dkrRemote exec $($name) powershell.exe -executionpolicy bypass "<insertPS>"
# this is great for doing a few small things.  
# This host will evaluate variables FIRST, THEN send the command.  Use SINGLE QUOTES if you want the container to evaluate the variable, such as 
# ps> docker $dkrRemote exec $($name) powershell.exe -executionpolicy bypass '$env:COMPUTERNAME' # this will spit out the containers name
#
# 2) The second way is Invoke-Commnad, this only works from the container host, its better for running more complicated code, however you may be 
# better off copying over a powershell scirpt with all the code and running it on the container.  That being said, below will run invoke-command
Invoke-Command -ContainerId $cid -RunAsAdministrator -ScriptBlock{
    Get-ChildItem "$using:cPath"
    ## insert whatever you want here
}
#
# 3) the third method is to enter a pssession.  This is great for just playing around and figuring stuff out
# ps> Enter-PSSession -ContainerId $cid -RunAsAdministrator # connect to container
###

################################## END  start a container and keep it running ##################################

################################## Load up some modules ##################################
$ps = "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:`$false;`
            Install-Module -Name VMware.PowerCLI,UMN-SCCM,UMN-Infoblox,UMN-Google,UMN-Github -Force -Confirm:`$false;"
docker $dkrRemote exec $($name) powershell.exe -executionpolicy bypass $ps
docker $dkrRemote exec $($name) powershell.exe -executionpolicy bypass "get-module -listavailable"
################################## END Load up some modules ##################################

################################## Common docker switches ##################################
# running with AD creds both build and run
docker $dkrRemote run -it --security-opt "credentialspec=file://<name>.json" microsoft/windowsservercore
docker build . --security-opt "credentialspec=file://<name>.json" -t arcgis:t2

# run with a DHCP IP external to the container host, without this the Host does PAT.  Again build or run time
# Replace 'Ext' with the name of whatave network you've create, its not a default part of the build
docker run -it --network=Ext microsoft/windowsservercore
docker build . --network=Ext -t arcgis:t2

##### Get IP of container
(docker $dkrRemote inspect $($name) | ConvertFrom-Json).NetworkSettings.Networks[0].psobject.properties.Value.IPAddress  ## for static IP
docker $dkrRemote exec $($name) powershell.exe '(Get-netadapter | Get-NetIPAddress -AddressFamily IPv4).IPAddress' ## for DHCP


################################## End Common docker switches ##################################


################################## Test a chocolatey package ##################################
$chocoPack = ''
$version = '--version 1.0.0'
$waitTime = # [int] in seconds as estimate of how long package install takes
#use this one for public choco repo
$ps = "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));choco install $chocoPack $version -y;Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/windows-server-container-tools/Wait-Service/Wait-Service.ps1' -OutFile 'c:\Wait-Service.ps1';c:\Wait-Service.ps1 -ServiceName WinRm -AllowServiceRestart"
# use the following if yoiu have your own chocolatey server
# $chocoSource = 'path_to_your_choco_source'
# $ps = "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));choco install $chocoPack $version -s '$chocoSource' -y;Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/windows-server-container-tools/Wait-Service/Wait-Service.ps1' -OutFile 'c:\Wait-Service.ps1';c:\Wait-Service.ps1 -ServiceName WinRm -AllowServiceRestart"
($cid = docker run -d $dockerArgs microsoft/windowsservercore powershell.exe -executionpolicy bypass $ps )
Start-Sleep -Seconds $waitTime
Invoke-Command -ContainerId $cid -RunAsAdministrator -ScriptBlock{
    Get-Content C:\choco\logs\choco.summary.log
    #Get-Content C:\choco\logs\chocolatey.log
    choco list --local-only ## list install packages
}
################################## End Test a chocolatey package ##################################

################################## DSC Pull Server Config testing -- super handy ##################################
$ps = "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Microsoft/Virtualization-Documentation/master/windows-server-container-tools/Wait-Service/Wait-Service.ps1' -OutFile 'c:\Wait-Service.ps1';c:\Wait-Service.ps1 -ServiceName WinRm -AllowServiceRestart"
($cid = docker run -d $dockerArgs microsoft/windowsservercore powershell.exe -executionpolicy bypass $ps )
$base = 'C:\Users\ContainerAdministrator\Documents'
$o_path = 'path_to_dsc_folder'
$mof = "$o_path\localhost.meta.mof"
docker cp -L $mof $cid`:$base
Invoke-Command -ContainerId $cid -RunAsAdministrator -ScriptBlock{
    Set-DscLocalConfigurationManager -Path 'C:\Users\ContainerAdministrator\Documents' -ComputerName 'localhost' -Verbose -Force
    Start-Sleep -Seconds 2
    Update-DscConfiguration
}
################################## End DSC Pull Server Config testing -- super handy ##################################


################################## Install Chef ##################################
$name = (((docker $dkrRemote ps --no-trunc -a| Select-String $cid).ToString()).Normalize()).Split(" ")[-1]
$ps1 = 'Invoke-WebRequest -uri "https://omnitruck.chef.io/install.ps1" -OutFile c:\install.ps1;c:\install.ps1;Install'
docker $dkrRemote exec  $($name) powershell.exe -executionpolicy bypass $ps1
## 
## Test chef cookbook locally on container
$cPath = 'c:\chef'
$local = ''## where ever the cookbooks are
docker $dkrRemote cp -L $local $cid`:$cPath
docker $dkrRemote exec  $($name) powershell.exe -executionpolicy bypass 'cd c:\chef;chef-client -z -r "recipe[IIStest]' ## repalce IIStest with your cookbook

## Connect node to chef server
$chefURL = ''
$chefURL = ''
$validationClientName = ''
# the node needs one file
$local = 'path_to.pem file'
docker $dkrRemote cp -L $local $cid`:'C:\chef\validation.pem'

$cname = ($cid.Substring(0,12)).toupper()
@"
chef_server_url  '$chefURL'
validation_client_name '$validationClientName'
file_cache_path   'c:/chef/cache'
file_backup_path  'c:/chef/backup'
cache_options     ({:path => 'c:/chef/cache/checksums', :skip_expires => true})
node_name '$cname'
log_level        :info
log_location       STDOUT
"@ | Out-File "$cname.rb" -Encoding utf8 -Force
docker $dkrRemote cp -L "$cname.rb" $cid`:"c:\chef"
#docker $dkrRemote cp -L "first-boot.json" $cid`:"c:\chef"
Remove-Item "$cname.rb" -Force # once its on the container we don't need it any more
docker $dkrRemote  exec $($name) powershell.exe -executionpolicy bypass "chef-client -c c:/chef/$cname.rb" # -j c:/chef/first-boot.json"

########## This only works from the Container Host
Invoke-Command -ContainerId $cid -RunAsAdministrator -ScriptBlock{
@"
chef_server_url  '$using:chefURL'
validation_client_name '$using:validationClientName'
file_cache_path   'c:/chef/cache'
file_backup_path  'c:/chef/backup'
cache_options     ({:path => 'c:/chef/cache/checksums', :skip_expires => true})
node_name '$env:COMPUTERNAME'
log_level        :info
log_location       STDOUT
"@ | Out-File 'c:\chef\client.rb' -Encoding utf8 -Force
chef-client -c c:/chef/client.rb -j c:/chef/first-boot.json
}

$name = (((docker ps --no-trunc -a| Select-String $cid).ToString()).Normalize()).Split(" ")[-1]
$ps = "get-content c:\chef\client.rb"
docker exec $($name) powershell.exe -executionpolicy bypass $ps
$ps = "get-content c:\chef\first-boot.json"
docker exec $($name) powershell.exe -executionpolicy bypass $ps

################################## End Install Chef ##################################




