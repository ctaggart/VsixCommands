$vs = Get-VSSetupInstance
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installershell.exe" modify --quiet `
    --installPath $vs.InstallationPath `
    --remove Microsoft.VisualStudio.Component.FSharp