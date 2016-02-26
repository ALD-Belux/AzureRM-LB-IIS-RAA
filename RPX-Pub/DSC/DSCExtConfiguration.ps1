Configuration Main
{
	Param 
	( 
		[string] $nodeName,
		[System.Management.Automation.PSCredential]$storageCreds,
		[string] $IPAddress,
		[string] $netmask,
		[string] $gateway
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking, xPSDesiredStateConfiguration

	$psCredentialSTG = New-Object System.Management.Automation.PSCredential ("$($storageCreds.UserName)", $storageCreds.Password)

	Node localhost
	{
		LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
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
		xDhcpClient EnableDhcpClient
		{
			State          = 'Disabled'
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
		}
		xIPAddress FixedIPAddress 
		{ 
			IPAddress      = $IPAddress 
			SubnetMask     = $netMask
			InterfaceAlias = 'Ethernet'
			AddressFamily  = 'IPv4'
			DependsOn = "[xDhcpClient]EnableDhcpClient"
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
			DependsOn = "[xIPAddress]FixedIPAddress","[xDhcpClient]EnableDhcpClient","[xDefaultGatewayAddress]Gateway"
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
					if($zone.ZoneName -eq $dmzDnsZone ) {return $true}
				}
				return $false
			}
			SetScript = {
				Add-DnsServerConditionalForwarderZone -name $dmzDnsZone -MasterServers $dmzDnsIP
			}
			GetScript ={@{Result = "DMZForwarder"}}

			DependsOn = "[WindowsFeature]DNS"
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
			DependsOn = "[WindowsFeature]WebServerRole","[xIPAddress]FixedIPAddress","[xDhcpClient]EnableDhcpClient","[xDefaultGatewayAddress]Gateway"
		}
		Package InstallWebDeploy
		{
			Ensure = "Present"  
			Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
			Name = "Microsoft Web Deploy 3.6 Beta"
			ProductId = "{50638DB8-30CE-4713-8EA0-6AA405740391}"
			Arguments = "ADDLOCAL=ALL"
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
			Arguments = ''
			DependsOn = "[Script]DownloadWebPi"
		}

		Package InstallARR
		{
			Ensure = "Present"
			Path = "c:\Program Files\Microsoft\Web Platform Installer\WebPiCmd-x64.exe"
			Name = "Application Request Routing 3.0"
			ProductId = '279B4CB0-A213-4F94-B224-19D6F5C59942'
			Arguments = "/install /accepteula /Products:ARRv3_0"
			DependsOn = "[Package]InstallWebPi"
		}
	}
}