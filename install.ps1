# Installateur graphique pour Cogify
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# --- Fenêtre ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Installation de Cogify"
$form.Size = New-Object System.Drawing.Size(480, 230)
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
$detail.Size = New-Object System.Drawing.Size(420, 70)
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

# Exécute un script en arrière-plan tout en gardant la fenêtre réactive
function Wait-Job-Responsive($job) {
    while ($job.State -eq "Running") {
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.Application]::DoEvents()
    }
    return Receive-Job -Job $job -ErrorAction SilentlyContinue
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
            Set-Status "Conda n'est pas installe sur cette machine." "Cogify a besoin de Conda pour installer GDAL (lecture/ecriture des fichiers geo)."

            $progress.Style = "Continuous"
            $progress.Value = 0

            $installer = "$env:TEMP\miniconda_installer.exe"
            $uri = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"

            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $downloadComplete = $false
            $downloadError = $null

            Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier WebClientProgress | Out-Null
            Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -SourceIdentifier WebClientCompleted | Out-Null

            try {
                $webClient.DownloadFileAsync([Uri]$uri, $installer)

                while (-not $downloadComplete) {
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.Application]::DoEvents()

                    $progressEvent = Get-Event -SourceIdentifier WebClientProgress -ErrorAction SilentlyContinue
                    if ($progressEvent) {
                        $pct = $progressEvent.SourceEventArgs.ProgressPercentage
                        $progress.Value = $pct
                        $detail.Text = "Telechargement de Miniconda en cours... $pct%"
                        Remove-Event -SourceIdentifier WebClientProgress -ErrorAction SilentlyContinue
                    }

                    $completedEvent = Get-Event -SourceIdentifier WebClientCompleted -ErrorAction SilentlyContinue
                    if ($completedEvent) {
                        if ($completedEvent.SourceEventArgs.Error) {
                            $downloadError = $completedEvent.SourceEventArgs.Error
                        }
                        $downloadComplete = $true
                        Remove-Event -SourceIdentifier WebClientCompleted -ErrorAction SilentlyContinue
                    }
                }
            } finally {
                Unregister-Event -SourceIdentifier WebClientProgress -ErrorAction SilentlyContinue
                Unregister-Event -SourceIdentifier WebClientCompleted -ErrorAction SilentlyContinue
                $webClient.Dispose()
            }

            $progress.Style = "Marquee"

            if ($downloadError -or -not (Test-Path $installer)) {
                Show-Error "Le telechargement de Miniconda a echoue.`nVerifiez votre connexion internet.`n`n$downloadError"
            }

            Set-Status "Installation de Miniconda..." "Installation silencieuse de Miniconda (gestionnaire d'environnements Python) dans $env:USERPROFILE\miniconda3."
            $targetDir = "$env:USERPROFILE\miniconda3"
            $job = Start-Job -ScriptBlock {
                param($installer, $targetDir)
                Start-Process -FilePath $installer -ArgumentList "/InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /S /D=$targetDir" -Wait
            } -ArgumentList $installer, $targetDir
            Wait-Job-Responsive $job | Out-Null
            Remove-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Item $installer -Force -ErrorAction SilentlyContinue

            $condaBat = "$targetDir\condabin\conda.bat"
            if (-not (Test-Path $condaBat)) {
                Show-Error "Conda introuvable apres installation de Miniconda."
            }
        }

        # --- 2. Installation du solveur libmamba (resolution de dependances bien plus rapide) ---
        Set-Status "Preparation de Conda..." "Installation du solveur rapide (libmamba)."
        $job = Start-Job -ScriptBlock {
            param($condaBat)
            cmd.exe /c "`"$condaBat`" install -n base -y conda-libmamba-solver"
        } -ArgumentList $condaBat
        Wait-Job-Responsive $job | Out-Null
        Remove-Job -Job $job -ErrorAction SilentlyContinue

        # --- 3. Création de l'environnement conda ---
        Set-Status "Creation de l'environnement Cogify..." "Installation de Python, GDAL et Streamlit (plusieurs minutes)."
        $job = Start-Job -ScriptBlock {
            param($condaBat, $here)
            cmd.exe /c "`"$condaBat`" env create -f `"$here\app\environment.yml`" --solver=libmamba --force"
        } -ArgumentList $condaBat, $here
        Wait-Job-Responsive $job | Out-Null
        $envFailed = $job.State -eq "Failed"
        Remove-Job -Job $job -ErrorAction SilentlyContinue
        if ($envFailed) {
            Show-Error "Erreur lors de la creation de l'environnement conda."
        }

        # --- 4. Création du raccourci ---
        Set-Status "Creation du raccourci sur le bureau..."
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cogify.lnk")
        $Shortcut.TargetPath = Join-Path $here "app\lancer_cogify.vbs"
        $Shortcut.WorkingDirectory = (Join-Path $here "app")
        $Shortcut.IconLocation = "imageres.dll,87"
        $Shortcut.Save()

        $progress.Style = "Continuous"
        $progress.Value = 100
        Set-Status "Installation terminee !" "Lancez 'Cogify' depuis le bureau."
        [System.Windows.Forms.MessageBox]::Show("Installation terminee avec succes !`n`nLancez 'Cogify' depuis le raccourci sur le bureau.", "Cogify", "OK", "Information") | Out-Null
    } catch {
        Show-Error "Erreur inattendue :`n$_"
    }
    $form.Close()
})

[void]$form.ShowDialog()





