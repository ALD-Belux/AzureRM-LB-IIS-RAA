#
# iisSharedConfig.ps1
#
# Source: http://byronpate.com/2014/09/script-iis-shared-configuration/
#
param (
    [Parameter(Mandatory=$false)]
    [String]$Action="List",
    [Parameter(Mandatory=$false)]
    [String]$UNCPath,
    [Parameter(Mandatory=$false)]
    [String]$uncUser,
    [Parameter(Mandatory=$false)]
    [String]$uncPassword
)
 
Write-Verbose "IIS Shared Configuration Manager"
 
#### Variables ####
$iisWASKey = "iisWASKey"
$iisConfigKey = "iisConfigurationKey"
$script:uncUser = $uncUser
$script:uncPwd = $uncPassword
 
#### Load Web Administration DLL ####
[System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll") | Out-Null
$serverManager = New-Object Microsoft.Web.Administration.ServerManager
$config = $serverManager.GetRedirectionConfiguration()
$redirectionSection = $config.GetSection("configurationRedirection")
 
function Check-UNC()
{
    if (!($UNCPath))
    { Write-Verbose "UNC Path for Shared Config is required."; exit;}
}
 
function Check-User()
{
    if (!($script:uncUser))
    {
        $script:uncUser = Read-Host "Enter UNC Service Account"
    }
 
    if (!($script:uncPwd))
    {
        $sstr = Read-Host "Enter UNC Service Account Password" -AsSecureString
        $marshal = [System.Runtime.InteropServices.Marshal]
        $ptr = $marshal::SecureStringToBSTR( $sstr )
        $script:uncPwd = $marshal::PtrToStringBSTR( $ptr )
        $marshal::ZeroFreeBSTR( $ptr )
    }
}
 
function Compare-Key($KeyName)
{
    $myConfigkey = Join-Path $env:temp $KeyName
    $remotekeyPath = Join-Path $UNCPath $KeyName
 
    & $env:windir\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -px $KeyName $myConfigkey -pri 
 
    if (!(Test-Path $myConfigkey ))
    {
        Write-Verbose "Could not export $KeyName. Check for any issues exporting Keys"
        return $false
    }
 
    $key1 = Get-Content $remotekeyPath
    $key2 = Get-Content $myConfigkey
 
    if (Compare-Object $key1 $key2)
    {
        return $false
    }else
    {
        return $true
    }
}
 
switch ($Action)
{
    "List" {
        Write-Host "Current Shared Configuration Setup"
        Write-Host ""
        if ($redirectionSection.Attributes["enabled"].Value -eq "true")
        {
            Write-Host "Shared Configuration is Enabled"
            Write-Host "Config Path: " $redirectionSection.Attributes["path"].Value
            Write-Host "User Name: " $redirectionSection.Attributes["userName"].Value
 
            $UNCPath = $redirectionSection.Attributes["path"].Value
 
            if (Compare-Key $iisWASKey )
            { Write-Host "$iisWASKey Check: In sync with Farm"}else
            { Write-Host "$iisWASKey Check: NOT in sync with Farm" -ForegroundColor DarkYellow}
 
            if (Compare-Key $iisConfigKey  )
            { Write-Host "$iisConfigKey Check: In sync with Farm"}else
            { Write-Host "$iisConfigKey Check: NOT in sync with Farm" -ForegroundColor DarkYellow}
 
        }else{
 
            Write-Host "Shared Configuration is NOT Enabled"
        }
    }
    "Enable" {
        Write-Verbose "Enabling Shared Configuration"
        Write-Verbose ""
 
        # Ensure UNC was provided
        Check-UNC
 
        # If Service Account isn't hard coded, prompt for it
        Check-User
 
        # Import iisWASKey if needed
        if (Compare-Key $iisWASKey )
        { Write-Verbose "$iisWASKey Check: In sync with Farm"}else
        {
            Write-Verbose "$iisWASKey Check: NOT in sync with Farm, updating..."
            $wasKey = Join-Path $UNCPath $iisWASKey
            & $env:windir\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -pi "iisWasKey" $wasKey -exp
        }
 
        # Import iisConfigKey if needed
        if (Compare-Key $iisConfigKey  )
        { Write-Verbose "$iisConfigKey Check: In sync with Farm"}else
        {
            Write-Verbose "$iisConfigKey Check: NOT in sync with Farm, updating..."
            $configKey = Join-Path $UNCPath $iisConfigKey
            & $env:windir\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -pi $iisConfigKey $configKey -exp
        }
 
        # Update Shared Config Settings
        $redirectionSection.Attributes["enabled"].Value = "true"
        $redirectionSection.Attributes["path"].Value = $UNCPath
        $redirectionSection.Attributes["userName"].Value = $script:uncUser
        $redirectionSection.Attributes["password"].Value = $script:uncPwd
        $serverManager.CommitChanges()
        Write-Verbose ""
        Write-Verbose "Shared Configuration Enabled using $uncpath"
    }
    "Disable" {
        Write-Verbose "Disable Shared Configuration"
        Write-Verbose ""
 
        if ($redirectionSection.Attributes["enabled"].Value -eq "true")
        {
            $redirectionSection.Attributes["enabled"].Value = "false"
            $serverManager.CommitChanges()
 
            Write-Verbose "Shared Configuration Disabled"
        }else
        {
            Write-Verbose "Shared Configuration is NOT Enabled"
        }
    }
    "Export" {
        Write-Verbose "Export Shared Configuration"
        Write-Verbose ""
 
        Check-UNC
 
        ### Copy applicationHost.config
        $appConfig = Join-Path $UNCPath "applicationHost.config"
        cpi $env:windir\system32\inetsrv\config\applicationHost.config $appConfig
 
        ### Copy administration.config
        $adminConfig = Join-Path $UNCPath "administration.config"
        cpi $env:windir\system32\inetsrv\config\administration.config $adminConfig
 
        ### Export Keys
        $wasKey = Join-Path $UNCPath $iisWASKey
        & $env:windir\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -px $iisWASKey $wasKey -pri 
 
        $ConfigKey = Join-Path $UNCPath $iisConfigKey
        & $env:windir\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -px $iisConfigKey $ConfigKey -pri 
 
    }
    default {Write-Verbose "$Action is not a valid action. Exiting. "; exit}
 }
 
Write-Verbose "Exit"  