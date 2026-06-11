# Installateur graphique pour Cogify
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# --- Fenêtre ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Installation de Cogify"
$form.Size = New-Object System.Drawing.Size(460, 200)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Initialisation..."
$label.AutoSize = $false
$label.Size = New-Object System.Drawing.Size(420, 40)
$label.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($label)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = "Marquee"
$progress.MarqueeAnimationSpeed = 30
$progress.Size = New-Object System.Drawing.Size(420, 25)
$progress.Location = New-Object System.Drawing.Point(20, 70)
$form.Controls.Add($progress)

$detail = New-Object System.Windows.Forms.Label
$detail.Text = ""
$detail.AutoSize = $false
$detail.ForeColor = [System.Drawing.Color]::Gray
$detail.Size = New-Object System.Drawing.Size(420, 40)
$detail.Location = New-Object System.Drawing.Point(20, 105)
$form.Controls.Add($detail)

function Set-Status($text, $sub = "") {
    $label.Text = $text
    $detail.Text = $sub
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Error($msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, "Erreur d'installation", "OK", "Error") | Out-Null
    $form.Close()
    exit 1
}

$form.Add_Shown({
    try {
        # --- 1. Recherche de conda existant ---
        Set-Status "Recherche de Conda..."
        $condaPaths = @(
            "$env:ProgramData\miniconda3\condabin\conda.bat",
            "$env:USERPROFILE\miniconda3\condabin\conda.bat",
            "$env:ProgramData\Anaconda3\condabin\conda.bat",
            "$env:USERPROFILE\Anaconda3\condabin\conda.bat"
        )
        $condaBat = $condaPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $condaBat) {
            Set-Status "Téléchargement de Miniconda..." "Cela peut prendre quelques minutes."
            $installer = "$env:TEMP\miniconda_installer.exe"
            try {
                Invoke-WebRequest -UseBasicParsing -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile $installer
            } catch {
                Show-Error "Le telechargement de Miniconda a echoue.`nVerifiez votre connexion internet.`n`n$_"
            }

            Set-Status "Installation de Miniconda..." "Installation silencieuse en cours."
            $targetDir = "$env:USERPROFILE\miniconda3"
            Start-Process -FilePath $installer -ArgumentList "/InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /S /D=$targetDir" -Wait
            Remove-Item $installer -Force -ErrorAction SilentlyContinue

            $condaBat = "$targetDir\condabin\conda.bat"
            if (-not (Test-Path $condaBat)) {
                Show-Error "Conda introuvable apres installation de Miniconda."
            }
        }

        # --- 2. Création de l'environnement conda ---
        Set-Status "Création de l'environnement Cogify..." "Installation de Python, GDAL et Streamlit (plusieurs minutes)."
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"`"$condaBat`" env create -f environment.yml --force`"" -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -ne 0) {
            Show-Error "Erreur lors de la creation de l'environnement conda (code $($proc.ExitCode))."
        }

        # --- 3. Création du raccourci ---
        Set-Status "Création du raccourci sur le bureau..."
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cogify.lnk")
        $Shortcut.TargetPath = Join-Path $here "lancer_cogify.vbs"
        $Shortcut.WorkingDirectory = $here
        $Shortcut.IconLocation = "imageres.dll,87"
        $Shortcut.Save()

        $progress.Style = "Continuous"
        $progress.Value = 100
        Set-Status "Installation terminée !" "Lancez 'Cogify' depuis le bureau."
        [System.Windows.Forms.MessageBox]::Show("Installation terminee avec succes !`n`nLancez 'Cogify' depuis le raccourci sur le bureau.", "Cogify", "OK", "Information") | Out-Null
    } catch {
        Show-Error "Erreur inattendue :`n$_"
    }
    $form.Close()
})

[void]$form.ShowDialog()
