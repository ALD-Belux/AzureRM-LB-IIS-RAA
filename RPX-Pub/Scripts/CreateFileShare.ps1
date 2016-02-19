#
# CreateFileShare.ps1
#
#Uncomment the following line to log on Azure
#Login-AzureRmAccount

#Resource Group name of the deployement
$rgName = "RPX1-Prod"

$ResourceGroup = Get-AzureRmResourceGroup -Name $rgName
$stgAccount = Get-AzureRmStorageAccount -ResourceGroupName $rgName
$stgAccountName = $stgAccount.StorageAccountName
$stgAccountKey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $rgName -Name $stgAccountName).Key1


$stgContext = New-AzureStorageContext $stgAccountName $stgAccountKey1
$stgShare = New-AzureStorageShare iis -Context $stgContext

$createLocalUserCmd = "net user $stgAccountName $stgAccountKey1 /ADD /PASSWORDCHG:NO /Y"
$pwdNeverExpireUser = 'WMIC USERACCOUNT WHERE "Name=''' + $stgAccountName + '''" SET PasswordExpires=FALSE'
$addUserToGrpCmd = "net localgroup IIS_IUSRS $stgAccountName /ADD"

