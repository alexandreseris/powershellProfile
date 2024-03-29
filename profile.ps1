<#
CAUTION: this script has been tested on windows 10 using powershell 5, maybe it works with other versions, maybe not so be carreful :)

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
		$cdToStartDirOnStartup
		$profileFunctionsExecOnStartup

there is another related var: $aditionnalScriptsLastExec
	the difference is that the import of the files in the list is done at the end of the profile, so if you can safely place elements using the profile ressources, custom functions for exemple

some functions requiere some exe in path, here's the list:
	the editor of your choice, param with the $defEditor var
	handle.exe https://docs.microsoft.com/en-us/sysinternals/downloads/handle
	git
	chocolatey (to install easilly soft like apt-get)

recommanded:
	notepad2 (which replace the shitty windows built-in text erditor) and set its default encoding to utf8 nobom

powershell profiles description and path:
	Current User, Current Host - console	$Home\[My ]Documents\WindowsPowerShell\Profile.ps1
	Current User, All Hosts   				$Home\[My ]Documents\Profile.ps1
	All Users, Current Host - console   	$PsHome\Microsoft.PowerShell_profile.ps1
	All Users, All Hosts      				$PsHome\Profile.ps1 => a good choice to access the functions with any user

	Current user, Current Host - ISE		$Home\[My ]Documents\WindowsPowerShell\Microsoft.P owerShellISE_profile.ps1
	All users, Current Host - ISE  			$PsHome\Microsoft.PowerShellISE_profile.ps1


you can split this file into several parts which whill be visible using profileFunctions but you have to make every parts on 3 lines:
first line is 119 #, second is 15 # a space and the part's name and third is again 119 #
scripts in $aditionnalScripts and $aditionnalScriptsLastExec do not need to follow that rule you can put them as you wish, they will appear in order only with a subpart on the file name
	be extra carefull with the scripts you put here as they only should be writable by an admin to avoid injection

Best powershell practices:
	The better lists/array:
		Array: just generic stuff, really slow but permissive => @()
		Arraylist: still generic but faster => New-Object System.Collections.ArrayList
		GenericList: not generic and the fastest => New-Object 'System.Collections.Generic.List[Int]'
#>

$_profileTestedVersion = 5
$_powershellVersion = $PSVersionTable.PSVersion.Major
$_powershellVersionStr = $($PSVersionTable.PSVersion).tostring()

if ($_powershellVersion -lt $_profileTestedVersion) {
	$cautionMess = read-host "powershell version $_powershellVersion found.`nthis script has been tested under version $_profileTestedVersion, use it at your own risk!`ny to continue, else exit`n(if you wish to skip this control, you'll have to manually delete it in the profile)"
	if ($cautionMess -ne "y") {
		exit
	}
}


#######################################################################################################################
############### PARAMS AND BASIC STUFF
#######################################################################################################################
# carefull with theses, it should be writable only by admin to avoid injections
$aditionnalScripts = @()
$aditionnalScriptsLastExec = @()

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
	<#
	.SYNOPSIS
		customize the way prompt informations are displayed
	#>
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
	<#
	.SYNOPSIS
		start a new powershell process to reload the profile
	#>
	param (
		[switch]$noNewWindow
	)
	if ($noNewWindow) {
		powershell.exe
	} else {
		start-process "powershell"
	}
	exit
}

function profileEditPowershell {
	<#
	.SYNOPSIS
		edit this profile using your default text editor
	#>
	edit $profile
	$aditionnalScripts | ForEach-Object {edit $_}
	$aditionnalScriptsLastExec | ForEach-Object {edit $_}
}

function profileFunctions {
	<#
	.SYNOPSIS
		show the functions defined in the profile and their parameters
	#>
	$dictParts = @{}
	print "functions found in the profile $profile and in the additionnal scripts provided"

	# search in profile
	$searchStr = Get-Content $PROFILE | Select-String -Pattern "^(function |#{119}|#{15} )"
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

	# search in the additionnal scripts
	$additionnalScriptsListRes = @()
	$aditionnalScriptsSearch = $aditionnalScripts | ForEach-Object {Select-String -inputobject $(Get-Item $_) -Pattern "^function "}
	$aditionnalScriptsLastExecSearch = $aditionnalScriptsLastExec | ForEach-Object {Select-String -inputobject $(get-item $_) -Pattern "^function "}
	$additionnalScriptsListRes += $aditionnalScriptsSearch
	$additionnalScriptsListRes += $aditionnalScriptsLastExecSearch
	foreach ($line in $additionnalScriptsListRes) {
		$currentPart = $line.Path
		if ($currentPart -notin $dictParts.keys) {
			$dictParts[$currentPart] = @{}
			$dictParts[$currentPart]["functionList"] = New-Object System.Collections.ArrayList
			$dictParts[$currentPart]["partPos"] = $partPos
			$partPos += 1
		}
		$dictParts[$currentPart]["functionList"].add(($line.line -split " ")[1]) | out-null
	}

	$partsSorted = $dictParts.GetEnumerator() |
		Select-Object name, @{expression={$_.value["partPos"]}; name="pos"}, @{expression={$_.value["functionList"]}; name="functionList"} |
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
					Where-Object {$_.key -notin @("Debug", "Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable")} |
					ForEach-Object {$_.value} | Select-Object @{expression={$_.name + " (" + $_.parameterType.tostring() + ")"}; name="p"}).p -join ", "
				print $func -ForegroundColor yellow -NoNewline
				print " ($($params))"
			}
		}
	}
}


