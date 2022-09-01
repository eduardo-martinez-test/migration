[string[]]$groupWatched = "a-noe-Cloudinary-user"
#TEST
$API_KEY = 'a73f06a3e05b5b9ee4bc3403997006'
$API_SECRET = 'XTzDwQL1wISKIyjdJ-m1p8rDwDA'
$ACCOUNT_ID = '4dee283b-b1a7-46c1-8841-c8e1e046c956'

$secpasswd = ConvertTo-SecureString $API_SECRET -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($API_KEY, $secpasswd)

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
    $postparams.Add("prefix", $DisplayName)
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
        Write-Output "User not found. Skipping"
    } else{
        $putParams = '{"enabled": "false"}'
        $URI =  "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/${userID}"
        Write-Output "Sending WebRequest to $URI"
        Write-Output $putParams | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $URI -Method PUT -Headers $headers -Credential $credential -Body $putParams -ContentType 'application/json; charset=utf-8'
        $enabled = $response.enabled
        Write-Output "User $samAccountName enabled=${enabled}"
    }
}


function createOrEnableUser{
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
        Write-Output "User not found. Creating user"
        $postparams=@{}
        $postparams.Add("name", $DisplayName)
        $postparams.Add("email", $Email)
        $postparams.Add("role", "media_library_user")
        $json = $postparams | ConvertTo-Json
        $URI =  "https://api.cloudinary.com/v1_1/provisioning/accounts/${ACCOUNT_ID}/users/"
        Write-Output "Sending WebRequest to $URI"
        Write-Output $json
        $response = Invoke-RestMethod -Uri $URI -Method POST -Headers $headers -Credential $credential -Body $json -ContentType 'application/json; charset=utf-8'
        Write-Output $response 
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
    }
}

# SCRIPT START

foreach($group in $groupWatched){
    $lastUsersFile = "$group`.csv"
    $AdGroup = Get-ADGroup $group
    if(!(Test-Path -Path $lastUsersFile -PathType leaf)){
        Write-Output "${lastUsersFile} Not present, creating file and skipping"
        Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName | export-csv -path $lastUsersFile -Encoding UTF8
        Write-Output "File created in $lastUsersFile"
    } else{
        Write-Output "Found file $lastUsersFile"
        $lastRunUsers = Import-Csv $lastUsersFile
        $currentUsers = Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName

        Write-Output "`n============`nUsers DELETED from group $group"
        $deletedUsers = Compare-Object -DifferenceObject $currentUsers -ReferenceObject $lastRunUsers -Property SamAccountName, EmailAddress, DisplayName | Where-Object SideIndicator -eq "<=" | Select-Object SamAccountName, EmailAddress, DisplayName
        Write-Output $deletedUsers
        if ($deletedUsers){
        Write-Output "`nDisabling Users"
            foreach ($user in $deletedUsers) {
                disableUser $user.SamAccountName $user.EmailAddress $user.DisplayName
            }
        } else {
            Write-Output "No users removed from $group"
        }

        Write-Output "`n============`nUsers ADDED to group $group"
        $addedUsers = Compare-Object -DifferenceObject $currentUsers -ReferenceObject $lastRunUsers -Property SamAccountName, EmailAddress, DisplayName | Where-Object SideIndicator -eq "=>" | Select-Object SamAccountName, EmailAddress, DisplayName
        Write-Output $addedUsers
        if ($addedUsers){
        Write-Output "`nCreating or Enabling Users"
            foreach ($user in $addedUsers) {
                createOrEnableUser $user.SamAccountName $user.EmailAddress $user.DisplayName
            }
        } else{
            Write-Output "No users added to $groupWatched"
        }
    }
    Write-Output "Finished with $group"
    ## Export current user group for next run
    Get-ADUser -Filter "memberof -RecursiveMatch '$($AdGRoup)'" -Properties SamAccountName, EmailAddress, DisplayName | export-csv -path $lastUsersFile -Encoding UTF8
}
