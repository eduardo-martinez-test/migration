foreach ($user in Get-Content .\usersaad2.txt){
    $result = Get-AzureADUser -SearchString "$user"
    if($result){
        Write-Output "`nUser $user added to group"
        Add-AzureADGroupMember -ObjectId "d8547cc4-1ea0-47e8-a139-07fbb151afc3" -RefObjectId "$($result.ObjectId)"
    }
}