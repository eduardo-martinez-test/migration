<#
    .SYNOPSIS
    Add Azure AD users to Azure AD groups

    .DESCRIPTION
    Add users to groups in Azure AD. User mail is used to search for users and the values must must match the displayname for users and groups.

    .PARAMETER EmailAddress
        [mailaddress[]] Users to add to the group
    .PARAMETER Groups
        [AADgroups[]] Groups that the users will be added to
    .PARAMETER O365Credentials
        [pscredential] Credentials for Connect-AzureAD

#>

[CmdletBinding()]
[OutputType([int])]
Param
(
    [Parameter(
        Position = 5,
        Mandatory = $true,
        HelpMessage = "Enter a list of USER emails to add to group (comma separated)"
    )]
    [mailaddress[]]$EmailAddress,

    [Parameter(
        Position = 5,
        Mandatory = $true,
        HelpMessage = "Enter a list of GROUPS to add the user to (comma separated)"
    )]
    [String[]]$groups,

    
    [Parameter(
        Position = 80,
        Mandatory = $true,
        HelpMessage = "Credentials for Connect-AzureAD"
    )]
    [pscredential]$O365Credentials

)

Write-Output "[$(Get-Date -Format s)] Initializing Connections."
# Connect AAD
Write-Output "[$(Get-Date -Format s)] Connecting to AzureAD."
Connect-AzureAD -Credential $O365Credentials | Out-Null

$Out = ""

Write-Output "[$(Get-Date -Format s)] Adding users"

foreach ($user in $EmailAddress) {
    $AADuser = get-azureaduser -all $true -Filter "mail eq '$user'"
    if($AADuser){
        $Out+= "`nAdded user $user to groups:"
        foreach($group in $groups){
            if ($group -eq "a-AAD-NOE-Cloudinary-User"){  # TEMPORARY ONLY ALLOW CLOUDINARY GROUP
                $AADgroup = Get-AzureADGroup -all $true -Filter "displayname eq '$group'"
                try{
                Add-AzureADGroupMember -ObjectId $($AADgroup.ObjectId) -RefObjectId $($AADuser.ObjectId)
                Write-Output "[$(Get-Date -Format s)] Added user $($AADuser.DisplayName) ($($AADuser.ObjectId)) to group: $($AADgroup.DisplayName) ($($AADgroup.ObjectId))"
                $Out+= "`n- $group"
                } catch {
                    Write-Output "[$(Get-Date -Format s)] ERROR adding $($AADuser.DisplayName) ($($AADuser.ObjectId)) to group: $($AADgroup.DisplayName) ($($AADgroup.ObjectId))"
                }
            }            
        }
    } else {
        $Out+= "`nUser $user NOT FOUND"
    }
}

foreach($group in $groups){
    $AADgroup = Get-AzureADGroup -all $true -Filter "displayname eq '$group'"
    if($null -eq $AADgroup){
        $Out+= "`nGroup $group NOT FOUND"
    } else{
        if ($group -ne "Cloudinary-User"){ #TEMPORARY ONLY ALLOW CLOUDINARY GROUP
            $Out+= "`nGroup $group currently not supported by script."
        }
    }
}

if ($SRXEnv) {
    $SRXEnv.ResultMessage = $Out
}
else {
    Write-Output $Out
}