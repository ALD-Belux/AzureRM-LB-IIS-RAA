#
# iisSharedConfig.ps1
#
# Source: http://byronpate.com/2014/09/script-iis-shared-configuration/
#
param (
    [PSCredential]$uncCredentials
)

$StorageAccountName = $uncCredentials.UserName

$iisShare = "\\" + $StorageAccountName + ".file.core.windows.net\iis"
[PSCredential] $psCredentialDrive = New-Object System.Management.Automation.PSCredential("$($uncCredentials.UserName)",$uncCredentials.Password)

#### Variables ####
$iisWASKey = "iisWASKey"
$iisConfigKey = "iisConfigurationKey"
$absPath = "\config"
$UNCPath = $iisShare + $absPath

$marshal = [System.Runtime.InteropServices.Marshal]
$ptr = $marshal::SecureStringToBSTR( $psCredentialDrive.Password )
$uncPwd = $marshal::PtrToStringBSTR( $ptr )
$marshal::ZeroFreeBSTR( $ptr )

function Compare-Key($KeyName)
{
    $myConfigkey = Join-Path $env:temp $KeyName
    $remotekeyPath = Join-Path $UNCPath $KeyName
 
    & $env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -px $KeyName $myConfigkey -pri 
 
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

if(!(Test-Path "C:\WindowsAzure\sharedConfig.done")){

  #### Load Web Administration DLL ####
  [System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll") | Out-Null
  $serverManager = New-Object Microsoft.Web.Administration.ServerManager
  $config = $serverManager.GetRedirectionConfiguration()
  $redirectionSection = $config.GetSection("configurationRedirection")

  New-PSDrive -Name iisShare -Credential $psCredentialDrive -PSProvider FileSystem -Root $iisShare

  if (Test-Path $("iisShare:\\" + $absPath)){
    # Shared config Exist
    # Import iisWASKey if needed
    if (Compare-Key $iisWASKey )
    { Write-Verbose "$iisWASKey Check: In sync with Farm"}else
    {
        Write-Verbose "$iisWASKey Check: NOT in sync with Farm, updating..."
        $wasKey = Join-Path $UNCPath $iisWASKey
        & $env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -pi $iisWASKey $wasKey -exp
    }
 
    # Import iisConfigKey if needed
    if (Compare-Key $iisConfigKey  )
    { Write-Verbose "$iisConfigKey Check: In sync with Farm"}else
    {
        Write-Verbose "$iisConfigKey Check: NOT in sync with Farm, updating..."
        $configKey = Join-Path $UNCPath $iisConfigKey
        & $env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -pi $iisConfigKey $configKey -exp
    }
 
    # Update Shared Config Settings
    $redirectionSection.Attributes["enabled"].Value = "true"
    $redirectionSection.Attributes["path"].Value = $UNCPath
    $redirectionSection.Attributes["userName"].Value = $psCredentialDrive.UserName
    $redirectionSection.Attributes["password"].Value = $uncPwd
    $serverManager.CommitChanges()
    Write-Verbose ""
    Write-Verbose "Shared Configuration Enabled using $uncpath"

  } else {

    New-Item -ItemType Directory -Path $("iisShare:\\" + $absPath)
    ### Copy applicationHost.config
        $appConfig = Join-Path $UNCPath "applicationHost.config"
        cpi $env:windir\system32\inetsrv\config\applicationHost.config $appConfig
 
        ### Copy administration.config
        $adminConfig = Join-Path $UNCPath "administration.config"
        cpi $env:windir\system32\inetsrv\config\administration.config $adminConfig
 
        ### Export Keys
        $wasKey = Join-Path $UNCPath $iisWASKey
        & $env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -px $iisWASKey $wasKey -pri 
 
        $ConfigKey = Join-Path $UNCPath $iisConfigKey
        & $env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -px $iisConfigKey $ConfigKey -pri

        # Update Shared Config Settings
        $redirectionSection.Attributes["enabled"].Value = "true"
        $redirectionSection.Attributes["path"].Value = $UNCPath
        $redirectionSection.Attributes["userName"].Value = $psCredentialDrive.UserName
        $redirectionSection.Attributes["password"].Value = $uncPwd
        $serverManager.CommitChanges()
        Write-Verbose ""
        Write-Verbose "Shared Configuration Enabled using $uncpath"

  }

}