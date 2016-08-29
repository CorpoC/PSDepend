Function Test-Dependency {
    <#
    .SYNOPSIS
        Test a specific dependency

    .DESCRIPTION
        Test a specific dependency.  Validates whether a dependency exists

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * Appends a 'DependencyExists' property indicating whether the dependency exists; alternatively
          * Returns $True or $False if the -Quiet switch is used

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only test dependencies that are tagged with all of the specified Tags (-and, not -or)

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Test-Dependency

        Get dependencies from C:\requirements.psd1 and test whether they exist

    .LINK
        about_PSDepend

    .LINK
        about_PSDepend_Definitions

    .LINK
        Get-Dependency

    .LINK
        Get-PSDependType

    .LINK
        Invoke-PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/PSDepend
    #>
    [cmdletbinding()]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ParameterSetName='Map',
                    Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject[]]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags,

        [switch]$Quiet
    )
    Begin
    {
        # This script reads a depend.psd1, installs dependencies as defined
        Write-Verbose "Running Test-Dependency with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"
    }
    Process
    {
        Write-Verbose "Dependencies:`n$($Dependency | Out-String)"

        #Get definitions, and dependencies in this particular psd1
        $DependencyDefs = Get-PSDependScript
        $TheseDependencyTypes = @( $Dependency.DependencyType | Sort-Object -Unique )

        #call each dependencytype script for applicable dependencies
        foreach($DependencyType in $TheseDependencyTypes)
        {
            $DependencyScript = $DependencyDefs.$DependencyType
            if(-not $DependencyScript)
            {
                Write-Error "DependencyType $DependencyType is not defined in PSDependMap.psd1"
                continue
            }
            $TheseDependencies = @( $Dependency | Where-Object {$_.DependencyType -eq $DependencyType})

            #Define params for the script
            #Each dependency type can have a hashtable to splat.
            $RawParameters = Get-Parameter -Command $DependencyScript
            $ValidParamNames = $RawParameters.Name

            if($ValidParamNames -notcontains 'PSDependAction')
            {
                Write-Error "No PSDependAction found on PSDependScript [$DependencyScript]. Skipping [$($Dependency.DependencyName)]"
                continue
            }

            foreach($ThisDependency in $TheseDependencies)
            {
                #Parameters for dependency types.  Only accept valid params...
                if($ThisDependency.Parameters.keys.count -gt 0)
                {
                    $splat = @{}
                    foreach($key in $ThisDependency.Parameters.keys)
                    {
                        if($ValidParamNames -contains $key)
                        {
                            $splat.Add($key, $ThisDependency.Parameters.$key)
                        }
                        else
                        {
                            Write-Warning "Parameter [$Key] with value [$($ThisDependency.Parameters.$Key)] is not a valid parameter for [$DependencyType], ignoring.  Valid params:`n[$ValidParamNames]"
                        }
                    }
                    if($splat.ContainsKey('PSDependAction'))
                    {
                        $Splat['PSDependAction'] = 'Test'
                    }
                    else
                    {
                        $Splat.add('PSDependAction','Test')
                    }
                }
                else
                {
                    $splat = @{PSDependAction = 'Test'}
                }

                #Define params for the script
                $splat.add('Dependency', $ThisDependency)

                $TestResult = . $DependencyScript @splat
                if($Quiet)
                {
                    $TestResult
                }
                else
                {
                    $ThisDependency | Select-Object -Property *, @{n='DependencyExists'; e={$TestResult}}
                }
            }
        }
    }
}
