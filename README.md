# powershellProfile

> A collection of usefull functions and utilitaries for dev and ops

*this script has been tested on windows 10 using powershell 5*  
*please notice that the script file has to be utf-16 (BE or LE its not important i believe) encoded and use \r\n as line endings*

## Dependencies

some functions requiere specific exe in path, here's the list:

- the editor of your choice, configured with the `$defEditor` var
- [handle.exe](https://docs.microsoft.com/en-us/sysinternals/downloads/handle)
- [git](https://git-scm.com/download/win)
- [chocolatey](https://chocolatey.org/)

## Setup

Copy or merge this file into the desired profile  
Profiles descriptions base on [Microsoft doc](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles)
| Description | Path |
| ----------- | ---- |
| Current User, Current Host - console | $Home\[My ]Documents\WindowsPowerShell\Profile.ps1 |
| Current User, All Hosts | $Home\[My ]Documents\Profile.ps1 |
| All Users, Current Host - console | $PsHome\Microsoft.PowerShell_profile.ps1 |
| All Users, All Hosts | $PsHome\Profile.ps1 |
| Current user, Current Host - ISE | $Home\[My ]Documents\WindowsPowerShell\Microsoft.P owerShellISE_profile.ps1 |
| All users, Current Host - ISE | $PsHome\Microsoft.PowerShellISE_profile.ps1 |

## Configuration

you can place additionnal scripts path in the `$aditionnalScripts` var  
They will be imported and thus you'll have access to the var, functions, etc  
You should put at least one script defining the following vars:

- `$defEditor` for the path of your desired text editor
- `$profile` for the path of the powershell profile
- `$defAdm` for the default administrator user
- `$defUser` for the default user
- `$gitlocation` for the path where you locally store your git repos
- `$cdToStartDirOnStartup` whether or not you wish to cd to $startDir on startup
- `$startDir` for the default start directory
- `$profileFunctionsExecOnStartup` whether or not you wish to print the definitions of the functions available on your profile at startup

The var `$aditionnalScriptsLastExec` will behave like `$aditionnalScripts` but will be imported at the end of the profil so you can use profile defined functions
