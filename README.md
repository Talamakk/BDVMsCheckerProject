# BDVMsCheckerProject 

## Introduction and Demo
Virtual machines in running state generate costs for all cloud service customers. Therefore, having in mind cost effectiveness, the good practice is to run them only when it's necessary. It's easier to achieve this by developing tools that enables control and automate management over the deployed VMs. BDVMsChecker solution was developed to automate verification of active VMs in different subscriptions among the whole Azure tenant. It's function is to check active VMs at the scheduled time for each subscription and save their IDs into a single table's row in Azure storage account. Azure Functions, Azure ResourceGraph (with KQL query), storage account and PowerShell script enable to automate this task - see [How does it work?](https://github.com/Talamakk/BDVMsChecker#how-does-it-work) section for detailed solution architecture.
This project was made mostly for cloud solutions training purposes so any feedback is more than welcome!


<img src="https://github.com/Talamakk/BDVMsCheckerProject/blob/main/Images/1.jpg" width="700">


## Solution concept and tools
Microsoft Azure has plenty of different tools we can use to automate tasks. This project was built using [Azure Resource Graph](https://docs.microsoft.com/en-us/azure/governance/resource-graph/overview) for getting proper data, [Azure Table Storage](https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-overview) for storing data and
time-triggered [Azure Function](https://docs.microsoft.com/en-us/azure/azure-functions/functions-overview) developed in PowerShell, using [Az PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az) for getting all the automation work.
### Azure Resource Graph
Azure Resource Graph enables quick and effective resources exploration, in the database way with easy filtering, grouping and sorting by using [Kusto Query Language](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/). The main advantages are ability to research among different subscriptions and among different resource providers at single call. Azure Resource Graph is notified by Azure Resource Manager every time any Azure resources is updated. What's more, it regularly scans resource providers for latest updates, so it's always current. 
### Azure Table Storage
Azure Table Storage is the type of storage in storage account that can be used for storing NoSQL data.  
### Azure Functions
Azure Functions is the solution enabling serverless code execution and running apps in Azure cloud environment. 
### Az PowerShell module
This PowerShell module contains cmdlets useful for managing Azure resources via PowerShell. It's imporant to enable this module (and other necessary modules too if needed!) in the function app requirements.

### How does it work?
Once a day at night time-triggered BDVMsCheckerFunction is executed. Initially, it gets the list of subscriptions that account has access to, making possible to research even the whole tenant, what was the requirement for the project. Then, for each subscription, the KQL query is constructed and binded together with subscription ID into JSON. This binding is the payload for HTTP request being send to the Azure Resource Graph endpoint using `Invoke-AzRestMethod` cmdlet (this way of communication was used because of REST API training purposes). Subsequently, active VMs IDs data is collected, formatted into CSV and saved into separate row in the Azure Table. Subscription ID is the PartitionKey and execution time is the RowKey. 


<img src="https://github.com/Talamakk/BDVMsCheckerProject/blob/main/Images/2.jpg" width="700">


## Additional Useful Links for this project
[Time-triggered function](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=in-process&pivots=programming-language-powershell)  
[CRON format expressions](https://en.wikipedia.org/wiki/Cron)  
[Microsoft VM compute REST API](https://docs.microsoft.com/pl-pl/rest/api/compute/virtual-machines)  
[KQL Tutorial](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/tutorial?pivots=azuredataexplorer) 

