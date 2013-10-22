# These utility functions have been extracted from the Pscx.Utility.psm1 module
# of the Powershell Community Extensions, which is here: http://pscx.codeplex.com/

<#
.SYNOPSIS
    Invokes the specified batch file and retains any environment variable changes it makes.
.DESCRIPTION
    Invoke the specified batch file (and parameters), but also propagate any  
    environment variable changes back to the PowerShell environment that  
    called it.
.PARAMETER Path
    Path to a .bat or .cmd file.
.PARAMETER Parameters
    Parameters to pass to the batch file.
.PARAMETER RedirectStdErrToNull
    Whether to redirect the stderr of the batch file to null. Necessary for some scripts such
    as the Windows SDK SetEnv.cmd script. Defaults to $false for compatibility with other calls
    to this function.
.EXAMPLE
    C:\PS> Invoke-BatchFile "$env:ProgramFiles\Microsoft Visual Studio 9.0\VC\vcvarsall.bat"
    Invokes the vcvarsall.bat file.  All environment variable changes it makes will be
    propagated to the current PowerShell session.
.NOTES
    Author: Lee Holmes (slight modifications by JN)
#>
Function Invoke-BatchFile
{
    param([string]$Path, [string]$Parameters, [bool]$RedirectStdErrToNull = $false)

    $tempFile = [IO.Path]::GetTempFileName()  

    ## Store the output of cmd.exe.  We also ask cmd.exe to output   
    ## the environment table after the batch file completes  
    if ($RedirectStdErrToNull -eq $true) {
        (cmd.exe /c " `"$Path`" $Parameters && set > `"$tempFile`" ") 2> $null
    } else {
        cmd.exe /c " `"$Path`" $Parameters && set > `"$tempFile`" "
    }
    
    ## Go through the environment variables in the temp file.  
    ## For each of them, set the variable in our local environment.  
    Get-Content $tempFile | Foreach-Object {   
        if ($_ -match "^(.*?)=(.*)$")  
        { 
            Set-Content "env:\$($matches[1])" $matches[2]  
        } 
    }  

    Remove-Item $tempFile
}

<#
.SYNOPSIS
    Imports environment variables for the specified version of Visual Studio.
.DESCRIPTION
    Imports environment variables for the specified version of Visual Studio. 
    This function requires the PowerShell Community Extensions. To find out 
    the most recent set of Visual Studio environment variables imported use 
    the cmdlet Get-EnvironmentVars.  If you want to revert back to a previous 
    Visul Studio environment variable configuration use the cmdlet 
    Pop-EnvironmentVars.
.PARAMETER VisualStudioVersion
    The version of Visual Studio to import environment variables for. Valid 
    values are 2008, 2010 and 2012.
.PARAMETER Architecture
    Selects the desired architecture to configure the environment for. 
	Defaults to x86 if running in 32-bit PowerShell, otherwise defaults to 
	amd64.
.PARAMETER Configuration
    Selects the desired configuration in case of the Windows SDK. Defaults to
    Release if not specified.
.EXAMPLE
    C:\PS> Import-VisualStudioVars 2010

    Sets up the environment variables to use the VS 2010 compilers. Defaults 
	to x86 if running in 32-bit PowerShell, otherwise defaults to amd64.
.EXAMPLE
    C:\PS> Import-VisualStudioVars 2012 arm

    Sets up the environment variables for the VS 2012 arm compiler.
#>
Function Import-VisualStudioVars
{
    param
    (
        [Parameter(Mandatory = $true, Position = 0)][ValidateSet('2010', '2012', '2013', 'WindowsSDK7.1')][string]$VisualStudioVersion,
        [Parameter(Position = 1)][string]$Architecture = 'amd64',
        [Parameter(Position = 2)][string]$Configuration = 'release'
    )
 
    End
    {
        switch ($VisualStudioVersion)
        {
            '2010' {
                Push-Environment
                Invoke-BatchFile (Join-Path $env:VS100COMNTOOLS "..\..\VC\vcvarsall.bat") -Parameters $Architecture -RedirectStdErrToNull $false
            }
 
            '2012' {
                Push-Environment
                Invoke-BatchFile (Join-Path $env:VS110COMNTOOLS "..\..\VC\vcvarsall.bat") -Parameters $Architecture -RedirectStdErrToNull $false
            }

            '2013' {
                Push-Environment
                Invoke-BatchFile (Join-Path $env:VS120COMNTOOLS "..\..\VC\vcvarsall.bat") -Parameters $Architecture -RedirectStdErrToNull $false
            }

            'WindowsSDK7.1' {
                if ($Architecture -eq "amd64") {
                    $architectureParameter = "/x64"
                } elseif ($Architecture -eq "x86") {
                    $architectureParameter = "/x86"
                } else {
                    Write-Host "Unknown Configuration: $configuration"
                    return
                }

                if ($Configuration -eq "release") {
                    $configurationParameter = "/release"
                } elseif ($configuration -eq "debug") {
                    $configurationParameter = "/debug"
                } else {
                    Write-Host "Unknown Configuration: $configuration"
                    return
                }

                Push-Environment
                Invoke-BatchFile (Join-Path $env:ProgramFiles "Microsoft SDKs\Windows\v7.1\Bin\setenv.cmd") -Parameters "$configurationParameter $architectureParameter" -RedirectStdErrToNull $true
            }
 
            default {
                Write-Error "Import-VisualStudioVars doesn't recognize VisualStudioVersion: $VisualStudioVersion"
            }
        }
    }
}

Function Get-GuessedVSVersion {
    
    #Platform SDK (since it seems to set VS100COMNTOOLS even without Visual Studio 2010 installed)
    if (Test-Path (Join-Path $env:ProgramFiles "Microsoft SDKs\Windows\v7.1\Bin\setenv.cmd")) {
        return 'WindowsSDK7.1'
    }

    #Visual Studio's, newest versions first

    #Visual Studio 2013
    if ((Test-Path env:\VS120COMNTOOLS) -and (Test-Path (Join-Path $env:VS120COMNTOOLS "..\..\VC\vcvarsall.bat"))) {
        return '2013'
    }
    
    #Visual Studio 2012
    if ((Test-Path env:\VS110COMNTOOLS) -and (Test-Path (Join-Path $env:VS110COMNTOOLS "..\..\VC\vcvarsall.bat"))) {
        return '2012'
    }

    #Visual Studio 2010
    if ((Test-Path env:\VS100COMNTOOLS) -and (Test-Path (Join-Path $env:VS100COMNTOOLS "..\..\VC\vcvarsall.bat"))) {
        return '2010'
    }

    throw "Can't find any of VS2010-2013 or WindowsSDK7.1."
}