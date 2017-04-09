$vs = Get-VSSetupInstance
Start-Process (Join-Path $vs.InstallationPath 'Common7\IDE\VSIXInstaller.exe') -ArgumentList '/q', '/u:VisualFSharp' -Wait