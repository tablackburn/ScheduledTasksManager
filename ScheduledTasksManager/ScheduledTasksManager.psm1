# Dot source functions
$publicFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$publicFunctions = Get-ChildItem -Path $publicFunctionsPath -Filter '*.ps1' -Recurse -ErrorAction 'Stop'
$privateFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$privateFunctions = Get-ChildItem -Path $privateFunctionsPath -Filter '*.ps1' -Recurse -ErrorAction 'Stop'
$allFunctions = @()
$allFunctions += $publicFunctions
$allFunctions += $privateFunctions
foreach ($function in $allFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Unable to dot source '$($function.FullName)'"
        throw $_
    }
}

Export-ModuleMember -Function $publicFunctions.BaseName
