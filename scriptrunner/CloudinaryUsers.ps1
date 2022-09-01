<#
    .SYNOPSIS
    Checks if there has been any change on Cloudinary AD group (a-noe-Cloudinary-user) and updates the cloudinary account accordingly:
    
    .DESCRIPTION
    Checks if there has been any change on Cloudinary AD group (a-noe-Cloudinary-user) and updates the cloudinary account accordingly.

    User removed from AD group or disabled (previous run enabled):
        Disable user on Cloudinary
    User added to AD group or enabled (previous run disabled): 
        If user already exists on Cloudinary: Enable user on Cloudinary
    User no longer exists on AD:
        Delete user on Cloudinary and notify damsupport@nintendo.de
        
    Writes the members of the AD group to a csv waiting for next run

    Modifying random comment here
    
    .PARAMETER Credentials
        [APICredentials] Credentials for the API
        [Environment] Cloudinary environment to provision users

#>

[CmdletBinding()]
Param
(

    [Parameter(
        Position = 10,
        Mandatory = $true,
        HelpMessage = "Credentials for API"
    )]
    [pscredential]$APICredentials,

    [Parameter(
        Position = 10,
        Mandatory = $true,
        HelpMessage = "Cloudinary environment for user provisioning"
    )]
    [pscredential]$Environment

)
$ACCOUNT_ID = $Environment.GetNetworkCredential().Password
$credential = $APICredentials


[string[]]$groupWatched = "a-noe-Cloudinary-user"


$global:result = ""

function getUserID{
    [CmdletBinding()]
    param (
        [String]$DisplayName,
        [String]$Email
    )
    $finalID = "0000"
    $headers=@{}
    $headers.Add("user-agent", "vscode-restclient")
    $headers.Add("Content-Type", "application/json; charset=utf-8")
    #SET PREFIX TO NAME (whatever...)
    $postparams=@{}
    $postparams.Add("prefix", ($DisplayName.Split(" "))[0])
    #PARSE ALL USERS FROM JSON
    $URI = "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/"
    $response = Invoke-RestMethod -Uri $URI -Method GET -Headers $headers -Credential $credential -Body $postparams 
    #Write-Output $response.users
    if($response.users){
        foreach($user in $response.users){
            if($Email -eq $user.email){
                #Write-Output "Email matched: $Email"
                $finalID = $user.id
            }
        }       
    } else{
        #Write-Error "User not found. Returning ID: 0000"
    }
    return $finalID
}

function disableUser{
    param
    (
        [string]$samAccountName,
        [string]$Email,
        [string]$DisplayName
    )
        Write-Output "Disabling user ${samAccountName}. Email: ${email}. DisplayName: ${DisplayName}"
    $headers=@{}
    $headers.Add("user-agent", "vscode-restclient")
    $headers.Add("Content-Type", "application/json; charset=utf-8")
    Write-Output "Getting user ID for: ${DisplayName}. Email: ${email}"
    $userID = getUserID $DisplayName $Email
    if ($userID -eq "0000"){
        Write-Output "User not found on Cloudinary. Skipping user disable"
    } else{
        $putParams = '{"enabled": "false"}'
        $URI =  "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/${userID}"
        Write-Output "Sending WebRequest to $URI"
        Write-Output $putParams | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $URI -Method PUT -Headers $headers -Credential $credential -Body $putParams -ContentType 'application/json; charset=utf-8'
        $enabled = $response.enabled
        Write-Output "User $samAccountName enabled=${enabled}"
        $global:result += "`nUser disabled: $samAccountName $Email"
    }
}


function enableUser{
    param
    (
        [string]$samAccountName,
        [string]$Email,
        [string]$DisplayName
    )
    Write-Output "Checking if user ${samAccountName}. Email: ${email}. DisplayName: ${DisplayName} Already exists"
    $headers=@{}
    $headers.Add("user-agent", "vscode-restclient")
    $headers.Add("Content-Type", "application/json; charset=utf-8")
    $userID = getUserID $DisplayName $Email
    if ($userID -eq "0000"){
        Write-Output "User not found on Cloudinary. Skipping user enable"
    } else{
        Write-Output "User $samAccountName already exists. ID: $userID"
        Write-Output "Enabling user"
        $putParams = '{"enabled": "true"}'
        $URI =  "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/${userID}"
        Write-Output "Sending WebRequest to $URI"
        Write-Output $putParams | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $URI -Method PUT -Headers $headers -Credential $credential -Body $putParams -ContentType 'application/json; charset=utf-8'
        $enabled = $response.enabled
        Write-Output "User $samAccountName enabled=${enabled}"
        $global:result += "`nUser enabled: $samAccountName $Email"
    }
}

