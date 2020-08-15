<#
please notice that this file has to be utf-16 (BE or LE its not important i believe) encoded and use \r\n as line endings

you can place additionnal scripts path in the $aditionnalScripts var, they will be imported and thus you'll have access to the var, functions, etc
	you should put at least one script defining the following vars:
		$defEditor
		$defEditorParams
		$profile
		$defAdm
		$defUser
		$startDir
		$gitlocation

requiere following exe on your path
	the editor of your choice, param with the $defEditor var
	handle.exe https://docs.microsoft.com/en-us/sysinternals/downloads/handle

recommanded:
	notepad2 (which replace the shitty windows built-in text erditor) and set its default encoding to utf8 nobom
	chocolatey to install easilly soft like apt-get

powershell profiles description and path:
	Current User, Current Host - console	$Home\[My ]Documents\WindowsPowerShell\Profile.ps1
	Current User, All Hosts   				$Home\[My ]Documents\Profile.ps1
	All Users, Current Host - console   	$PsHome\Microsoft.PowerShell_profile.ps1
	All Users, All Hosts      				$PsHome\Profile.ps1

	Current user, Current Host - ISE		$Home\[My ]Documents\WindowsPowerShell\Microsoft.P owerShellISE_profile.ps1
	All users, Current Host - ISE  			$PsHome\Microsoft.PowerShellISE_profile.ps1


you can split this file into several parts which whill be visible using profileFunctions but you have to make every parts on 3 lines:
first line is 119 #, second is 15 # a space and the part's name and third is again 119 #
unfortunnaly, functions in the scripts declared in $aditionnalScripts can not be displayed with profileFunctions

Best powershell practices:
	The better lists/array:
		Array: just generec stuff, really slow but permissive => @()
		Arraylist: still generic but faster => New-Object System.Collections.ArrayList
		GenericList: not generic and the fastest => New-Object 'System.Collections.Generic.List[Int]'
#>

#######################################################################################################################
############### PARAMS AND BASIC STUFF
#######################################################################################################################

$aditionnalScripts = @()

foreach ($script in $aditionnalScripts) {
	. $script
}


#######################################################################################################################
############### ALIASES
#######################################################################################################################
set-alias pingp test-connection
set-alias grep select-string
set-alias print write-host


#######################################################################################################################
############### ESTHETICS
#######################################################################################################################
function prompt {
	$loc = $(get-location).path
	$dateF = dateFormat -dateFormat "yyyy/MM/dd HH:mm:ss"
	print ""
	if (credIsCurrentUserAdm) {
		print -NoNewline "$($env:username)" -ForegroundColor red
	} else {
		print -NoNewline "$($env:username)" -ForegroundColor green
	}
	print -NoNewline "@"
	print -NoNewline "$($env:COMPUTERNAME) " -ForegroundColor Cyan
	print -NoNewline "$dateF`n$loc`n"
	$host.ui.RawUI.WindowTitle = $loc
	return ">"
}


#######################################################################################################################
############### PROFILE
#######################################################################################################################
function profileReload {
	& $profile 
}

function profileReloadHard {
	powershell.exe; exit
}

function profileEditPowershell {
	if (credIsCurrentUserAdm) {
		Start-Process -FilePath $defEditor -ArgumentList "$profile  $defEditorParams"
	} else {
		sudo -command $defEditor -argList "$profile  $defEditorParams"
	}
}

function profileFunctions {
	$searchStr = cat $PROFILE | sls -Pattern "^(function |#{119}|#{15} )"
	$dictParts = @{}
	$n = 0
	$partPos = 1
	while ($n -lt $searchStr.length) {
		$line = $searchStr[$n]
		if ($line -match '^#{119}') {
			$currentPart = $searchStr[$n+1]
			$dictParts[$currentPart] = @{}
			$dictParts[$currentPart]["functionList"] = New-Object System.Collections.ArrayList
			$dictParts[$currentPart]["partPos"] = $partPos
			$partPos += 1
			$n += 2
		} else {
			$dictParts[$currentPart]["functionList"].add(($line -split " ")[1]) | out-null
		}
		$n += 1
	}
	$partsSorted = $dictParts.GetEnumerator() |
		select name, @{expression={$_.value["partPos"]}; name="pos"}, @{expression={$_.value["functionList"]}; name="functionList"} |
		Sort-Object -Property pos
	foreach ($part in $partsSorted) {
		if ($($part.functionList).count -gt 0) {
			$partName = $part.name -replace "^#+ ", ""
			print $("#"*119)
			print "    $partName" -ForegroundColor red
			print $("#"*119)
			foreach ($func in $part.functionList) {
				$commandObj = get-command $func
				$params = $($commandObj.Parameters.GetEnumerator() |
					where {$_.key -notin @("Debug", "Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable")} |
					ForEach-Object {$_.value} | select @{expression={$_.name + " (" + $_.parameterType.tostring() + ")"}; name="p"}).p -join ", "
				print $func -ForegroundColor yellow -NoNewline
				print " ($($params))"
			}
		}
	}
}


