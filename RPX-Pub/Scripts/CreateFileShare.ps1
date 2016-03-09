##
#
# To publish on Azure Automation
# Create a webhook
#
##

param (
    [object]$WebhookData
)

# If runbook was called from Webhook, WebhookData will not be null.
if ($WebhookData -ne $null)
{
    # Collect properties of WebhookData
    $WebhookName = $WebhookData.WebhookName
    $WebhookHeaders = $WebhookData.RequestHeader
    $WebhookBody = $WebhookData.RequestBody

    # Collect individual headers. Resource group and share name converted from JSON.
    
    $From = $WebhookHeaders.From
    $params = ConvertFrom-Json -InputObject $WebhookBody
    Write-Output "Runbook started from webhook $WebhookName by $From."
    Write-Output $params

    $ResourceGroupName = $params.ResourceGroupName
    $shareName = $params.shareName
    
    #Use service Account
    Write-Output "[START] Get Azure credential asset"
    $besvcazu_creds = Get-AutomationPSCredential -Name "BE-Azure-Service"
    Write-Output "[DONE] Get Azure credential asset"
    
    Write-Output "[DONE] Login on Azure using " + $besvcazu_creds.UserName
    $login = Login-AzureRmAccount -Credential $besvcazu_creds
    Write-Output "[DONE] Login on Azure using " + $besvcazu_creds.UserName
    
    Write-Output "[START] Get storage account context"
    $stgAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
    $stgAccountName = $stgAccount.StorageAccountName
    $stgAccountKey1 = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $stgAccountName).Key1
    $stgContext = New-AzureStorageContext $stgAccountName $stgAccountKey1
    Write-Output "[DONE] Get storage account context"

    if(!(Get-AzureStorageShare $shareName -Context $stgContext))
    {
        Write-Output "[START] Creating Share"
        New-AzureStorageShare $shareName -Context $stgContext
        Write-Output "[DONE] Creating Share"
    } else {
        Write-Output "[DONE] Share already exist"
    }
}