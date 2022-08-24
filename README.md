# Correct-AD-Broken-Object-Owner

# Description : 

This Script correct AD Broken Owner Object

Script scan and replace broken owners/representing a risk of (users accounts, Computers, Groups and Organizational Units).


# Objective : 

Clean AD and prevent various attacks also reduce CT vulnerabilities on objects

# About : 

when the user creates an object, he will be the owner and can modify the permissions at any time, even if we remove the permission on the AD he can still perform actions on the objects he owns, he will then become a target of attack, because access to these objects will recover accounts


# Recommendation : 

Microsoft recommends placing a Domain Admin privileged group or groups memebers on objects at risk to protect them from various vulnerabilities.

Links : https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd125370(v=ws.10)?redirectedfrom=MSDN

# Why to Use script : 

This script help to replace bad object owner by the recommend groups. 

Prevent Attack : Kerberos Resource-based Constrained Delegation on Computer Object Takeover

# How to use : 

 Copy the script from "Source Code" folder on ISE and lanuch it from the machine on the domain or on Domain Controller.
 
 The script need right administrator privilege and be run by a member of administrator domains.
 
 
 # Edit Script 
 
 the script list by default 50 objects brokent by category, you can list more on change value at line : 237
 
 The script generate HTML format by default, you can also show on gridview or CSV by uncomment line : 267
 
 You can add a specific groups or user to skip from scan, by add it in line : 49
 

 # Thanks to All contributors, specified :  
 
 Souin Mattieuw 
 Adham Bouomar
 Guylaine NGOUDJO
 
 # Demo : 

![caboov3](https://user-images.githubusercontent.com/49924401/186425742-554e1139-4349-4d4c-a43c-8a8ff26094a8.gif)