#######################################################################################################################
############### ADM STUFF
#######################################################################################################################
function processSearch {
	param(
		[Parameter(Mandatory = $False)][string]$FilterStr = "",
		[switch] $getParentRecurse,
		[switch] $getChildsRecurse
	)
	# fields description: https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
	if ($FilterStr -ne "") {$FilterStr = " WHERE " + $FilterStr}
	$processes = Get-CimInstance -Query $("SELECT * from Win32_Process" + $FilterStr) |
		select @{Label=”Name”;Expression={$_.ProcessName}}, @{Label=”ExecutablePath”;Expression={$_.Path}}, CreationDate, ProcessId, ParentProcessId, CommandLine
	if ($getParentRecurse -eq $true) {
		foreach ($process in $processes) {
			$FilterStrParent = $("ProcessId=" + $process.ParentProcessId)
			$parentProcess = processSearch -getParentRecurse -FilterStr $FilterStrParent
			add-member -InputObject $process -membertype NoteProperty -name "parentProcess" -value $parentProcess
		}
	} elseif ($getChildsRecurse -eq $true) {
		foreach ($process in $processes) {
			$FilterStrChilds = $("ParentProcessId=" + $process.ProcessId)
			$childProcesses = processSearch -getChildsRecurse -FilterStr $FilterStrChilds
			add-member -InputObject $process -membertype NoteProperty -name "childProcesses" -value $childProcesses
		}
	}
	$processes
}

function processPrettyPrint {
	param(
		[Parameter(Mandatory = $true)]$processSearchRes,
		[Parameter(Mandatory = $false)]$fields=@("name", "ProcessId", "ExecutablePath", "CreationDate", "CommandLine"),
		[Parameter(Mandatory = $false)][int]$level=0
	)
	if ($processSearchRes -eq $null) {
		print "aucun process"
	}
	foreach ($process in $processSearchRes) {
		$($($process | select $fields | FL | Out-String) -split "`r`n" | ? {$_ -ne ""} | % {"  "*$level + $_}) -join "`r`n"
		if ($process.childProcesses -ne $null) {
			foreach ($childProc in $process.childProcesses) {
				processPrettyPrint -processSearchRes $childProc -level $($level+1)
			}
		}
		if ($process.parentProcess -ne $null) {
			processPrettyPrint -processSearchRes $($process.parentProcess) -level $($level+1)
		}
	}
}



function pathenvGet {
    param(
        [ValidateSet('Machine', 'User', 'Session')]
        [string] $Container = 'Machine'
    )
	print "path $Container"
	if ($Container -ne 'Session') {
		$containerMapping = @{
			Machine = [EnvironmentVariableTarget]::Machine
			User = [EnvironmentVariableTarget]::User
		}
		$containerType = $containerMapping[$Container]

		$paths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
	} else {
		$paths = $env:Path -split ';'
	}
	return $paths
}