#######################################################################################################################
############### DISK MANAGEMENT
#######################################################################################################################
function disksAndPartitions {
	<#
	.SYNOPSIS
		print disks and related partitions in a table output
	#>
	$disks = @()
	foreach ($disk in (get-disk | sort-object -property DiskNumber)) {
		$diskFields = $disk | Select-Object `
			DiskNumber, FriendlyName, size, OperationalStatus, HealthStatus, PartitionStyle, BusType, UniqueId, Guid, BootFromDisk, IsBoot, IsSystem
		Add-Member -InputObject $diskFields -MemberType NoteProperty -Name "partitions" -Value @()
		foreach ($partition in $(get-partition -DiskNumber $disk.DiskNumber | sort-object -property PartitionNumber)) {
			$partitionFields = $partition | Select-Object `
				PartitionNumber, Type, DriveLetter, size, MbrType, GptType, Offset, AccessPaths, UniqueId, IsActive, IsBoot, IsHidden, IsSystem
			$volumeFields = get-volume -Partition $partition | Select-Object `
				FileSystem
			Add-Member -InputObject $partitionFields -MemberType NoteProperty -Name "volume" -Value $volumeFields.FileSystem
			$diskFields.partitions += $partitionFields
		}
		$disks += $diskFields
	}



	foreach ($diskFields in $disks) {
		$diskFormat = $diskFields
		$diskFormat.size = formatSize $diskFormat.size
		$diskFormat = $diskFields | Select-Object -ExcludeProperty partitions * | Format-Table -autosize -property * | out-string -Width 1000
		$diskFormat = ($diskFormat -replace "\r\n\r\n", "") + "`r`n"
		write-host $diskFormat
		foreach ($partitionFields in $diskFields.partitions) {
			$partitionFields.size = formatSize $partitionFields.size
		}
		$partitionFormat = $diskFields.partitions | Select-Object * | Format-Table -autosize -property * | out-string -Width 1000
		$partitionFormat = (($partitionFormat) -replace "\r\n\r\n", "") + "`r`n"
		$partitionFormat = [regex]::replace($partitionFormat, "^", "`t", [System.Text.RegularExpressions.RegexOptions]::Multiline)
		write-host $partitionFormat
	}
}


#######################################################################################################################
############### ADM RELATED
#######################################################################################################################
function processSearch {
	<#
	.SYNOPSIS
		allow you to search process in sql like query (no need to write where)
		you can use the following fields: Name, ExecutablePath, CreationDate, ProcessId, ParentProcessId, CommandLine and any other in the Win32_Process class (https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process)
		Name and ProcessId are wrapped arround the processId and processName params so you dont have to include them manually in filterStr (but you can if you want)
		getParentRecurse and getChildsRecurse switch parameters allow you to recursivly retrieve the process obj
	#>
	param(
		[Parameter(Mandatory = $False)][string]$filterStr = "",
		[Parameter(Mandatory = $False)][string]$processId = "",
		[Parameter(Mandatory = $False)][string]$processName = "",
		[switch] $getParentRecurse,
		[switch] $getChildsRecurse,
		[switch] $prettyPrint,
		[switch] $verboseSwitch
	)
	# fields description: https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
	$QueryStrBuild = "SELECT * from Win32_Process"
	if ($FilterStr -ne "" -or $processId -ne "" -or $processName -ne "") {
		$QueryStrBuild += " WHERE "
		$whereBuild = @()
		if ($FilterStr -ne "") {
			$whereBuild += $FilterStr
		}
		if ($processId -ne "") {
			$whereBuild += "ProcessId = $processId"
		}
		if ($processName -ne "") {
			$whereBuild += "Name like '$processName%'"
		}
		$QueryStrBuild += $whereBuild -join " and "
	}
	if ($verboseSwitch) {print $QueryStrBuild}
	$processes = Get-CimInstance -Query $QueryStrBuild |
		Select-Object @{Label=”Name”;Expression={$_.ProcessName}},
			@{Label=”ExecutablePath”;Expression={$_.Path}},
			CreationDate,
			@{Label=”User”;Expression={
					$ownerObj = (Get-WmiObject Win32_Process -Filter "processid=$($_.ProcessId)").getowner()
					if ($null -ne $ownerObj.User) {
						$ownerObj.Domain+"\"+$ownerObj.User
					} else {
						""
					}
				}
			},
			ProcessId,
			ParentProcessId,
			CommandLine
	if ($null -eq $processes) {
		return $null
	}
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
	if ($prettyPrint) {
		processPrettyPrint -processSearchRes $processes
	} else {
		$processes
	}
}

