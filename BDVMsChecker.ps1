<#
    .SYNOPSIS
    Lists IDs of active VMs into table storage.

    .DESCRIPTION
    This time-triggered Azure function automatically checks active VMs among set of subscriptions user has access to. 
    List of active VMs is CSV formatted and saved in separate table storage row for each particular subscription.
    For quick and effective resources search, Azure Resource Graph was used.  

    .PARAMETER Timer
    Passed automatically by Azure, allows to schedule function triggering using CRON expression.

    .INPUTS
    All needed parameters passed by Azure.

    .OUTPUTS
    Logging data goes to the output stream.

    .EXAMPLE
    Function not executed manually. 

    .NOTES
    Version:    1.0
    Author:     B.Dylik
    Date:       27.08.2022

    .LINKS  
    Useful documentation:
    https://docs.microsoft.com/en-us/azure/governance/resource-graph/overview
    https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-overview
    https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/
#>

# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Information "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Information "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Get storage account and table context.
$ctx = Get-AzStorageAccount -Name bdvmschecker -ResourceGroupName BDVMsChecker | Select-Object -ExpandProperty Context
$cloudTable = (Get-AzStorageTable -Name ActiveVMs -Context $ctx).CloudTable

# Get current date
$currentDate = Get-Date -format "dd.MM.yyyy, HH:mm"

# Get subscriptions list
$subscriptionList = (Get-AzSubscription).Id

# Get active VMs IDs list and put it into separate table row for each subscription
foreach ($sub in $subscriptionList) {
    
    # Build the KQL query and pack it in JSON along with particular subscription ID
    $queryPayload = @"
    {
        "subscriptions": ["$sub"],
        "query": "Resources | where type == 'microsoft.compute/virtualmachines' `
        | where properties.extended.instanceView.powerState.code contains 'running' | project id"
    } 
"@

    # Send the HTTP request to Resource Graph endpoint and get the data using built query
    $VMsList = [string[]]((Invoke-AzRestMethod -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2020-04-01-preview" `
                -Payload $queryPayload -Method POST).Content | ConvertFrom-Json).data.rows

    # Generate proper information to upload (listing in CSV format)
    if ($VMsList.Count -gt 0) {
        $payload = $VMsList -join ","
    }
    else {
        $payload = "No active VMs"
    }

    # Create new row in the table and save data into storage account table
    try {
        Add-AzTableRow -Table $cloudTable -PartitionKey $sub -RowKey $currentDate -property @{"ActiveVMs" = "<$payload>" } -ErrorAction Stop
        Write-Information "Data saving success."
    }
    catch {
        $message = $_.Exception.Message
        Write-Information "Saving data to storage account table failed. Details below:"
        Write-Information $message
        Break
    }
}