function deleteUser{	
    param	
    (	
        [string]$samAccountName,	
        [string]$Email,	
        [string]$DisplayName	
    )	
    Write-Output "Checking if user ${samAccountName}. Email: ${email}. DisplayName: ${DisplayName} Already exists"	
    $headers=@{}	
    $headers.Add("user-agent", "vscode-restclient")	
    $headers.Add("Content-Type", "application/json; charset=utf-8")	
    $userID = getUserID $DisplayName $Email	
    if ($userID -eq "0000"){	
        Write-Output "User not found on cloudinary. Skipping user deletion"	
    } else{	
        Write-Output "User $samAccountName found. ID: $userID. Deleting"	
        $URI =  "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/${userID}"	
        Write-Output "Sending WebRequest to $URI"	
        $response = Invoke-RestMethod -Uri $URI -Method DELETE -Headers $headers -Credential $credential -Body $putParams -ContentType 'application/json; charset=utf-8'	
        $message = $response.message	
        if ($message -eq "ok"){	
            Write-Output "User $samAccountName deleted from Cloudinary"	
            $global:result += "`nUser deleted: $samAccountName $Email"	
            sendEmailUserDeleted $samAccountName $Email $DisplayName	
        } else {	
            Write-Output "User $samAccountName not deleted from Cloudinary"	
        }	
    }	
}	
    
function sendEmailUserDeleted{	
    param	
    (	
        [string]$samAccountName,	
        [string]$Email,	
        [string]$DisplayName	
    )	
    $Server = "int-mail.nintendo.de"	
    $Port = 25	
    $Subject = "User $samAccountName deleted from Cloudinary"	
    $Body = "The user $samAccountName ($DisplayName - $Email) has been deleted from Cloudinary. Please check that this is correct and contact EAM team (noe-itio-eam@nintendo.de) if not."	
    $SSender = "cloudinary-provisioning@nintendo.de" 	
    $Recipient = @("eduardo.martinez@nintendo.es","eduardo.martinez@nintendo.de")
    $SMTPClient = New-Object Net.Mail.SmtpClient($Server, $Port)	
    
    try {	
        Write-Output "Sending message..."	
        $SMTPClient.Send($SSender, $Recipient, $Subject, $Body)	
        Write-Output "Message successfully sent to $($Recipient)"	
    } catch [System.Exception] {	
        Write-Output "An error occurred:"	
        Write-Error $_	
    }	
    
}

# SCRIPT START

foreach($group in $groupWatched){
    $lastUsersFile = "$group`.csv"
    $currentUsersFile = "$group`.current`.csv"
    $global:result += "`nGroup $group"
    $AdGroup = Get-ADGroup $group
    if(!(Test-Path -Path $lastUsersFile -PathType leaf)){
        Write-Output "${lastUsersFile} Not present, creating file and skipping"
        Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName, Enabled | Select-Object SamAccountName, EmailAddress, DisplayName, Enabled | export-csv -path $lastUsersFile -Encoding UTF8
        Write-Output "File created in $lastUsersFile"
        $global:result += "`n$lastUsersFile not present, file created"
    } else{
        Write-Output "Found file $lastUsersFile"
        $lastRunUsers = Import-Csv $lastUsersFile
        Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName, Enabled | Select-Object SamAccountName, EmailAddress, DisplayName, Enabled | Export-Csv -Path $currentUsersFile -Encoding UTF8
        $currentUsers = Import-Csv $currentUsersFile

        Write-Output "`n============`nUsers DELETED from group $group"
        $deletedUsers = Compare-Object -DifferenceObject $currentUsers -ReferenceObject $lastRunUsers -Property SamAccountName, EmailAddress, DisplayName, Enabled | Where-Object SideIndicator -eq "<=" | Select-Object SamAccountName, EmailAddress, DisplayName, Enabled
        Write-Output $deletedUsers

        if ($deletedUsers){
        Write-Output "`nDisabling Users"
            foreach ($user in $deletedUsers) {
                try{
                    disableUser $user.SamAccountName $user.EmailAddress $user.DisplayName
                } catch {
                    Write-Output "`nError disabling $user"
                    Write-Output $_
                }
                try{	
                    Get-ADUser $user.SamAccountName	
                } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{	
                    Write-Output "`nUser $($user.SamAccountName) not found on AD. Deleting on cloudinary"	
                    deleteUser $user.SamAccountName $user.EmailAddress $user.DisplayName	
                }
            }
        } else {
            Write-Output "No users removed from $group"
        }

        Write-Output "`n============`nUsers ADDED to group $group"
        $addedUsers = Compare-Object -DifferenceObject $currentUsers -ReferenceObject $lastRunUsers -Property SamAccountName, EmailAddress, DisplayName, Enabled | Where-Object SideIndicator -eq "=>" | Select-Object SamAccountName, EmailAddress, DisplayName, Enabled
        Write-Output $addedUsers
        if ($addedUsers){
        Write-Output "`nEnabling Users"
            foreach ($user in $addedUsers) {
                if($user.Enabled = $true){
                    try{
                        enableUser $user.SamAccountName $user.EmailAddress $user.DisplayName
                    } catch {
                        Write-Output "`nError enabling $user"
                        Write-Output $_
                    }
                }
            }
        } else{
            Write-Output "No users added to $groupWatched"
        }
    }
    Write-Output "Finished with $group"
    ## Export current user group for next run
    Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName, Enabled | Select-Object SamAccountName, EmailAddress, DisplayName, Enabled | export-csv -path $lastUsersFile -Encoding UTF8
    Remove-Item -Path $currentUsersFile
    $global:result += "`nUpdated $lastUsersFile`n======================"
}
$SRXEnv.ResultMessage = $global:result