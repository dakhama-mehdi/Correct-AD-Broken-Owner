<#	
   .NOTES
   ===========================================================================
   Version      : 1
   Updated      : Aout, 2022
   Created by   : Dakhama Mehdi
   Contribution : Souin Matthiew
                  Guylaine NGOUDJO
   Organization : 
   Filename:      Caboo-V4
   Tool Name :    Correct-AD-Broken-object-Owner
   ===========================================================================
  .DESCRIPTION
  This script, help to detect broken owners/representing a risk of (user accounts, Computers, Groups and Organizational Units), Based on Microsoft recommandation
  It generates an HTML page, and does not require any module.
  .How to use 
  Must be turned on machine in domain AD
  Lanuched with user from AD (no right admin is required)
  No need module
			
#>

# Test if domain is present, and user can send ldap request

$testdomain = $env:username

$testldap = ([adsisearcher]"(&(objectCategory=User)(samaccountname=$testdomain))").findone()  

if (!$testldap) {

Write-Host 'cannot contact AD domain, or user havent right'
break;

 }

#Get Privilege groups domain for filter


$skipdefaultgroups = $null
$skipdefaultgroups = @()	
$skipdefaultgroups += ([adsisearcher]"(&(groupType:1.2.840.113556.1.4.803:=1)(!(objectSID=S-1-5-32-546))(!(objectSID=S-1-5-32-545)))").findall().Properties.name
$skipdefaultgroups += ([adsisearcher] "(&(objectCategory=group)(admincount=1)(iscriticalsystemobject=*))").FindAll().Properties.name
$varoptionalgroup = [ADSI]("LDAP://" + (([ADSI]"LDAP://RootDSE").schemaNamingContext))
$varoptionalgroup.PsBase.ObjectSecurity.Access.identityreference.value | select -Unique | ForEach-Object {

$skipdefaultgroups += $_.Split("\")[1]
}
# Add groups or objects to skip from result and uncomment the below line 
# Exemple for skip Exchange account, replace only "Exchange" from your user name or groups
# $skipdefaultgroups += Exchange"

#creating arrays that will contain noncompiding objects    
$brokenusers = $Object = $brokenpc = $null
$script:brokenusers = [System.Collections.ArrayList]@() 
$script:brokenpc = [System.Collections.ArrayList]@()
$script:brokengroups = [System.Collections.ArrayList]@()
$script:brokenou = [System.Collections.ArrayList]@()
$script:nbrbrokenusers = $script:NbrsbrokenPC = $script:nbrbrokengroups = $script:nbrscanobject = $script:nbrbrokenou = 0

#Search computer or user from all domain (search from specific OU will be added later)
#You can stop by ctrl+c script any times

#region Menu

do
 {
    Clear-Host
    Write-Host "================ Menu chose method to repair  ================`n" -ForegroundColor Cyan
    
    Write-Host "1: Press '1' for repair all domain." -ForegroundColor Green
    Write-Host "2: Press '2' for repair specific OU.`n"   -ForegroundColor Green
    Write-Host " "

    $selection = Read-Host "Please make a selection"

    switch ($selection)   {

    '1' {  'You chose option #1' 
    $selection = 'q'
    $conditions = ([adsisearcher]"(|(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=8192)))(objectCategory=User)(groupType:1.2.840.113556.1.4.803:=2)(objectCategory=organizationalUnit))").findall().properties
    }
    
    '2' {    
    $Ouname = Read-Host "enter name of OU"

    $OUpath= ([adsisearcher]"(&(objectCategory=organizationalUnit)(ou=$Ouname*))").findall().properties.distinguishedname | Out-GridView -PassThru -Title "Select OU" -ErrorAction Stop 

    if (!$OUpath) {
    Write-Host -ForegroundColor Red "Pls retest OU name not found"`n` 
    pause

    } else {
    $conditions = (New-Object -TypeName adsisearcher -ArgumentList ([adsi] ("LDAP://" + $OUpath), '(|(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=8192)))(objectCategory=User)(groupType:1.2.840.113556.1.4.803:=2)(objectCategory=organizationalUnit))')).FindAll().Properties
    $selection = 'q'
    }

    } default {
      Write-Host "pls chose 1 or 2, and q for quit" -ForegroundColor DarkGray
      sleep -Seconds 3
    }
    }
 }
 until ($selection -eq 'q')

#endregion menu

#region function create table

      function add-valueobject  {
    
    param (
        [string] $name,
        [string] $samaccountname,
		[string] $distinguishedname,
		[string] $whencreated,
		[string] $sid,
		[string] $OS,
		[string] $Oldowner,
        [string] $newowner,
        [string] $cat,
        [string] $listetype
     )

		 
     $Hash = [ordered]@{
        Name              = $name
        SamAccountName    = $samaccountname
        DistinguishedName = $distinguishedname
        Created           = $whencreated
        SID               = $sidstring
        $cat              = $OS
        Old_Owner         = $Oldowner
        New_Owner         = $newowner 
   }

if ($listetype -eq 'brokenou')
{
  $Hash.remove('SamAccountName')
  $Hash.remove('SID')
}

$Object = [PSCustomObject]$Hash


    switch ($listetype) {
    
    'brokenpc'     { $script:brokenpc += $Object ; $script:NbrsbrokenPC++ }
    'brokenusers'  { $script:brokenusers += $Object; $script:nbrbrokenusers++ }
    'brokengroups' { $script:brokengroups += $Object; $script:nbrbrokengroups++ }
    'brokenou'     { $script:brokenou += $Object;  $script:nbrbrokenou++ }

    }

    }

#endregion function create table

#region function correction

function correct-brokenowner {

       param ( $ownerinfo  )
        
       $NewOwner = New-Object System.Security.Principal.NTAccount("$groupecorrect")
       $ownerinfo.PsBase.ObjectSecurity.SetOwner($NewOwner)

       try {
        $ownerinfo.PsBase.CommitChanges() 
        return $groupecorrect
        } catch {

        Write-host $($_.exception.message) -ForegroundColor Cyan
        return "error"
        }     
}

#endregion function correction

#region Chose groups to correct

$grouplist = $null
$grouplist = @()


([adsisearcher] "(&(objectCategory=group)(admincount=1)(iscriticalsystemobject=*))").FindAll().Properties | ForEach-Object {

#List group contains admins domain or entreprise or administrator 

 $sidstring = (New-Object System.Security.Principal.SecurityIdentifier($_["objectsid"][0], 0)).Value 

      if ($sidstring -like "*-512" -or $sidstring -like "*-519" -or $sidstring -like "*-544") 

      {$grouplist += $_.name }
      

      }


$groupecorrect = $grouplist | Out-GridView -PassThru

Write-Host You have chose : $groupecorrect -ForegroundColor Yellow

pause

#endregion Chose groups to correct


#region Scan 

$conditions | ForEach-Object {

$name = $_.samaccountname

if (!$name) { $name = $_.name }

Write-Host "We scanne $name" -ForegroundColor Yellow 

$getowner = [ADSI]("LDAP://" + $_.distinguishedname)
$oldowner = $getowner.PsBase.ObjectSecurity.Owner.Split("\")[1]

#check if owner is different from the array
if ($skipdefaultgroups -notcontains $oldowner ) { 
        
      #Convert Binary SID     
      $sid = $_["objectsid"][0] 
      if ($sid) { $sidstring = (New-Object System.Security.Principal.SecurityIdentifier($sid, 0)).Value }
                   
       if ($_["objectcategory"][0] -match "Computer") { 
       
       $newowner = correct-brokenowner $getowner 
       add-valueobject $_["name"][0] $_["samaccountname"][0] $_["distinguishedname"][0] $_["whencreated"][0] $_["objectsid"][0] $_["operatingsystem"][0] $oldowner $newowner OS brokenpc  
                                                                     
       
       } elseif ($_["objectcategory"][0] -match "Person") {

       $newowner = correct-brokenowner $getowner
       add-valueobject $_["name"][0] $_["samaccountname"][0] $_["distinguishedname"][0] $_["whencreated"][0] $_["objectsid"][0] $_["userprincipalname"][0] $oldowner $newowner UPN brokenusers
              
       } elseif ($_["objectcategory"][0] -match "group") {

       $newowner = correct-brokenowner $getowner
       add-valueobject $_["name"][0] $_["samaccountname"][0] $_["distinguishedname"][0] $_["whencreated"][0] ' ' $_["cn"][0]  $oldowner $newowner CN brokengroups
              
       } else {

      $newowner = correct-brokenowner $getowner
      add-valueobject $_["name"][0] ' ' $_["distinguishedname"][0] $_["whencreated"][0] $_["objectsid"][0] $_["description"][0]  $oldowner $newowner Description brokenou
      }
   
    $name = $getowner = $null 
}
  
    $nbrscanobject++
}

#endregion Scan

$htmltest = $null

#region CreateHTML
#Format HTML Head and page 
$head = @"
<style  type="text/css">

body { 
       background-color:#FFFFFF;
       font-family:Calibri;
              font-size:12pt; }
                h1{
        background-color:green;
        color:white;
        text-align: center;
    }    h3 {
        font-family:Tahoma;
        color:#6D7B8D;
        }
              td, th { border:0px solid black; 
                       border-collapse:collapse;
    }
                       th { color:white;
                            background-color:Dodgerblue; }
                            table, tr, td, th { padding: 2px; margin: 0px }
                            tr:nth-child(odd) {background-color: lightgray}
                            table {
                            width:95%;
                            margin-left:10px; 
                            margin-bottom:20px;
                            }
                            caption 
                            {
                            background-color:#FFFF66;
                            text-align:left;
                            font-weight:bold;
                            font-size:14pt;
                            }
tr:nth-child(n + 50) {
    visibility: hidden;
}
</style>
"@

#Generate HTML page style

$ImageTag = "<Img src='https://github.com/dakhama-mehdi/Scan-broken-owner/raw/main/Picture/2.png' Alt='Scanbroken' style='float:left' width='180' height='120' hspace=10>"

$htmltest+= $ImageTag

$htmltest+= "<h3>Correct-AD-Broken-Object-Owner (IT-connect) </h3>"
$date = Get-Date
$htmltest+= "<h3>By : DAKHAMA MEHDI   - Baomar Adham - Guylaine NGOUDJO</h3>"
$htmltest+= "<h3>$date / Scanned Object : $nbrscanobject<h3>"

$htmltest+= (ConvertTo-Html  -PreContent "<h1>Broken Users : $nbrbrokenusers</h1>" -Head $head) + ($brokenusers | ConvertTo-Html -PreContent "<h1> </h1>" -Head $head) +
( ConvertTo-Html -PreContent "<h1>Broken PC : $NbrsbrokenPC</h1>" -Head $head) + ($brokenpc | ConvertTo-Html -PreContent "<h1> </h1>" -Head $head) +
( ConvertTo-Html -PreContent "<h1>Broken Groups : $nbrbrokengroups</h1>" -Head $head) + ($brokengroups | ConvertTo-Html -PreContent "<h1> </h1>" -Head $head) +
( ConvertTo-Html -PreContent "<h1>Broken OU : $nbrbrokenou</h1>" -Head $head) + ($brokenou | ConvertTo-Html -PreContent "<h1> </h1>" -Head $head)

#endregion Createhtml

$htmltest | Out-File report-brokenowner.html

start .\report-brokenowner.html

# You can list result on consol if you use ISE, or use out-gridview
# exemples to list all brokenusers or computers on out-gridview
#$brokenusers + $brokenpc | Out-GridView -Title SCABOO -OutputMode Single 
