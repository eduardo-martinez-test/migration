<#
    .Synopsis
    Grant permissions to send as on a shared mailbox to a user

    .DESCRIPTION
    Grant permissions to send as on a shared mailbox to a user

    .PARAMETER SharedMailbox
    The Shared mailbox to which the permission wil be granted

    .PARAMETER User
    User which will be granted the send as permission
#>

[CmdletBinding()]
[OutputType([int])]
Param
(
    [Parameter(
        Position = 1,
        Mandatory = $true,
        HelpMessage = "Shared mailbox to which the permission will be granted"
    )]
    [ValidateScript( { $(Get-Recipient -Identity $_ | Measure-Object).count -eq 1 })]
    [string]$SharedMailbox,


    [Parameter(
        Position = 2,
        Mandatory = $true,
        HelpMessage = "User which will be granted the send as permission"
    )]
    [string]$User

)

$mailbox = Get-Recipient -Identity $SharedMailbox
$userToAdd = Get-Recipient $User
Add-ADPermission -Identity $mailbox.DistinguishedName -User $($userToAdd.SamAccountName) -AccessRights 'ExtendedRight' -ExtendedRights 'send as'
