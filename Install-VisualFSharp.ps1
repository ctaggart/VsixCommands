$vs = Get-VSSetupInstance
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installershell.exe" modify --quiet `
    --installPath $vs.InstallationPath `
    --add Microsoft.VisualStudio.Component.FSharp