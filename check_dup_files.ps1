param(
    [string]$folder='G:\Music 2017 BackUp',
    [string]$csvFile='C:\scripts\file_dups.csv',
    [int16]$batchSz=1000  
)  # Modify this to be the path to the root of your iTunes directory

function Get-FileHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [System.String]
        [Alias('PSPath')]
        $Path
    )

    if ((Test-Path -LiteralPath $Path) -eq $false) {
        Write-Host "*! Test-Path failed for $Path."
        throw New-Object System.IO.FileNotFoundException($Path)
    }

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    } catch {
        Write-Host "*! try of Get-Item failed."
        throw
    }

    if ($item -isnot [System.IO.FileInfo]) {
        throw New-Object System.ArgumentException('Specified path must refer to a File object.','Path')
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
    } catch {
        Write-Host "*! ReadAllBytes failed."
        throw
    }

    $md5Hash = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5Hash.ComputeHash($bytes)

    $sb = New-Object System.Text.StringBuilder

    foreach ($byte in $hashBytes) {
        $sb.Append($byte.ToString("x2")) | Out-Null
    }

    Write-Output $sb.ToString()
}

Write-Output "$(Get-Date -Format u) - Starting processing."
Clear-Content -Path $csvFile -Force

$files = @{}

$numFiles=0
$numDistinctFiles=0

Get-ChildItem -LiteralPath $folder -File -Force -Recurse |  # You may want to filter on specific file types here;  I'm not sure what iTunes uses.
Where-Object { $_.Extension -match 'm4a|m4p|m4v|mp3' } |
Where-Object { $_ -is [System.IO.FileInfo] } |
ForEach-Object {
    try {
        $numFiles++
        if ($numFiles % $batchSz -eq 0) {
            Write-Output "$(Get-Date -Format u) - $numFiles files processed..."
        }
        $hash = $_ | Get-FileHash
    } catch {
        Write-Error -ErrorRecord $_
        return   # Can look confusing, but ForEach-Object "loops" use return, not continue
    }

    if ($files.ContainsKey($hash) -eq $false) {
        $numDistinctFiles++
        $files[$hash] = New-Object 'System.Collections.Generic.List[System.String]'
        if ($numDistinctFiles % $batchSz -eq 0) {
            Write-Output "$(Get-Date -Format u) - $numDistinctFiles distinct files added to hash..."
        }
    } else {
        # In this sample, I'm just identifying duplicates by adding all their names to a list.
        # You can have the script delete duplicates here, if you wish, but keep in mind that
        # just because two files have identical hashes, that's not a guarantee that they have
        # identical contents;  it is possible for two different inputs to produce the same
        # hash code.
    }

    $files[$hash].Add($_.FullName)
}

Write-Output "$(Get-Date -Format u) - Done searching through $numFiles files with $numDistinctFiles distinct files found."

Write-Host "   "
Write-Host "### DONE FINDING ALL POTENTIAL DUPS ###"
Write-Host "### NOW REPORTING ON THEM ###"
Write-Host "   "

# For example purposes, output the list of duplicates (since the script didn't delete them)

foreach ($entry in $files.GetEnumerator()) {
    if ($entry.Value.Count -gt 1) {
        $x=0
        $firstFile=$null
        $secondFile=$null
        $thirdFile=$null
     
        Write-Host "*!*!*!*! Potential duplicates:"
        foreach ($path in $entry.Value) {
            if ($x -eq 0 ) {
                $firstFile=$path
            }
            if ($x -eq 1) {
                $secondFile=$path
            }
            if ($x -eq 2) {
                $thirdFile=$path
            }
		    $x++
            Write-Host "  $path"
        }
        Write-Host ""
        $dupFiles = [pscustomobject]@{ File1 = $firstFile; File2 = $secondFile; File3 = $thirdFile }
        $dupFiles | Export-Csv -Path $csvFile -Append -NoTypeInformation
        $x=0
    }
}
Write-Output "$(Get-Date -Format u) - Processing Complete!"