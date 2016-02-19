Configuration Main
{

Param ( [string] $nodeName, [string]$IPAddress )

Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking

Node $nodeName
  {
	LocalConfigurationManager            
    {            
        ActionAfterReboot = 'ContinueConfiguration'            
        ConfigurationMode = 'ApplyOnly'            
        RebootNodeIfNeeded = $true            
    }
	xIPAddress FixedIPAddress 
    { 
        Address        = $IPAddress 
        InterfaceAlias = 'Ethernet'
        AddressFamily  = 'IPv4'
    }
    WindowsFeature DNS
    {
		Name = "DNS"
		Ensure = "Present"		
		DependsOn = "[xIPAddress]FixedIPAddress"
    }
	xDnsServerAddress DnsServerAddress 
    { 
        Address        = '127.0.0.1' 
        InterfaceAlias = 'Ethernet'
        AddressFamily  = 'IPv4'
        DependsOn = "[WindowsFeature]DNS"
    }
  }
}