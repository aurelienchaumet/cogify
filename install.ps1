# Installateur graphique pour Cogify
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# --- Fenêtre ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Installation de Cogify"
$form.Size = New-Object System.Drawing.Size(520, 270)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Initialisation..."
$label.AutoSize = $false
$label.Size = New-Object System.Drawing.Size(460, 40)
$label.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($label)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = "Marquee"
$progress.MarqueeAnimationSpeed = 30
$progress.Size = New-Object System.Drawing.Size(460, 25)
$progress.Location = New-Object System.Drawing.Point(20, 70)
$form.Controls.Add($progress)

$detail = New-Object System.Windows.Forms.Label
$detail.Text = ""
$detail.AutoSize = $false
$detail.ForeColor = [System.Drawing.Color]::Gray
$detail.Size = New-Object System.Drawing.Size(460, 100)
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

# Exécute un script en arrière-plan tout en gardant la fenêtre réactive,
# et affiche le temps écoulé / la dernière ligne d'un fichier de log
function Wait-Job-Responsive($job, $baseText = "", $logFile = $null) {
    $start = Get-Date
    while ($job.State -eq "Running") {
        Start-Sleep -Milliseconds 200
        [System.Windows.Forms.Application]::DoEvents()

        if ($baseText) {
            $elapsed = [int]((Get-Date) - $start).TotalSeconds
            $line = ""
            if ($logFile -and (Test-Path $logFile)) {
                $lastLine = Get-Content -Path $logFile -Tail 1 -ErrorAction SilentlyContinue
                if ($lastLine) { $line = "`n$lastLine" }
            }
            $detail.Text = "$baseText (ecoule : ${elapsed}s)$line"
            $form.Refresh()
        }
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

                    $progressEvents = @(Get-Event -SourceIdentifier WebClientProgress -ErrorAction SilentlyContinue)
                    if ($progressEvents.Count -gt 0) {
                        $pct = $progressEvents[-1].SourceEventArgs.ProgressPercentage
                        $progress.Value = [int]$pct
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
            Wait-Job-Responsive $job "Installation de Miniconda en cours, merci de patienter" | Out-Null
            Remove-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Item $installer -Force -ErrorAction SilentlyContinue

            $condaBat = "$targetDir\condabin\conda.bat"
            if (-not (Test-Path $condaBat)) {
                Show-Error "Conda introuvable apres installation de Miniconda."
            }
        }

        # --- 2. Installation du solveur libmamba (resolution de dependances bien plus rapide) ---
        Set-Status "Preparation de Conda..." "Installation du solveur rapide (libmamba)."
        $logFile = "$env:TEMP\cogify_install_libmamba.log"
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
        $job = Start-Job -ScriptBlock {
            param($condaBat, $logFile)
            cmd.exe /c "`"$condaBat`" install -n base -y conda-libmamba-solver > `"$logFile`" 2>&1"
        } -ArgumentList $condaBat, $logFile
        Wait-Job-Responsive $job "Installation du solveur rapide (libmamba)" $logFile | Out-Null
        Remove-Job -Job $job -ErrorAction SilentlyContinue

        # --- 2bis. Acceptation des conditions d'utilisation des canaux par defaut ---
        Set-Status "Preparation de Conda..." "Acceptation des conditions d'utilisation des canaux Anaconda."
        $logFile = "$env:TEMP\cogify_install_tos.log"
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
        $job = Start-Job -ScriptBlock {
            param($condaBat, $logFile)
            $channels = @(
                "https://repo.anaconda.com/pkgs/main",
                "https://repo.anaconda.com/pkgs/r",
                "https://repo.anaconda.com/pkgs/msys2"
            )
            foreach ($c in $channels) {
                cmd.exe /c "`"$condaBat`" tos accept --override-channels --channel $c >> `"$logFile`" 2>&1"
            }
        } -ArgumentList $condaBat, $logFile
        Wait-Job-Responsive $job "Acceptation des conditions d'utilisation" $logFile | Out-Null
        Remove-Job -Job $job -ErrorAction SilentlyContinue

        # --- 3. Création de l'environnement conda ---
        Set-Status "Creation de l'environnement Cogify..." "Installation de Python, GDAL et Streamlit (plusieurs minutes)."
        $logFile = "$env:TEMP\cogify_install_env.log"
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
        $job = Start-Job -ScriptBlock {
            param($condaBat, $here, $logFile)
            cmd.exe /c "`"$condaBat`" env remove -n cogify -y >> `"$logFile`" 2>&1 & `"$condaBat`" env create -f `"$here\app\environment.yml`" --solver=libmamba >> `"$logFile`" 2>&1"
        } -ArgumentList $condaBat, $here, $logFile
        Wait-Job-Responsive $job "Installation de Python, GDAL et Streamlit (plusieurs minutes)" $logFile | Out-Null
        Remove-Job -Job $job -ErrorAction SilentlyContinue

        $condaRoot = Split-Path -Parent (Split-Path -Parent $condaBat)
        $envFailed = -not (Test-Path "$condaRoot\envs\cogify\python.exe")
        if ($envFailed) {
            $lastLines = ""
            if (Test-Path $logFile) { $lastLines = (Get-Content -Path $logFile -Tail 15 -ErrorAction SilentlyContinue) -join "`n" }
            Show-Error "Erreur lors de la creation de l'environnement conda.`n`n$lastLines"
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