function pathenvAdd {
    param(
			[string] $Path,
			[ValidateSet('Machine', 'User', 'Session')][string] $Container = 'Machine'
    )
	
	if ($Path -eq "" -or $Path -eq $null) {
		print "current $Container PATH: "
		pathenvGet -Container $Container | print
		$Path = read-host "`nplease provide something to add in the $Container PATH`n"
	}
    if (Test-Path -path "$Path") {
        if ($Container -ne 'Session') {
            $containerMapping = @{
                Machine = [EnvironmentVariableTarget]::Machine
                User = [EnvironmentVariableTarget]::User
            }
            $containerType = $containerMapping[$Container]

            $persistedPaths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
            if ($persistedPaths -notcontains $Path) {
				$persistedPaths = $persistedPaths + $Path | where { $_ }
				[Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
            }
        }

        $envPaths = $env:Path -split ';'
        if ($envPaths -notcontains $Path) {
			$envPaths = $envPaths + $Path | where { $_ }
			$env:Path = $envPaths -join ';'
        }
    } else {
		print "$path does not exist" -foreground red -background black
		return $null
	}
}

# handle.exe: 
# params: -p to pass pid or program name; -a to search all type of handles (reg key, synchronization primitives, threads, and processes)
# you search directly the name of the file when providing the last param (no flag requiered)
function fileHandlesSearch {
    param(
		# [string] $PID,
		[string] $processName
		# [string] $FileName,
		# [string] $handlerType,
		# [System.Object[]] $handlerTypes,
		# [switch] $searchAllTypes
    )
	if (-not $(credIsCurrentUserAdm)) {
		print -foreground yellow "This script work best if launch as admin, just sayin :3"
	}
	$res = @()
	$hexaChars = "0123456789ABCDEF"
	$handleOutput = $(handle.exe -u)
	$processList = get-process
	$handleOutput = $handleOutput[5..$($handleOutput.length)]
	$handleOutput = $handleOutput | where {$_ -ne "`n"}
	$handleOutput = $handleOutput | where {$_ -ne ""}
	$handleOutput = $handleOutput -join "`n"
	$handleOutput = $handleOutput -split "------------------------------------------------------------------------------"
	foreach ($process in $handleOutput) {
		$processParsed = $process -split "`n"
		
		$pidreg = [regex]::Matches($processParsed[1], " pid: (\d+) ")
		if ($pidreg -ne $null) {
			$curpid = [regex]::Matches($processParsed[1], "pid: (\d+) ").groups[1].value
			$processname = $($processList | where {$_.id -eq $curpid}).processname
		} else {
			$curpid = "unknown"
		}
		if ($processname -eq $null -or $processname -eq "") {
			$regprocessname = [regex]::Matches($processParsed[1], "^(.+?) pid: \d+ ")
			if ($regprocessname -ne $null) {
				$processname = $regprocessname.groups[1].value
			} else {
				$processname = "unknown"
			}
		}
		$userreg = [regex]::Matches($processParsed[1], "^.+? pid: \d+ (.+)")
		if ($userreg -ne $null) {
			$handleuser = $userreg.groups[1].value
		} else {
			$handleuser = "unknown"
		}
		
		$handleList = $processParsed[2..$($processParsed.length)]
		$handleList = $handleList | where {$_ -ne ""}
		foreach ($handle in $handleList) {
			$reg = [regex]::Matches($handle, "\s+([" + $hexaChars + "]+?):\s+File\s+\([RWD-]{3}\)\s+(.+)")
			if ($reg -ne $null) {
				# print $handle
				$handleId = $reg.groups[1].value
				$fileName = $reg.groups[2].value
				$outobj = new-object psobject
				add-member -InputObject $outobj -membertype NoteProperty -name "pid" -value $curpid
				add-member -InputObject $outobj -membertype NoteProperty -name "processName" -value $processname
				add-member -InputObject $outobj -membertype NoteProperty -name "handleUser" -value $handleuser
				add-member -InputObject $outobj -membertype NoteProperty -name "handleId" -value $handleId
				add-member -InputObject $outobj -membertype NoteProperty -name "fileName" -value $fileName
				$res += $outobj
			}
		}
	}
	return $res
}


# should better test this ^^
# function fileHandleClose {
	# handle.exe -c handleid -p pid -y
	# print the infos before doing it if no force flag passed
# }



#######################################################################################################################
############### META
#######################################################################################################################
function functionDefinition {
	param(
		[string]$func
	)
	return $((get-command $func).definition)
}

function className {
	param(
		[Parameter(Mandatory = $True)] $obj
	)
	return "[$($obj.gettype().fullname)]"
}

function errorClass {
	param(
		$err = $error[0] # def on last err
	)
	print "Error Description: $err"
	return className -obj $err
}


#######################################################################################################################
############### UTILS
#######################################################################################################################
function edit {
	if ($args[0].indexof(" ") -ne -1) {
		$args[0] = '"' + $args[0] + '"'
	}
	Start-Process -FilePath $defEditor -ArgumentList $args
}

function lsltr {
	ls $args | Sort-Object -Property LastWriteTime | select mode, name, length, LastWriteTime | format-table -autosize | out-string
}

function openWindows {
	Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select id, processname, path, MainWindowTitle
}

function dateFormat {
	param(
		[Parameter(Mandatory = $false)][DateTime]$dateObj = $(get-date),
		[Parameter(Mandatory = $false)][string]$dateFormat = 'yyyyMMdd_HHmmss'
	)
	$dateObj.ToString($dateFormat)
}

function  {
  # replace the `exit` call with your custom exit expression eventually; you have to Ctrl+D and Enter (not like in linux)
  print "Bye Bye :3"
  exit
}

#######################################################################################################################
############### CRED RELATED
#######################################################################################################################
function credCLI {
	param(
		[string] $def,
		[string] $user=$defAdm,
		[string] $password
	)
	if ($user -eq $null -or $user -eq "") {
		if ($def) {
			$user = Read-Host -Prompt "Connect as (default is $def)"
			if ($user -eq "") {
				$user = $def
			}
		} else {
			$user = Read-Host -Prompt "Connect as"
		}
	} 
	if ($password -eq $null -or $password -eq "") {
		$securepassword = Read-Host -Prompt "password" -AsSecureString
	} else {
		$securepassword = ConvertTo-SecureString $password -AsPlainText -Force
	}
	$cred = new-object -typename System.Management.Automation.PSCredential($user, $securepassword)
	return $cred
}

function credIsCurrentUserAdm {
	$usr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
	return $usr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function su {
	param(
		[string] $user=$defAdm,
		[string] $password,
		[System.Management.Automation.PSCredential] $cred
	)
	if (-not $cred) {
		$cred = credCLI -def "$defAdm" -user $user -password $password
	}
	$newproc = Start-Process powershell.exe -Credential $cred -ArgumentList "Start-Process powershell.exe -Verb runAs"
	<#-NoNewWindow => this completly breaks the UI for some reason...#>
}

function sudo {
	param(
		[Parameter(Mandatory = $True)] [string] $command,
		[string] $argList="",
		[string] $user=$defAdm,
		[string] $password,
		[System.Management.Automation.PSCredential] $cred
	)
	if (-not $cred) {
		$cred = credCLI -def "$defAdm" -user $user -password $password
	}
	if (get-command -name $command) {
			Start-Process powershell.exe -Credential $cred -argumentList "-Command & {$command $argList; pause} -Verb runAs"
	} else {
		if ($argList -eq "") {
			Start-Process powershell.exe -Credential $cred -argumentList "Start-Process $command -Verb runAs"
		} else {
			Start-Process powershell.exe -Credential $cred -argumentList "Start-Process $command -argumentList $argList -Verb runAs"
		}
	}
}


#######################################################################################################################
############### PKG ET CHOCOLATEY
#######################################################################################################################
function pkgHelp {
	print "here is the common build-in commands of choco.exe"
	print ""
	print "search - searches remote or local packages (alias for list)"
	print "info - retrieves package information. Shorthand "
	print "install - installs packages from various sources"
	print "upgrade - upgrades packages from various sources [all]"
	print "uninstall - uninstalls a package"
	print "config - Retrieve and configure config file settings"
	print ""
	print "here's some custom powershell function:"
	print ""
	print "pkgChocoListInstalled to list installed packages with Chocolatey"
	print "pkgChocoUpgradeAllpkg to upgrade all packages"
	print "pkgChocoLog to edit the log file"
	print ""
	print "pkgNotonChocoUpdate will help updating the soft not manage by cholocatey (must be defined by yourself!)"
	print ""
	print "pkgDriversUpdate will start scripts to download the last drivers (not manage by cholocatey, must be defined by yourself!)"
	
}


function pkgChocoListInstalled {
	print "Packages installed:"
	choco list --local-only
}


function pkgChocoUpgradeAllpkg {
	if (credIsCurrentUserAdm) {
		print "launching globale update"
		pkgChocoLogArchive
		choco upgrade all -y
	} else {
		print "please run the function as admin"
		pause
	}
}

function pkgChocoLog {
	edit $chocoLogLocation
}

function pkgChocoLogArchive {
	$currentDate = get-date
	$currentDateStr = $currentDate.ToString('yyyyMMdd_HHmmss')
	Move-Item -LiteralPath $chocoLogLocation -Destination "$chocoLogLocation.$currentDateStr.old"
}


#######################################################################################################################
############### SYSYEME DE FICHIER
#######################################################################################################################
function dirsSize {
	param(
		[string]$targetPath = ".\",
		[int]$sizeFormat = 1GB,
		[int]$minSize = 1,
		[int]$roundNumberDec = 2,
		[bool]$debug = $true,
		[bool]$outStr = $false
	)

	class DirInfo {
		[string] $path
		$fileCount
		$size
		$depth
		
		DirInfo([string] $path, $fileCount, $size) {
			$this.path = $(resolve-path $path).path
			# $this.depth = $($this.path.ToString().Split('\\')  | ? {$_ -ne ""}).Count
			$this.fileCount = $fileCount
			$this.size = $size
		}
		
		[double]formatSize([int]$sizeFormat, [int]$roundNumberDec) {
			return [math]::round($($this.size / $sizeFormat), $roundNumberDec)
		}
		
		incrementCountAndSize($fileCount, $size) {
			$this.fileCount += $fileCount
			$this.size += $size
		}
	}

	$targetPath = $(resolve-path $targetPath).path
	if ($debug) {print "folder: $targetPath"}
	$resDict = @{}
	# browsing the deepest files first
	$fileList = $(ls -recurse $targetPath |
		select fullname, length, directoryname, parent, PSIsContainer, @{Name = 'depth'; Expression = {$($_.fullname.ToString().Split('\\') | ? {$_ -ne ""}).Count}} | 
		sort-object @{Expression = "depth"; Descending = $True}
	)
	if ($debug) {print "browsing files to do some maths"}
	foreach ($item in $fileList) {
		if ($item.PSIsContainer -eq $false) { # fichier
			$dirName = $item.directoryname
			if ($resDict.ContainsKey($dirName)) {
				$resDict[$dirName]["fileCount"] += 1
				$resDict[$dirName]["size"] += $item.length
			} else {
				$resDict[$dirName] = @{"fileCount" = 1; "size"= $item.length}
			}
		} else { # dir
			$dirName = $($item.parent).fullname
			if ($resDict.ContainsKey($dirName)) { # parent folder has been created
				if ($resDict.ContainsKey($item.fullname)) { # folder is not empty
					$resDict[$dirName]["fileCount"] += $resDict[$item.fullname]["fileCount"]
					$resDict[$dirName]["size"] += $resDict[$item.fullname]["size"]
				}
			} else { # parent folder not exists yet
				if ($resDict.ContainsKey($item.fullname)) { # folder not empty
					$resDict[$dirName] = @{"fileCount" = $resDict[$item.fullname]["fileCount"]; "size"= $resDict[$item.fullname]["size"]}
				} else { # folder is empty
					$resDict[$dirName] = @{"fileCount" = 0; "size"= 0}
				}
			}
		}
	}

	if ($debug) {print "creating DirInfo obj"}
	$resList = [System.Collections.ArrayList]@()
	foreach ($itemDict in $resDict.GetEnumerator()) {
		$newObj = [DirInfo]::new($itemDict.key, $itemDict.value["filecount"], $itemDict.value["size"])
		$nooutput = $resList.add($newObj)
	}


	if ($debug) {print "size ordering of the results"}

	$output = $resList |
		sort-object -property size |
		select path, fileCount, @{Name = 'size'; Expression = {$_.formatSize($sizeFormat, $roundNumberDec)}} |
		? {$_.size -gt $minSize}
	if ($outStr) {
		$output | FT -autosize | Out-String -Width 4096
	} else {
		$output
	}
}

#######################################################################################################################
############### ENCODING
#######################################################################################################################

# http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html
function fileEncoding {
	[CmdletBinding()] 
	Param (
		[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] 
		[string]$Path
	)
	[byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
	#print Bytes: $byte[0] $byte[1] $byte[2] $byte[3]
	# EF BB BF (UTF8)
	if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) { return 'UTF8-BOM' }
	# FE FF  (UTF-16 Big-Endian)
	elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) { return 'Unicode UTF-16 Big-Endian' }
	# FF FE  (UTF-16 Little-Endian)
	elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe) { return 'Unicode UTF-16 Little-Endian' }
	# 00 00 FE FF (UTF32 Big-Endian)
	elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) { return 'UTF32 Big-Endian' }
	# FE FF 00 00 (UTF32 Little-Endian)
	elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0) { return 'UTF32 Little-Endian' }
	# 2B 2F 76 (38 | 38 | 2B | 2F)
	elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) ) { return 'UTF7'}
	# F7 64 4C (UTF-1)
	elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c ) { return 'UTF-1' }
	# DD 73 66 73 (UTF-EBCDIC)
	elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73) { return 'UTF-EBCDIC' }
	# 0E FE FF (SCSU)
	elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff ) { return 'SCSU' }
	# FB EE 28  (BOCU-1)
	elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 ) { return 'BOCU-1' }
	# 84 31 95 33 (GB-18030)
	elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33) { return 'GB-18030' }
	else { return 'ASCII or UTF8-noBOM' }
}

#######################################################################################################################
############### GIT
#######################################################################################################################

function gitCd {
	cd $gitlocation
}

function gitPowershellProfileRepoPush {
	Param (
		[Parameter(Mandatory = $false)][string]$commitMess = "updated profile"
	)
	gitCd
	cd powershellProfile
	cp $PROFILE "./profile.ps1"
	edit "./profile.ps1"
	read-host "Please remove any personnal stuff remaining in your profile and press enter to commit"
	git add "profile.ps1"
	git commit -m $commitMess
	git push origin master
}

#######################################################################################################################
############### ONSTARTUP
#######################################################################################################################
cd $startDir
profileFunctions