function processPrettyPrint {
	<#
	.SYNOPSIS
		pretty print the return of processSearch in a tree like view
	#>
	param(
		[Parameter(Mandatory = $true)]$processSearchRes,
		[Parameter(Mandatory = $false)]$fields=@("Name", "ProcessId", "CreationDate", "User", "ExecutablePath", "CommandLine"),
		[Parameter(Mandatory = $false)][int]$indentSpaceNumber=4,
		[Parameter(Mandatory = $false)][int]$level=0
	)
	if ($null -eq $processSearchRes) {
		print "aucun process"
	}
	foreach ($process in $processSearchRes) {
		$($($($process | Select-Object $fields | Format-List | Out-String) -split "`r`n" | Where-Object {$_ -ne ""} | ForEach-Object {" "*$indentSpaceNumber*$level + $_}) -join "`r`n") + "`r`n"
		if ($null -ne $process.childProcesses) {
			foreach ($childProc in $process.childProcesses) {
				processPrettyPrint -processSearchRes $childProc -level $($level+1)
			}
		}
		if ($null -ne $process.parentProcess) {
			processPrettyPrint -processSearchRes $($process.parentProcess) -level $($level+1)
		}
	}
}



function pathenvGet {
	<#
	.SYNOPSIS
		retrieve path environnement variable for the specified container
	#>
    param(
        [ValidateSet('Machine', 'User', 'Session')][string] $Container = 'Machine'
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
	<#
	.SYNOPSIS
		set the path environnement variable for the specified container
		if no path param is passed, current path env var is printed
		the path param is controller to check if it actually exists
		if everything is ok, the path elem is added and the path elem is added to the current session so you do not need to create a new session
	#>
    param(
			[string] $Path,
			[ValidateSet('Machine', 'User', 'Session')][string] $Container = 'Machine'
    )
	
	if ($Path -eq "" -or $null -eq $Path) {
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
				$persistedPaths = $persistedPaths + $Path | Where-Object { $_ }
				[Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
            }
        }

        $envPaths = $env:Path -split ';'
        if ($envPaths -notcontains $Path) {
			$envPaths = $envPaths + $Path | Where-Object { $_ }
			$env:Path = $envPaths -join ';'
        }
    } else {
		print "$path does not exist" -foreground red -background black
		return $null
	}
}


