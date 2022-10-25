using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Get password for the AD user from key vault.
# This function app managed identity was granted access to the secret. If running locally, make sure the signed in user has access to this secret
$ADUserPasswordSecret = 'ADUserPassword'
$KeyVaultPassword = (Get-AzKeyVaultSecret -vaultName $env:keyVaultName -name $ADUserPasswordSecret).SecretValueText

# Create a credential object for the AD user stored in the environment variable $env:ADUser with the key vault password
$ADPassword = ConvertTo-SecureString $KeyVaultPassword -AsPlainText -Force
$ADCredential = New-Object System.Management.Automation.PSCredential($env:ADUser, $ADPassword)

# Script to run with PowerShell.exe
$Script = {
    param (
        $ADCredential
    )
    Import-Module AzureAD
    # Setting TLS1.2 version
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    Connect-AzureAD -Credential $ADCredential | Write-Verbose

    Get-AzureADUser -All $true | select userPrincipalName | where userPrincipalName -ne $null | ConvertTo-Json
}

# Run using PowerShell.exe instead of using PowerShell 6
$ScriptResult = ConvertFrom-Json (&$env:64bitPowerShellPath -WindowStyle Hidden -NonInteractive `
                                        -Command $Script -Args $ADCredential)
# Write out result to console
$ScriptResult

$filePath = '<PathToCsv>/<FileName>.csv'
$url = '<BlobSasUrl>'
Export-Csv $filePath -NoTypeInformation
azcopy copy $filePath $url


# Return results to caller
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = '200'
    Body = $ScriptResult
})
