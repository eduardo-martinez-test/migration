<#
    .SYNOPSIS
    Get list of distribution lists and shared mailboxes a user is part of
    
    .DESCRIPTION
    Get list of distribution lists and shared mailboxes a user is part of
    
    .PARAMETER Credentials
        [user] AD username to check (eg: )

#>

[CmdletBinding()]
[OutputType([int])]
param(
     [Parameter(Mandatory = $true)]
     [string]$user
)

$Output = "Distribution groups [ $user ] is a member of:`n"
$DistributionGroups= get-adprincipalgroupmembership $user | Get-adgroup -prop mail | Where-Object mail -ne $NULL | Where-Object GroupCategory -eq "Distribution"
foreach($dist in $DistributionGroups){
    $Output += "$($dist.mail)`n"
}
$Output += "`nShared mailboxes [ $user ] has access and permissions:`n"
$mailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited | Get-MailboxPermission -User $user
foreach($mailbox in $mailboxes){
    $mail = Get-Mailbox -Identity $mailbox.Identity
    $Output += "$($mail.PrimarySmtpAddress)`t"
    $Output += "$($mailbox.AccessRights)`n"
}
$SRXEnv.ResultMessage = $Output