function fileHandlesSearch {
    <#
    .SYNOPSIS
        search file handles (better launch as admin) using handle.exe
        processName and fileName param are case insensitive and do not need the exact string (checks if the file contain the param)
        note:
        -you cannot use both processId and processName at the same time, and you cannot pass list of any kind to thoses parameters
        -searchAllTypes param allow you to retrieve any kind of handle, even threads, reg key, etc (default without the falg is to search files and sections only)
    #>
    param(
		[string] $processId="",
		[string] $processName="",
		[string] $fileName="",
        [switch] $searchAllTypes,
        [switch] $verboseSwitch
    )
    if ($verboseSwitch) {print "setting encodings"}
    $encoding = [System.Text.Encoding]::UTF7
    encodingSet -encoding $encoding -setAllEncodings

    $hexaChars = "0123456789ABCDEF"

    $baseCmd = "handle.exe"
    if ($verboseSwitch) {print "processing parameters"}
    $optLs = @("-nobanner", "-u")
    if ($processId -ne "") {
        $optLs += "-p"
        $optLs += "$processId"
    } elseif ($processName -ne "") {
        $optLs += "-p"
        $optLs += "$processName"
    }
    if ($searchAllTypes) {
        $optLs += "-a"
    }
    if ($fileName -ne "") {
        $optLs += "$fileName"
    }

    if ($verboseSwitch) {print "exec $baseCmd $optLs"}
    $handleRaw = & $baseCmd $optLs

    if ($verboseSwitch) {print "setting encodings back"}
    encodingRestore -setAllEncodings

    if ($handleRaw -match "^usage: handle") {
        print "synthax problem with handle.exe"
        return $null
    } elseif ($handleRaw -match "^No matching handles found\.`$") {
        print "no match found"
        return $null
    }

    if ($verboseSwitch) {print "parsing raw results"}
    $handleRaw = $handleRaw | Where-Object {$_ -notmatch "^\s*`$"}
    $handleRaw = $handleRaw | ForEach-Object {$_.trim()}

    $res = @()

    if ($fileName -ne "") { # the resultat if a filename is passed to handle is completly different, hence the if
        foreach ($line in $handleRaw) {
            $regStr = "^(?<process>.+)\s+pid: (?<pid>\d+)\s+type: (?<type>[\w ]+?)\s+(?<user>.+?)\s+(?<handle>[$hexaChars]+?): (?<description>.*)?`$"
            $regSearch = [regex]::Matches($line, $regStr)

            if ($regSearch.count -gt 0) {
                $processName = $regSearch[0].groups["process"].value.trim()
                $processId = $regSearch[0].groups["pid"].value.trim()
                $type = $regSearch[0].groups["type"].value.trim()
                $user = $regSearch[0].groups["user"].value.trim()
                $handle = $regSearch[0].groups["handle"].value.trim()
                $description = $regSearch[0].groups["description"].value.trim()
                if ($user -eq "\<unable to open process>") {
                    $user = ""
                }

                $buildObj = [pscustomobject]@{
                    processName = $processName
                    pid = $processId
                    type = $type
                    user = $user
                    handle = $handle
                    description = $description
                }
                $res += $buildObj
            } else {
                print "line not matched: $line"
            }
        }
    } else { # parsing res if no filename was passed
        function parseHandleLine {
            param(
                [string]$line,
                [string]$processName,
                [string]$processId,
                [string]$user
            )
            $handleInfoReg = "^"
            $handleInfoReg += "(?<handle>[$hexaChars]+): (?<type>File)  \([RWD-]{3}\)   (?<description>.+)"
            $handleInfoReg += "|(?<handle>[$hexaChars]+): (?<type>\w+( \w+)*)\s+(?<description>.+)"
            $handleInfoReg += "|(?<handle>[$hexaChars]+): (?<type>\w+( \w+)*)"
            $handleInfoReg += "`$"
            $handleInfoRegSearchReg = [regex]::Matches($line, $handleInfoReg)
            if ($handleInfoRegSearchReg.count -gt 0) {
                $handle = $handleInfoRegSearchReg[0].groups["handle"].value.trim()
                $type = $handleInfoRegSearchReg[0].groups["type"].value.trim()
                $description = $handleInfoRegSearchReg[0].groups["description"].value.trim()
            } else {
                print "line not matched (handleInfoReg): $line"
            }
            $buildObj = [pscustomobject]@{
                processName = $processName
                pid = $processId
                type = $type
                user = $user
                handle = $handle
                description = $description
            }
            return $buildObj
        }


        if ($processId -ne "") {
            $processInfos = processSearch -processId $processId
            foreach ($line in $handleRaw) {
                $buildObj = parseHandleLine -line $line -processName $processInfos.Name -processId $processId -user $processInfos.user
                $res += $buildObj
            }
        } else {
            $processSeparator = "------------------------------------------------------------------------------"
            $processInfoReg = "^(?<process>.+?) pid: (?<pid>\d+) (?<user>.+?)`$"

            $processSeparatorFound = $false
            foreach ($line in $handleRaw) {
                if ($line -eq $processSeparator) {
                    $processSeparatorFound = $true
                    continue
                } else {
                    if ($processSeparatorFound) { # line for process infos
                        $processSeparatorFound = $false

                        $processInfoRegSearch = [regex]::Matches($line, $processInfoReg)
                        if ($processInfoRegSearch.count -gt 0) {
                            $processName = $processInfoRegSearch[0].groups["process"].value.trim()
                            $processId = $processInfoRegSearch[0].groups["pid"].value.trim()
                            $user = $processInfoRegSearch[0].groups["user"].value.trim()
                        } else {
                            print "line not matched (processInfoReg): $line"
                        }
                    } else { # line for handle infos
                        $buildObj = parseHandleLine -line $line -processName $processName -processId $processId -user $user
                        $res += $buildObj
                    }
                }
            }
        }
    }
    return $res
}


function fileHandleClose {
    <#
    .SYNOPSIS
        close a file handle using handle.exe
        BE EXTRA CAREFULL WITH THIS, closing a bad handle could crash the system; noConfirmation switch should probably not be used at all
    #>
    param (
        [Parameter(Mandatory = $true)][int]$processId,
        [Parameter(Mandatory = $true)][string]$handleHexaId,
        [switch]$noConfirmation
    )
    $encoding = [System.Text.Encoding]::UTF7
    encodingSet -encoding $encoding -setAllEncodings
    $baseCmd = "handle.exe"
    $optLs = @("-nobanner", "-p", $($processId.ToString()), "-c", $handleHexaId)
    if ($noConfirmation) {
        $optLs += "-y"
    }
    & $baseCmd $optLs
    $errorTest = $?
    encodingRestore -setAllEncodings
    return $errorTest
}



#######################################################################################################################
############### NETWORK
#######################################################################################################################

