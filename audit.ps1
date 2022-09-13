# This system audit script is created by dieter [at] secudea [dot] be

$dir="audit_dom_$env:computername"
mkdir $dir 
$path = Resolve-Path $dir
$logfile = "log-$env:computername.txt"
echo "Creation of directories successfull: $dir`n" | Set-content -Path $path\$logfile

echo "Getting system information`n" | Add-Content -Path $path\$logfile
echo "Computer: $env:computername" | Add-Content -Path $path\$logfile
date | Add-Content -Path $path\$logfile
echo "User: $env:USERNAME\$env:USERDOMAIN`n" | Add-Content -Path $path\$logfile 

# Finding domain sid and "domain admins" group name
$DomainSID = (Get-ADDomain).DomainSID
$DomainAdminsSid = New-Object System.Security.Principal.SecurityIdentifier ([System.Security.Principal.WellKnownSidType]::AccountDomainAdminsSid,$DomainSID)
$DomainAdminGroup = Get-ADGroup -Filter {SID -eq $DomainAdminsSid} -Properties Name
$EnterpriseAdminsSid = New-Object System.Security.Principal.SecurityIdentifier ([System.Security.Principal.WellKnownSidType]::AccountEnterpriseAdminsSid,$DomainSID)
$EnterpriseAdminGroup = Get-ADGroup -Filter {SID -eq $EnterpriseAdminsSid} -Properties Name


echo "Extracting Domain Administrator Group Memberships`n" | Add-Content -Path $path\$logfile
Get-ADGroupMember -Identity $DomainAdminGroup -Recursive | export-csv -delimiter "`t" -path $path\domain-admin-group-membership-all_$env:computername.txt -notype
Get-ADGroupMember -Identity $DomainAdminGroup -Recursive | Get-ADUser -Filter {Enabled -eq $true} | export-csv -delimiter "`t" -path $path\domain-admin-group-membership-enabled_$env:computername.txt -notype

echo "Extracting Enterprise Administrator Group Memberships`n" | Add-Content -Path $path\$logfile
Get-ADGroupMember -Identity $EnterpriseAdminGroup -Recursive | export-csv -delimiter "`t" -path $path\enterprise-admin-group-membership-all_$env:computername.txt -notype
Get-ADGroupMember -Identity $EnterpriseAdminGroup -Recursive | Get-ADUser -Filter {Enabled -eq $true} | export-csv -delimiter "`t" -path $path\enterprise-admin-group-membership-enabled_$env:computername.txt -notype


echo "Extracting all group policies`n" | Add-Content -Path $path\$logfile
Get-GPO -all | % { Get-GPOReport -GUID $_.id -ReportType HTML -Path "$path\$($_.displayName).html" }

echo "Extracting GPO Result information`n" | Add-Content -Path $path\$logfile
gpresult.exe /H $path\gpresult_$env:computername.html

echo "saving registry for further analysis`n" | Add-Content -Path $path\$logfile
reg save hklm\system $path\system.sav
reg save hklm\security $path\security.sav
reg save hklm\sam $path\sam.sav
reg export hklm $path\hklm.reg

$compress = @{
Path= "$path\*.sav", "$path\hklm.reg"
CompressionLevel = "Fastest"
DestinationPath = "$path\reg.zip"
}
Compress-Archive @compress
Remove-Item "$path\*.sav"
Remove-Item "$path\hklm.reg"

#invoke ADAudit.ps1
./AdAudit.ps1 -all | Add-Content -Path $path\$logfile

echo "All data has been extracted"