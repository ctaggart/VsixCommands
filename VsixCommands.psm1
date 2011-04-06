$extensionManager = [Microsoft.VisualStudio.Shell.Package]::GetGlobalService([Microsoft.VisualStudio.ExtensionManager.SVsExtensionManager])
$extensionRepository = [Microsoft.VisualStudio.Shell.Package]::GetGlobalService([Microsoft.VisualStudio.ExtensionManager.SVsExtensionRepository])
$VSInstallDir = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\VisualStudio\10.0 InstallDir | Select -ExpandProperty InstallDir
$vsixInstallerPath = Join-Path $VSInstallDir VSIXInstaller.exe

function Get-InstalledVsix {
    param(
        [string]
        [parameter(Mandatory = $true)]
        $VsixId
    )
    
    $vsix = $null
    if($extensionManager.TryGetInstalledExtension($VsixId, [ref]$vsix)) {
        $vsix
    }
    else {
        $null
    }
}

function Install-Vsix {
    param(
        [string]
        [parameter(Mandatory = $true)]
        $VsixPath
    )
        
    Start-Process $vsixInstallerPath -ArgumentList $VsixPath -Wait
}

function Install-GalleryVsix {
    param(
        [string]
        [parameter(Mandatory = $true)]
        $NameOrId
    )

    # Check to see if the vsix is already installed
    $extension = Get-InstalledVsix $NameOrId

    if($extension) {
        throw "'$NameOrId' is already installed."
    }
    
    # Calling generic methods in PS is a mess
    $createQueryMethod = $extensionRepository.GetType().GetMethods() | ?{ $_.Name -eq 'CreateQuery' -and $_.GetParameters().Length -eq 0 }
    $createQueryMethod = $createQueryMethod.MakeGenericMethod([Microsoft.VisualStudio.ExtensionManager.UI.VsGalleryEntry])

    # All of that to call CreateQuery<VsGalleryEntry>()
    $query = $createQueryMethod.Invoke($extensionRepository, $null)
    
    # Builds the expression e.VsixId == $NameOrId
    # We have to the expression dynamically
    $param = [Linq.Expressions.Expression]::Parameter([Microsoft.VisualStudio.ExtensionManager.UI.VsGalleryEntry])
    $vsixIdEquals = Get-EqualExpression $param "VsixID" $NameOrId
    
    # Builds the entire lambda
    $lambda = [Linq.Expressions.Expression]::Lambda($vsixIdEquals, $param)

    $quotedLambda = [Linq.Expressions.Expression]::Quote($lambda)
    $call = [Linq.Expressions.Expression]::Call([Linq.Queryable], "Where", @($query.ElementType), @($query.Expression, $quotedLambda))
    
    # Invoke the query
    # More powershell bugs... We need to call CreateQuery so we can build the linq expression dynamically
    $createQueryMethod = [Linq.IQueryProvider].GetMethods() | ?{ $_.Name -eq 'CreateQuery' -and !$_.IsGenericMethod }
    $vsix = @($createQueryMethod.Invoke($query.Provider, $call))[0]

    if(!$vsix) {
        # Try doing a plain search
        $createQueryMethod = $extensionRepository.GetType().GetMethods() | ?{ $_.Name -eq 'CreateQuery' -and $_.GetParameters().Length -eq 0 }
        $createQueryMethod = $createQueryMethod.MakeGenericMethod([Microsoft.VisualStudio.ExtensionManager.UI.VsGalleryEntry])
        $query = $createQueryMethod.Invoke($extensionRepository, $null)
        $query.SearchText = $NameOrId

        # After getting results back, look at the product name to see if it contains to id so we can do further filtering
        $results = @($query | ?{ $_.Name.IndexOf($NameOrId, [StringComparison]::OrdinalIgnoreCase) -gt -1 -and $_.VsixID })

        # If we have an ambiguous match then throw
        if($results.Count -gt 1) {
            throw "Ambiguous matches found: {0}. Try being more specific." -f ([String]::Join(", ", ($results | %{ $_.Name + " ($($_.VsixID))" })))
        }

        $vsix = $results[0]
    }
        
    if($vsix) {
        Write-Host "Found extension '$($vsix.Name) ($($vsix.VsixID))'"

        Write-Host "Downloading..."

        # Download the extension
        $installableExtension = $extensionRepository.Download($vsix)
        
        Write-Host "Launching the VSIX installer..."

        # Exeute the VSIX installer on the extension
        Install-Vsix $installableExtension.PackagePath

        # Check to see if the vsix was installed
        $extension = Get-InstalledVsix $NameOrId

        if($extension) {
            Write-Warning "You probably need to restart VS for the changes to take effect"
        }
    }
    else {
        throw "Unable to find VSIX matching '$NameOrId'"
    }
}

function Get-EqualExpression {
    param(
        $param,
        $propertyName,
        $value
    )
    # Since the vsix is is hard to find, we look for product name as well
    # Builds the expression e.$propertyName == $value
    $left = [Linq.Expressions.Expression]::Property($param, $propertyName)
    $right = [Linq.Expressions.Expression]::Constant($value)
    [Linq.Expressions.Expression]::Equal($left, $right)
}