function pingLocal {
	<#
	.SYNOPSIS
		ping your default gateway (not reliable if you're connected to several interfaces)
	#>
	ping -t $((Get-WmiObject -Class Win32_IP4RouteTable |  Select-Object nexthop, interfaceindex, destination, mask | Where-Object { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'})[0].nexthop)
}

function openPorts {
    <#
    .SYNOPSIS
        netstat powershell wrapper and retrieve process infos with get-process
		documentation for the state: https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Protocol_operation and https://docs.microsoft.com/windows-server/administration/windows-commands/netstat#remarks
    #>
	$netstatRaw = netstat -aon
	$netstatRaw = $netstatRaw | Where-Object {$_ -notmatch "^`s*$"}
	function parseIp {
		param(
			[string]$ip
		)
		$spl = $ip -split ":"
		$adr = $spl[0..$($spl.count - 2)] -join ":"
		if ($adr.indexof("[") -ne -1) {
			$adr = $adr -replace "\[|\]", ""
			$type = "ipv6"
		} else {
			$type = "ipv4"
		}
		$port = $spl[$spl.count - 1]
		$ipObj = [pscustomobject]@{
			adress = $adr
			port = $port
			type = $type
		}
		return $ipObj
	}
	$netStatRes = @()
	foreach ($line in $netstatRaw[2..$netstatRaw.Count]) {
		$line = $line.trim()
		$splitRes = $line -split "\s+"
		$protocol = $splitRes[0]
		$local = $splitRes[1]
		$remote = $splitRes[2]
		if ($splitRes.count -eq 4) {
			$state = $null
			$processId = $splitRes[3]
		} else {
			$state = $splitRes[3]
			$processId = $splitRes[4]
		}
		$processDetails = Get-Process -id $processId
		$lineObj = [pscustomobject]@{
			protocol = $protocol
			local = parseIp -ip $local
			remote = parseIp -ip $remote
			state = $state
			pid = $processId
			processName = $processDetails.name
			processPath = $processDetails.path
		}
		$netStatRes += $lineObj
	}
	return $netStatRes
}


#######################################################################################################################
############### META
#######################################################################################################################
function functionDefinition {
	<#
	.SYNOPSIS
		return the code of the function passed as parameter
	#>
	param(
		[string]$func
	)
	return $((get-command $func).definition)
}

function className {
	<#
	.SYNOPSIS
		return the class name of the object passed as parameter
	#>
	param(
		[Parameter(Mandatory = $True)] $obj
	)
	return "[$($obj.gettype().fullname)]"
}

function errorClass {
	<#
	.SYNOPSIS
		return the class name of an error
		if no error is supplied, last error from $error is used instead
	#>
	param(
		$err = $error[0] # def on last err
	)
	print "Error Description: $err"
	return className -obj $err
}


#######################################################################################################################
############### UTILS
#######################################################################################################################
function formatSize {
    param (
        $inpNum
    )
    $sizes = @(
        @{"str"="TB"; "num"=1TB},
        @{"str"="GB"; "num"=1GB},
        @{"str"="MB"; "num"=1MB},
        @{"str"="KB"; "num"=1KB}
    )
    foreach ($size in $sizes) {
        if ($inpNum -ge $size["num"]) {
            return "$([System.Math]::Round($inpNum / $size["num"], 2))$($size["str"])"
        }
    }
}

function edit {
    <#
    .SYNOPSIS
        open the argument file in the default editor
    #>
	if ($args[0].indexof(" ") -ne -1) {
		$args[0] = '"' + $args[0] + '"'
	}
	Start-Process -FilePath $defEditor -ArgumentList $args
}

function lt {
	<#
	.SYNOPSIS
		list files from older to newer based on modification date
	#>
	Get-ChildItem $args | Sort-Object -Property LastWriteTime
}

function ltToday {
	<#
	.SYNOPSIS
		list files from older to newer based on modification date and filter to get only files modified today
	#>
	Get-ChildItem $args | Where-Object {isSameDay -dat1 $_.LastWriteTime -dat2 $(get-date)} | Sort-Object -Property LastWriteTime
}


function openWindows {
	<#
	.SYNOPSIS
		return the open window
	#>
	Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object id, processname, path, MainWindowTitle
}

function dateFormat {
	<#
	.SYNOPSIS
		wrapper to format date
	#>
	param(
		[Parameter(Mandatory = $false)][DateTime]$dateObj = $(get-date),
		[Parameter(Mandatory = $false)][string]$dateFormat = 'yyyyMMdd_HHmmss'
	)
	$dateObj.ToString($dateFormat)
}

function isSameDay {
	<#
	.SYNOPSIS
		compare two date and check if they are on the same day
	#>
	param(
		[System.DateTime]$dat1,
		[System.DateTime]$dat2
	)
	if (($dat1.day -eq $dat2.day) -and ($dat1.month -eq $dat2.month) -and ($dat1.year -eq $dat2.year)) {
		return $True
	} else {return $False}
}

function  {
    <#
    .SYNOPSIS
        quit powershell using Ctrl + D (you have to press enter since it's a function tho)
    #>
  print "Bye Bye :3"
  exit
}

function hashtableToCustomobj {
	<#
	.SYNOPSIS
		wrapper to convert hashtable to custom object
	#>
	param (
		[Hashtable]$hashtable
	)
	$object = New-Object PSObject
	$hashtable.GetEnumerator() | 
	ForEach-Object { 
		Add-Member -inputObject $object -memberType NoteProperty -name $_.Name -value $_.Value
	}
	return $object
}

#######################################################################################################################
############### CRED RELATED
#######################################################################################################################
function credCLI {
    <#
    .SYNOPSIS
        comand line to retrieve a user credentiel (System.Management.Automation.PSCredential obj)
    #>
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
		$securepassword = Read-Host -Prompt "password for $user" -AsSecureString
	} else {
		$securepassword = ConvertTo-SecureString $password -AsPlainText -Force
	}
	$cred = new-object -typename System.Management.Automation.PSCredential($user, $securepassword)
	return $cred
}

function credIsCurrentUserAdm {
    <#
    .SYNOPSIS
        checks if the current user is an administrator
    #>
	$usr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
	return $usr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}



#######################################################################################################################
############### PKG, CHOCOLATEY
#######################################################################################################################
function pkgHelp {
	<#
	.SYNOPSIS
		print chocolatey commands and custom function related to package management
	#>
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
	print "pkgChocoLog to open last logs of choco"
	print ""
	print "pkgNotonChocoUpdate will help updating the soft not manage by cholocatey (must be defined by yourself!)"
	print ""
	print "pkgDriversUpdate will start scripts to download the last drivers (not manage by cholocatey, must be defined by yourself!)"
}

function pkgChocoListInstalled {
	<#
	.SYNOPSIS
		print the locally installed packages with chocolatey
	#>
	$listRaw = choco list --local-only
	$listRaw[0..$($listRaw.count-2)] | ForEach-Object {
		$splitInfos = $_ -split " "
		[pscustomobject]@{
			name = $splitInfos[0]
			version = $splitInfos[1]
		}
	}
}

function pkgChocoUpgradeAllpkg {
	<#
	.SYNOPSIS
		upgrade all your chocolatey packages
	#>
	param (
		[switch]$openLogs,
		[switch]$dontRemovePublicShortcuts
	)
	if (credIsCurrentUserAdm) {
		print "launching globale update"
		pkgChocoLogArchive
		choco upgrade all -y
		if (-not $dontRemovePublicShortcuts) {
			Remove-Item "$($env:PUBLIC)\Desktop\*"
		}
		if ($openLogs) {
			pkgChocoLog
		}
	} else {
		print "please run the function as admin"
	}
}

function pkgChocoLog {
	<#
	.SYNOPSIS
		open the chocolatey log files using your default text editor
	#>
	edit $chocoLogLocation $chocoLogSummaryLocation	
}

function pkgChocoLogArchive {
	<#
	.SYNOPSIS
		rename the current chocolatey log with the current date
	#>
	$currentDate = get-date
	$currentDateStr = $currentDate.ToString('yyyyMMdd_HHmmss')
	Move-Item -LiteralPath $chocoLogLocation -Destination "$chocoLogLocation.$currentDateStr.old"
	Move-Item -LiteralPath $chocoLogSummaryLocation -Destination "$chocoLogSummaryLocation.$currentDateStr.old"
	Get-ChildItem -LiteralPath $chocoLogDir -file | Where-Object {$(New-TimeSpan -Start $($_.LastWriteTime) -end $(Get-Date)).days -gt 30*3} | ForEach-Object {Remove-Item -LiteralPath $_.fullname}
}

function pkgGetAllSoftwareInstalled {
	Get-AppxPackage |
		Select-Object @{"l"="name"; "e"={$_.name}},
		       InstallLocation,
		       @{"l"="version"; "e"={$_.version}},
		       @{"l"="InstallDate"; "e"={""}},
		       @{"l"="Publisher"; "e"={$_.Publisher}},
		       @{"l"="architecture"; "e"={$_.Architecture}},
		       @{"l"="level"; "e"={"windowsStore"}}
	Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object {
	  Get-ItemProperty $_.pspath | Where-Object {$_.DisplayName -ne "" -and $null -ne $_.DisplayName} |
		Select-Object @{"l"="name"; "e"={$_.DisplayName}},
		       InstallLocation,
		       @{"l"="version"; "e"={$_.DisplayVersion}},
		       InstallDate,
			   Publisher,
		       @{"l"="architecture"; "e"={"x64"}},
			   @{"l"="level"; "e"={"system"}}
	}
	Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object {
	  Get-ItemProperty $_.pspath | Where-Object {($_.DisplayName -ne "" -and $null -ne $_.DisplayName)} |
		Select-Object @{"l"="name"; "e"={$_.DisplayName}},
		       InstallLocation,
		       @{"l"="version"; "e"={$_.DisplayVersion}},
		       InstallDate,
			   Publisher,
		       @{"l"="architecture"; "e"={"x86"}},
			   @{"l"="level"; "e"={"system"}}
	}
	Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object {
	  Get-ItemProperty $_.pspath | Where-Object {($_.DisplayName -ne "" -and $null -ne $_.DisplayName)} |
		Select-Object @{"l"="name"; "e"={$_.DisplayName}},
		       InstallLocation,
		       @{"l"="version"; "e"={$_.DisplayVersion}},
		       InstallDate,
			   Publisher,
		       @{"l"="architecture"; "e"={"Neutral"}},
			   @{"l"="level"; "e"={"user"}}
	}
}

#######################################################################################################################
############### FILE SYSTEM
#######################################################################################################################
function switchDrive {
	param(
		[string]$targetDrive
	)
	$newLocation = $(Get-Location).path -replace '^.', $targetDrive
	if (test-path $newLocation) {
		Set-Location $newLocation
	} else {
		write-error "$newLocation does not exists"
	}
}


function dirsSize {
    <#
    .SYNOPSIS
        compute the size of a directory
    #>
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
	$fileList = $(Get-ChildItem -recurse $targetPath |
		Select-Object fullname, length, directoryname, parent, PSIsContainer, @{Name = 'depth'; Expression = {$($_.fullname.ToString().Split('\\') | Where-Object {$_ -ne ""}).Count}} | 
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
		[void] $resList.add($newObj)
	}


	if ($debug) {print "size ordering of the results"}

	$output = $resList |
		sort-object -property size |
			Select-Object path, fileCount, @{Name = 'size'; Expression = {$_.formatSize($sizeFormat, $roundNumberDec)}} |
			Where-Object {$_.size -gt $minSize}
	if ($outStr) {
		$output | Format-Table -autosize | Out-String -Width 4096
	} else {
		$output
	}
}


function advancedFileSearch {
    <#
    .SYNOPSIS
        allow some advanced search in a directory using regex
    #>
	param(
		[Parameter(Mandatory=$true)] [string]$rootDir,
		[Parameter(Mandatory=$false)] [string]$searchDirReg = ".*",
		[Parameter(Mandatory=$false)] [string]$searchFileContentReg = ".*",
		[Parameter(Mandatory=$false)] [string]$fileEncoding = "utf8",
		[Parameter(Mandatory=$false)] [int]$lineCut = 100,
		[Parameter(Mandatory=$false)] [int]$caseSensitive = $false
	)
	$cwd = Get-Location
	if ($rootDir -notlike '*\') {
		$rootDir = $rootDir + "\"
	}
	Set-Location $rootDir
	$fileList = $(Get-ChildItem -recurse |
		Where-Object {$_.PSIsContainer -eq $false -and $($_.fullname -replace  [regex]::escape($rootDir), "") -match $searchDirReg} |
		Select-Object @{expression={$_.fullname -replace  [regex]::escape($rootDir), ""};label="path"}
	)
	foreach ($file in $fileList) {
		if ($caseSensitive) {
			$res = select-string -CaseSensitive -encoding $fileEncoding -pattern $searchFileContentReg -path $file.path
		} else {
			$res = select-string -encoding $fileEncoding -pattern $searchFileContentReg -path $file.path
		}
		foreach ($line in $res) {
			if ($lineCut -lt 0) {
				$line | Select-Object @{expression={$_.path -replace  [regex]::escape($rootDir), ""};label="path"}, line
			} else {
				if ($line.line.length -gt $lineCut) {
					$line | Select-Object @{expression={$_.path -replace  [regex]::escape($rootDir), ""};label="path"}, @{expression={$_.line.substring(0,$lineCut) };label="line"}
				} else {
					$line | Select-Object @{expression={$_.path -replace  [regex]::escape($rootDir), ""};label="path"}, line
				}
			}
		}
	}
	Set-Location $cwd
}


#######################################################################################################################
############### ENCODING
#######################################################################################################################

# http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html
function encodingGuessFile {
    <#
    .SYNOPSIS
        guess the encoding of a file
    #>
	[CmdletBinding()] 
	Param (
		[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)][string]$Path
	)
	[byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
	if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) { return 'UTF8-BOM' } # EF BB BF (UTF8)
	elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) { return 'Unicode UTF-16 Big-Endian' } # FE FF  (UTF-16 Big-Endian)
	elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe) { return 'Unicode UTF-16 Little-Endian' } 	# FF FE  (UTF-16 Little-Endian)
	elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) { return 'UTF32 Big-Endian' } # 00 00 FE FF (UTF32 Big-Endian)
	elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0) { return 'UTF32 Little-Endian' } # FE FF 00 00 (UTF32 Little-Endian)
	elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) ) { return 'UTF7'} # 2B 2F 76 (38 | 38 | 2B | 2F)
	elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c ) { return 'UTF-1' } # F7 64 4C (UTF-1)
	elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73) { return 'UTF-EBCDIC' } # DD 73 66 73 (UTF-EBCDIC)
	elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff ) { return 'SCSU' } # 0E FE FF (SCSU)
	elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 ) { return 'BOCU-1' } # FB EE 28  (BOCU-1)
	elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33) { return 'GB-18030' } # 84 31 95 33 (GB-18030)
	else { return 'ASCII or UTF8-noBOM' }
}

