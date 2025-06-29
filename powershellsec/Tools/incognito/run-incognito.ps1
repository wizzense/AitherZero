# incognito.exe does not run reliably in powershell_ise.exe.


if ($host.Name -eq "ConsoleHost")
{ 
    "`n.\incognito.exe list_tokens -u`n"
    .\incognito.exe list_tokens -u 
    "`n"
}
else
{ 
    $pdir = $pwd 
    Start-Process -FilePath powershell.exe -ArgumentList "-noexit cd $pdir ; .\run-incognito.ps1" 
} 



