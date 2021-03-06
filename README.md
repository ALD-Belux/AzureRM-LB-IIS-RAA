# AzureRM-LB-IIS-RAA

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/ALD-Belux/AzureRM-LB-IIS-RAA/master/RPX-Pub/Templates/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

Deploy an Azure Resource Manager Template with in a load balancing with IIS and Routing Application Request (RAA)

![Blueprint](RPXBluePrint.png)

## Prerequisites
To be able to automate the Azure File Share creation we need to first create an Azure Automation with a webhook based on  [CreateFileShare.ps1](RPX-Pub/Scripts/CreateFileShare.ps1)

## Deployement
There are three major components to achieve the result:

1. The [json template](RPX-Pub/Templates/azuredeploy.json) deploy all the azure resources except the Azure File Share
2. The [Azure Automation webhook](RPX-Pub/Scripts/CreateFileShare.ps1) deploy the Azure File Share
3. The [DSC template](RPX-Pub/DSC/DSCExtConfiguration.ps1) trigger the webhook, deploy IIS, DNS (forward to on premise DNS), RAA and IIS shared configuration