function encodingSet {
    <#
    .SYNOPSIS
        set encoding (output encoding, console output or input encoding)
		the encoding is set outside of the scope's function, it's globally set (on your session only)
		be carrefull as this seems to break the ui when using the console interactively
    #>
	param (
		[Parameter(Mandatory = $True)][System.Text.Encoding]$encoding,
		[switch]$setAllEncodings,
		[switch]$SetOutputEncoding,
		[switch]$SetConsoleOutputEncoding,
		[switch]$SetConsoleInputEncoding
	)
    if ($setAllEncodings -or $SetOutputEncoding) {$OutputEncoding = $encoding}
    if ($setAllEncodings -or $SetConsoleOutputEncoding) {[Console]::OutputEncoding = $encoding}
    if ($setAllEncodings -or $SetConsoleInputEncoding) {[console]::InputEncoding = $encoding}
}

function encodingRestore {
    <#
    .SYNOPSIS
        restore encoding to default (output encoding, console output or input encoding)
		the encoding is set outside of the scope's function, it's globally set (on your session only)
    #>
	param (
		[switch]$restoreAllEncodings,
		[switch]$restoreOutputEncoding,
		[switch]$restoreConsoleOutputEncoding,
		[switch]$restoreConsoleInputEncoding
	)
    if ($restoreAllEncodings -or $restoreOutputEncoding) {$OutputEncoding = $OutputEncodingBk}
    if ($restoreAllEncodings -or $restoreConsoleOutputEncoding) {[Console]::OutputEncoding = $ConsoleOutputEncodingBk}
    if ($restoreAllEncodings -or $restoreConsoleInputEncoding) {[console]::InputEncoding = $ConsoleInputEncodingBk}
}

