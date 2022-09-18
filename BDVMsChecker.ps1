<#
    .SYNOPSIS
    Lists IDs of active VMs into table storage and send it by e-mail.

    .DESCRIPTION
    This time-triggered Azure script automatically checks active VMs among set of subscriptions user has access to.
    List of active VMs is CSV formatted and saved in separate table storage row for each particular subscription.
    Active VMs list is also sent by e-mail using SendGrid API.
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
    Version:    1.1
    Author:     B.Dylik
    Date:       17.09.2022

    .LINKS
    Useful documentation:
    https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=in-process&pivots=programming-language-powershell
    https://en.wikipedia.org/wiki/Cron
    https://docs.microsoft.com/pl-pl/rest/api/compute/virtual-machines
    https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/
    https://docs.sendgrid.com/for-developers/partners/microsoft-azure-2021
    https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal#environment-variables
#>

# Input bindings are passed in via param block
param($Timer)

# Definition of the function saving data to Azure Table Storage
function SaveToTableStorage {
    param (
        [Parameter(Mandatory = $true)]
        [string] $subscription,
        [Parameter(Mandatory = $true)]
        [string] $payload
    )

    # Get current date
    $currentDate = Get-Date -format "dd.MM.yyyy, HH:mm"

    # Create new row in the table and save data into storage account table
    try {
        Add-AzTableRow -Table $cloudTable -PartitionKey $subscription -RowKey $currentDate -property @{"ActiveVMs" = "<$payload>" } -ErrorAction Stop
        Write-Information "Data saved successfully."
    }
    catch {
        $message = $_.Exception.Message
        Write-Error ("Saving data to storage account table failed: " + $message)
        Break
    }
}

# Definition of the function sending e-mail using SendGrid API
function SendEmail {
    param (
        [Parameter(Mandatory = $true)]
        [string] $subscription,
        [Parameter(Mandatory = $true)]
        [string] $payload,
        [Parameter(Mandatory = $true)]
        [string] $destEmailAddress
    )

    # Get current date
    $currentDate = Get-Date -format "dd.MM.yyyy, HH:mm"

    # Build the SendGrid API request header using API key stored as an app environmental variable
    $requestHeader = @{
        'Authorization' = 'Bearer ' + $env:APIkey
        'Content-Type'  = 'application/json'
    }

    # Build the SendGrid API request body
    $requestBody = @{
        personalizations = @(
            @{
                "to"      = @(
                    @{
                        "email" = "$destEmailAddress"
                    }
                )
                "subject" = "Active Azure VMs in $subscription"
            }
        )
        from             = @{
            "email" = "bdvmscheckerproject@gmail.com"
        }
        content          = @(
            @{
            "type"  = "text/plain"
            "value" = "Subscription: $subscription `nDate: $currentDate `nActive VMs: $payload"
            }
        )
    }

    # Convert request body to JSON format
    $requestBodyJson = $requestBody | ConvertTo-Json -Depth 4

    # Send the e-mail calling SendGrid API
    try {
        Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" -Method POST -Headers $requestHeader -Body $requestBodyJson
        Write-Information "HTTP request sent successfully."
    }
    catch {
        $message = $_.Exception.message
        Write-Error ("Sending HTTP request failed: " + $message)
        Break
    }
}

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled
if ($Timer.IsPastDue) {
    Write-Information "PowerShell timer is running late!"
}

# Write an information log with the current time
Write-Information "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Get storage account and table context
$ctx = Get-AzStorageAccount -Name bdvmschecker -ResourceGroupName BDVMsChecker | Select-Object -ExpandProperty Context
$cloudTable = (Get-AzStorageTable -Name ActiveVMs -Context $ctx).CloudTable

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

    # Generate proper output (listing in CSV format)
    if ($VMsList.Count -gt 0) {
        $payload = $VMsList -join ","
    }
    else {
        $payload = "No active VMs"
    }

    # Save data to Table Storage
    SavetoTableStorage -subscription $sub -payload $payload

    # Send data by e-mail
    SendEmail -subscription $sub -payload $payload -destEmailAddress "bartek.dylik@gmail.com"
}