<# 
.SYNOPSIS 
    Veeam Backups Information 
.DESCRIPTION
	Ce script se connecte au serveur Veeam spécifié et renvoient l'état de tous les jobs de sauvegarde dans un fichier csv.
.PARAMETER de sortie
	csvfile = Spécifier l'emplacement du fichier CSV
.NOTES 
    File Name  : VeeamExportJobStatus.ps1 
    Author     : Jerome Kermorvant - jerome@kermorvant.fr

.EXAMPLE
    BackupCopyJobStatus.ps1
	Execute le script avec les paramètres par défaut
#> 

asnp "VeeamPSSnapIn" -ErrorAction SilentlyContinue

$veeamExePath = "C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Shell.exe"
$veeamDllPath = "C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Common.dll"
$csvfile = "C:\Reports\VeeamExportJobStatus.csv"


# Show debug info
$DebugPreference = "Continue"

function Get-VeeamVersion {
    $veeamExe = Get-Item $veeamExePath
    $VeeamVersion = $veeamExe.VersionInfo.ProductVersion
    Return $VeeamVersion
}


$VeeamVersion = Get-VeeamVersion
If ($VeeamVersion -lt 7) {
    Write-Host "Script requires VBR v7 or greater"
    exit
}

$date1 = Get-Date -Date "01/01/1970"
$date2 = Get-Date
$epoch = [math]::floor((New-TimeSpan -Start $date1 -End $date2).TotalSeconds)
$csv = "#Jobname,DatasizeGB,BackupsizeGB,Clients,LastStatus,LastRun,Epoch" + [Environment]::NewLine

# Get size of jobs
$jobs = Get-VBRJob

foreach ($job in $jobs) {

    $jobhosts = @{}

    $objects = $job.GetObjectsInJob()
    foreach ($object in $objects) {
        $jobhosts[$object.Object.Name] = $object.Object.Name
    }

    $backups = (Get-VBRBackup -Name $job.Name)

        $datasize = 0
        $backupsize = 0
        if (@($currentjobs).Count -gt 1) {
            foreach ($currentjob in $currentjobs.GetEnumerator()) {
                $datasize += $currentjob.DataSize
                $backupsize += $currentjob.BackupSize
            }
        } else {
            $startFolder = "S:\Backup\"+$job.Name
            $colItems = (Get-ChildItem $startFolder | Measure-Object -property length -sum)
            $datasize += $colItems.sum
            $backupsize += $colItems.sum

            $colItems = (Get-ChildItem $startFolder -recurse | Where-Object {$_.PSIsContainer -eq $True} | Sort-Object)
            foreach ($i in $colItems)
            {
                $subFolderItems = (Get-ChildItem $i.FullName | Measure-Object -property length -sum)
                $datasize += $subFolderItems.sum
                $backupsize += $subFolderItems.sum
            }

        }

        $clients = ($jobhosts.Keys -join ',')
        $lastrun = $job.findlastsession().progress.stoptime
        $csv += '"'+$job.Name.Replace('"','') + '","' + [Math]::Round([Decimal]$datasize/1024/1024/1024,2) + '","' + [Math]::Round([Decimal]$backupsize/1024/1024/1024,2) + '","' + $clients.Replace('"','') + '","' + $job.GetLastResult() + '","' + $lastrun + '","' + $epoch + '"' + [Environment]::NewLine

    }


$csv| Out-File $csvfile -Encoding ASCII