<#
    .SYNOPSIS
        Installs Terraform

    .DESCRIPTION
        Downloads and places the desired version of terraform on the PATH

        Relevant Dependency metadata:
            DependencyName (Key): This should be terraform
            Target: The folder to download this file to.  If a full path to a new file is used, this overrides any other file name.
            AddToPath: If specified, prepend the target's parent container to PATH

    .NOTES

    .PARAMETER Architecture
    The architecture of the binary to install. Defaults to amd64

    .PARAMETER PSDependAction
    Test or Install the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE
    @{
    'terraform' = @{
        DependencyType = "Terraform"
        Version        = "1.1.1"
    }

    Downloads terraform v1.1.1 to the current working directory

    .EXAMPLE
    @{
    'terraform' = @{
        DependencyType = "Terraform"
        Target         = "./Tools"
        Version        = "1.2.0"
    }

    Downloads terraform v1.2.0 to the target path relative from the current working directory. It will create the Tools folder if it doesn't already exist.

    This is the recommended setup in conjunction with a local folder within your repo that is untracked by VCS where your dependencies are local to your code and
    you can specify a path that is not impacted by platform you are running PSDepend on

    .EXAMPLE
    @{
    'terraform' = @{
        DependencyType = "Terraform"
        Target         = "/usr/bin/local"
        Version        = "1.2.0"
    }

    Downloads terraform v1.2.0 to the absolute path

    .EXAMPLE
    @{
    'terraform' = @{
        DependencyType = "Terraform"
        Parameters = @{
            Architecture = "arm"
        }
        Version        = "1.2.0"
    }

    Downloads terraform v1.2.0 for ARM architecture
}
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    $Architecture = "amd64",

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

$VersionRegex = "(?<version>\d+\.\d+.\d+)(-(?<prereleasetag>.+)){0,1}$"
$Source = $Dependency.Source
$tf = Get-InstalledTerraformVersion
$Version = Select-String -Pattern $VersionRegex -InputObject $Dependency.Version

if (-not $Version) {
    throw "Input version does not match regex"
}

$Platform = ((Get-OSEnvironment) -eq "MacOS" ? "darwin" : (Get-OSEnvironment)).ToLower()
$FileName = "terraform_{0}_{1}_{2}.zip" -f $Version, $Platform, $Architecture
$DownloadPath = Join-Path $env:TEMP $FileName
if (-not $Dependency.target) {
    $Path = Get-Location
}
else {
    $Path = $Dependency.Target
}

if ($tf.IsInstalled) {
    if ($tf.Version -ne $Version) {
        Write-Verbose "Installed Terraform v$($tf.Version) does not match version v$($Version) required"
        $ToInstall = $true
    }
    else {
        Write-Verbose "Terraform v$($tf.Version) installed"
        $ToInstall = $false
    }
}
else {
    Write-Verbose "Terraform not found on path"
    $ToInstall = $true
}

if ($PSDependAction -eq "Install" -and $ToInstall -eq $true) {
    if ($Source) {
        $URL = $Source
    }
    else {
        $URL = "https://releases.hashicorp.com/terraform/{0}/{1}" -f $Version, $FileName
    }
    Write-Verbose "Downloading [$URL] to [$DownloadPath]"

    if (-not (Test-Path $DownloadPath)) {
        Write-Verbose "Version of zip not found at $DownloadPath"
        try {
            Get-WebFile -URL $URL -Path $DownloadPath
        }
        catch {
            $_
            throw "Unable to retrieve package from $URL"
        }
    }
    else {
        Write-Verbose "Version of zip found at $DownloadPath"
    }

    $Out = Expand-Archive -Path $DownloadPath -DestinationPath $Path -Force -PassThru
    Write-Verbose "Terraform installed to $Out"

    if ($Dependency.AddToPath) {
        Write-Verbose "Setting PATH to`n$($Path, $env:PATH -join ';' | Out-String)"
        Add-ToItemCollection -Reference Env:\Path -Item $Path
    }

    return $true
}
elseif ($PSDependAction -eq "Install" -and $ToInstall -eq $false) {
    return $true
}
elseif ($PSDependAction -eq "Test") {
    return $ToInstall -eq $true ? $false : $true
}