#######################################################################################################################
############### GIT
#######################################################################################################################
function gitCd {
	<#
	.SYNOPSIS
		move to git repo directory
	#>
	Set-Location $gitlocation
}

function gitPullAllRepos {
	<#
	.SYNOPSIS
		update your git repos using git pull origin master
	#>
	$cwd = $(Get-Location).path
	gitCd
	Get-ChildItem | Where-Object {$_.psiscontainer -eq $true} | foreach-object {
		Set-Location $_.fullname;
		if (test-path "./.git/") {
			write-host $(Get-Location);
			git pull origin master;
		}
	}
	Set-Location $cwd
}

function gitCloneAllReposFromProfile {
	Param (
		[string]$userProfile ,
		[string]$localDir = "." ,
		[ValidateSet('git', 'https')][string]$cloneMode = 'https'
	)
	$per_page = 100
	$page = 1
	$url = "https://api.github.com/users/$userProfile/repos?per_page=$per_page&page=$page"
	$apiRes = @()
	$apiResPage = $null
	while ($null -eq $apiResPage -or $apiResPage.count -gt 0) {
		try {
			print "github api page $page"
			$apiResPage = Invoke-RestMethod -Method Get -uri $url
			$apiRes += $apiResPage
			$page += 1
			$url = "https://api.github.com/users/$userProfile/repos?per_page=$per_page&page=$page"
		} catch {
			write-error "shit happened :'(`n$_"
		}
	}
	$cwd = $(Get-Location).path
	Set-Location $localDir
	foreach ($repo in $apiRes) {
		if ($cloneMode -eq "https") {
			$urlClone = $repo.clone_url
		} else {
			$urlClone = $repo.ssh_url
		}
		print "clonning $($repo.name) ($urlClone)"
		git clone "$urlClone"
	}
	Set-Location $cwd
	
}

