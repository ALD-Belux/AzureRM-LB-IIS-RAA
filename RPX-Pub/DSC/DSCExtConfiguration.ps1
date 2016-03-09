Configuration Main
{
	Param 
	( 
		[string] $nodeName,
		[System.Management.Automation.PSCredential] $storageCreds,
		[System.Management.Automation.PSCredential] $CertificateCreds,
		[string] $dmzDnsZone,
		[string] $dmzDnsIP,
		[string] $IPAddress,
		[string] $netmask,
		[string] $gateway,
		[string] $createShareWebhook,
		[string] $ResourceGroupName,
		[string] $CertificateBlob
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking, xPSDesiredStateConfiguration, xPendingReboot, xCertificate

	[PSCredential] $psCredentialSTG = New-Object System.Management.Automation.PSCredential ("$($storageCreds.UserName)", $storageCreds.Password)
	[PSCredential] $psCredentialCert = New-Object System.Management.Automation.PSCredential ("$($CertificateCreds.UserName)", $CertificateCreds.Password)

	Node localhost
	{
		LocalConfigurationManager
		{
			ActionAfterReboot = 'ContinueConfiguration'
			ConfigurationMode = 'ApplyOnly'
			RebootNodeIfNeeded = $true
		}

		xPendingReboot PreTest
		{
            Name = "Check for a pending reboot before changing anything"
        }

		User Storage
		{
			UserName = $psCredentialSTG.UserName
			Description = 'Account to acces Azure Files Storage'
            Ensure = 'Present'
            FullName = 'Azure File Storage'
            Password = $psCredentialSTG
            PasswordChangeRequired = $false
            PasswordNeverExpires = $true
		}
		xGroup AddToIIS{
            GroupName='IIS_IUSRS'
            DependsOn= '[User]Storage'
            Ensure= 'Present'
            MembersToInclude=$('.\' + $storageCreds.UserName)
        }
		xDhcpClient DisableDhcpClient
		{
			State          = 'Disabled'
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
		}
		Script WaitForDHCP
		{
			TestScript = {
				return $false
			}
			SetScript = {
				Start-Sleep -Seconds 30
			}
			GetScript ={@{Result = "WaitForDHCP"}}

			DependsOn = "[xDhcpClient]DisableDhcpClient"
		}
		xIPAddress FixedIPAddress 
		{ 
			IPAddress      = $IPAddress 
			SubnetMask     = $netMask
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
			DependsOn = "[Script]WaitForDHCP"
		}
		xDefaultGatewayAddress Gateway 
		{ 
			Address      = $gateway
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
			DependsOn = "[xIPAddress]FixedIPAddress"
		}
		WindowsFeature DNS
		{
			Name = "DNS"
			Ensure = "Present"		
			DependsOn = "[xDhcpClient]DisableDhcpClient","[xIPAddress]FixedIPAddress","[xDefaultGatewayAddress]Gateway"
		}
		WindowsFeature DNSMgmt
		{
			Name = "RSAT-DNS-Server"
			Ensure = "Present"		
			DependsOn = "[WindowsFeature]DNS"
		}
		xDnsServerAddress DnsServerAddress 
		{ 
			Address        = '127.0.0.1' 
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
			DependsOn = "[WindowsFeature]DNS"
		}
		Script DMZForwarder
		{
			TestScript = {
				foreach ($zone in Get-DnsServerZone) {
					if($zone.ZoneName -eq $using:dmzDnsZone ) {return $true}
				}
				return $false
			}
			SetScript = {
				Add-DnsServerConditionalForwarderZone -name $using:dmzDnsZone -MasterServers $using:dmzDnsIP
				Start-Sleep -Seconds 30
				$resolved = Resolve-DnsName -Name "www.google.com" -DnsOnly -ErrorAction SilentlyContinue
				Start-Sleep -Seconds 10
				$resolved = Resolve-DnsName -Name "download.microsoft.com" -DnsOnly -ErrorAction SilentlyContinue
				Start-Sleep -Seconds 10
				$resolved = Resolve-DnsName -Name "s2events.azure-automation.net" -DnsOnly -ErrorAction SilentlyContinue
				Start-Sleep -Seconds 10
				$resolved = Resolve-DnsName -Name $using:dmzDnsZone -DnsOnly -ErrorAction SilentlyContinue
			}
			GetScript ={@{Result = "DMZForwarder"}}

			DependsOn = "[xDnsServerAddress]DnsServerAddress"
		}
		WindowsFeature WebServerRole
		{
			Name = "Web-Server"
			Ensure = "Present"
		}
		WindowsFeature WebManagementConsole
		{
			Name = "Web-Mgmt-Console"
			Ensure = "Present"
		}
		WindowsFeature WebManagementService
		{
			Name = "Web-Mgmt-Service"
			Ensure = "Present"
		}
		WindowsFeature HTTPRedirection
		{
			Name = "Web-Http-Redirect"
			Ensure = "Present"
		}
		WindowsFeature CustomLogging
		{
			Name = "Web-Custom-Logging"
			Ensure = "Present"
		}
		WindowsFeature LogginTools
		{
			Name = "Web-Log-Libraries"
			Ensure = "Present"
		}
		WindowsFeature RequestMonitor
		{
			Name = "Web-Request-Monitor"
			Ensure = "Present"
		}
		WindowsFeature Tracing
		{
			Name = "Web-Http-Tracing"
			Ensure = "Present"
		}
		WindowsFeature BasicAuthentication
		{
			Name = "Web-Basic-Auth"
			Ensure = "Present"
		}
		WindowsFeature WindowsAuthentication
		{
			Name = "Web-Windows-Auth"
			Ensure = "Present"
		}
		script CreateIISshare
		{
			TestScript = {
				return $false
			}
			SetScript ={
				$uri = $using:createShareWebhook
				$headers = @{"From"="ARM Deployement"}
				$params  = @{ ResourceGroupName=$using:ResourceGroupName;shareName="iis"}
				$body = ConvertTo-Json -InputObject $params
				$response = Invoke-RestMethod -Method Post -Uri $using:createShareWebhook -Headers $headers -Body $body
				return $true
			}
			GetScript = {@{Result = "CreateIISshare"}}
			DependsOn = "[xDefaultGatewayAddress]Gateway","[xDnsServerAddress]DnsServerAddress","[Script]DMZForwarder"
		}
		
		Script DownloadPFX
		{
			TestScript = {
				Test-Path "C:\WindowsAzure\certificate.pfx"
			}
			SetScript ={
				$source = $using:CertificateBlob
				$dest = "C:\WindowsAzure\certificate.pfx"
				Invoke-WebRequest $source -OutFile $dest
			}
			GetScript = {@{Result = "DownloadPFX"}}
			DependsOn = "[WindowsFeature]WebServerRole","[xDefaultGatewayAddress]Gateway","[xDnsServerAddress]DnsServerAddress","[Script]DMZForwarder"
		}

		xPfxImport importCert
		{
			Thumbprint = 'fab3bab3936c06a2601ce7bf4436674ce2d805b6'
			Path = 'C:\WindowsAzure\certificate.pfx'
			Location = 'LocalMachine'
			Store = 'WebHosting'
			Exportable = $false
			Credential = $psCredentialCert
			DependsOn = "[Script]DownloadPFX"
		}
		Script DownloadWebDeploy
		{
			TestScript = {
				Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
			}
			SetScript ={
				$source = "http://download.microsoft.com/download/A/5/0/A502BE57-7848-42B8-97D5-DEB2069E2B05/WebDeploy_amd64_en-US.msi"
				$dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
				Invoke-WebRequest $source -OutFile $dest
			}
			GetScript = {@{Result = "DownloadWebDeploy"}}
			DependsOn = "[WindowsFeature]WebServerRole","[xDefaultGatewayAddress]Gateway","[xDnsServerAddress]DnsServerAddress","[Script]DMZForwarder"
		}
		Package InstallWebDeploy
		{
			Ensure = "Present"  
			Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
			Name = "Microsoft Web Deploy 3.6 Beta"
			ProductId = "{50638DB8-30CE-4713-8EA0-6AA405740391}"
			Arguments = "ADDLOCAL=ALL REBOOT=ReallySuppress"
			DependsOn = "[Script]DownloadWebDeploy"
		}
		Service StartWebDeploy
		{                    
			Name = "WMSVC"
			StartupType = "Automatic"
			State = "Running"
			DependsOn = "[Package]InstallWebDeploy"
		}
		Script DownloadWebPi
		{
			TestScript = {
				Test-Path "C:\WindowsAzure\WebPlatformInstaller_amd64_en-US.msi"
			}
			SetScript ={
				$source = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
				$dest = "C:\WindowsAzure\WebPlatformInstaller_amd64_en-US.msi"
				Invoke-WebRequest $source -OutFile $dest
			}
			GetScript = {@{Result = "DownloadWebPi"}}
			DependsOn = "[Service]StartWebDeploy"
		}
		Package InstallWebPi
		{
			Ensure = "Present"
			Path = "C:\WindowsAzure\WebPlatformInstaller_amd64_en-US.msi"
			Name = "Microsoft Web Platform Installer 5.0"
			ProductId = '4D84C195-86F0-4B34-8FDE-4A17EB41306A'
			Arguments = 'REBOOT=ReallySuppress'
			DependsOn = "[Script]DownloadWebPi"
		}

		Package InstallARR
		{
			Ensure = "Present"
			Path = "c:\Program Files\Microsoft\Web Platform Installer\WebPiCmd-x64.exe"
			Name = "Application Request Routing 3.0"
			ProductId = '279B4CB0-A213-4F94-B224-19D6F5C59942'
			Arguments = "/install /accepteula /Products:ARRv3_0 /SuppressReboot"
			DependsOn = "[Package]InstallWebPi"
		}

		Script DownloadSharedConfig
		{
			TestScript = {
				Test-Path "C:\WindowsAzure\ShareConfig.zip"
			}
			SetScript ={
				$source = "https://inframgmt.blob.core.windows.net/rpx/iisSharedConfig.zip"
				$dest = "C:\WindowsAzure\ShareConfig.zip"
				Invoke-WebRequest $source -OutFile $dest
			}
			GetScript = {@{Result = "DownloadSharedConfig"}}
			DependsOn = "[Package]InstallARR"
		}

		Archive unzipSharedConfig {
			Ensure = "Present"
			Path = "C:\WindowsAzure\ShareConfig.zip"
			Destination = "C:\WindowsAzure\ShareConfig"
			DependsOn = "[Script]DownloadSharedConfig"
		}

		Script RunSharedConfig
		{
			TestScript = {
				Test-Path "C:\WindowsAzure\sharedConfig.done"
			}
			SetScript ={
				C:\WindowsAzure\ShareConfig\iisSharedConfig.ps1 -uncCredentials $using:psCredentialSTG
			}
			GetScript = {@{Result = "DownloadSharedConfig"}}
			DependsOn = "[Archive]unzipSharedConfig"
		}


		xPendingReboot PostTest
		{
            Name = "Check for a pending reboot after changing everything"
			DependsOn = "[Script]RunSharedConfig"
        }
	}
}