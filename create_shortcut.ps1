# Crée le raccourci "Cogify" sur le bureau
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cogify.lnk")
$Shortcut.TargetPath = Join-Path $here "lancer_cogify.vbs"
$Shortcut.WorkingDirectory = $here
$Shortcut.IconLocation = "imageres.dll,87"
$Shortcut.Save()

Write-Host "Raccourci 'Cogify' cree sur le bureau."