function gitPowershellProfileRepoPush {
	<#
	.SYNOPSIS
		update the project powershellProfile project using git
	#>
	Param (
		[Parameter(Mandatory = $false)][string]$commitMess = "updated profile"
	)
	gitCd
	Set-Location powershellProfile
	Copy-Item $PROFILE "./profile.ps1"
	edit "./profile.ps1"
	read-host "Please remove any personnal stuff remaining in your profile and press enter to commit"
	git add "profile.ps1"
	git commit -m $commitMess
	git push origin master
}

#######################################################################################################################
############### DOCKER
#######################################################################################################################
function _dockerInfos {
	print "process:"
	processSearch -filterStr "Name like '%wsl%' or Name like '%docker%'"
	print "services:"
	Get-Service | Where-Object {$_.ServiceName -like '*wsl*' -or $_.ServiceName -like '*docker*'} | Select-Object ServiceName, DisplayName, Status, StartType | Format-Table -AutoSize
	print "wsl distros:"
	wsl -l -v
}

function dockerStart {
	Set-Service -Name "com.docker.service" -StartupType Manual

	print "starting docker service"

	Start-Service -Name "com.docker.service"
	print "you can launch docker desktop"

	_dockerInfos
}

function dockerStop {
	Set-Service -Name "com.docker.service" -StartupType Manual

	print "shutdown wsl and stop docker service"

	wsl -t "docker-desktop-data"
	wsl -t "docker-desktop"
	Stop-Service -Name "com.docker.service"

	_dockerInfos
}

#######################################################################################################################
############### ONSTARTUP
#######################################################################################################################
foreach ($script in $aditionnalScriptsLastExec) {
	. $script
}

Set-Variable OutputEncodingBk -option ReadOnly -value $OutputEncoding
Set-Variable ConsoleOutputEncodingBk -option ReadOnly -value $([Console]::OutputEncoding)
Set-Variable ConsoleInputEncodingBk -option ReadOnly -value $([console]::InputEncoding)

print "powershell $_powershellVersionStr `n"
if ($cdToStartDirOnStartup -eq $true) {Set-Location $startDir}
if ($profileFunctionsExecOnStartup -eq $true) {profileFunctions}
