Import-Module './aither-core/AitherCore' -Force

Write-Host "Checking loaded aither-core modules:"
$modules = Get-Module | Where-Object { $_.Path -like '*aither-core*' }
$modules | Select-Object Name, Version, ModuleType | Format-Table

Write-Host "All loaded modules:"
Get-Module | Select-Object Name | Format-Table
