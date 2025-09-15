<#
.SYNOPSIS
Resolves the first conflict for a file.

.DESCRIPTION
Scans the matched file for conflict markers, extracting the lines from the ours
and theirs blocks. The indexes provided for each are used to filter the
extracted lines, and the results are used to replace the full conflict section.

.PARAMETER Path
The path of the file to resolve conflicts for. Supports glob patterns and
restricts matches to a single file.

.PARAMETER Ours
The comma-separated line indexes to use from the ours conflict block.

.PARAMETER Theirs
The comma-separated line indexes to use from the theirs conflict block.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter()]
    [string] $Ours,

    [Parameter()]
    [string] $Theirs
)

$items = @(Get-Item -Path $Path)
if ($items.Length -eq 0) {
    throw "Unable to resolve conflicts for unknown path '$Path'."
} elseif ($items.Length -gt 1) {
    $itemsDisplay = "'$(($items |
        Select-Object -ExpandProperty FullName) -join "', '")'"
    throw "Unable to resolve conflicts for multiple items: $itemsDisplay."
}

$file = $items[0]

function Test-ConflictSpecification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [string] $Text
    )
    begin {
        $commaSeparatedNumbersPattern = '^\d+(,\d+)*$'
        $errorFormat = 'The {0} parameter must contain comma-separated numbers, but instead has ''{1}''.'
    }
    process {
        if (-not $Text) {
            return
        }

        if (-not ($Text -match $commaSeparatedNumbersPattern)) {
            throw $errorFormat -f $Name, $Text
        }
    }
}

Test-ConflictSpecification -Name 'Ours' -Text $Ours
Test-ConflictSpecification -Name 'Theirs' -Text $Theirs

enum MarkerScan {
    Ours
    BaseOrSeparator
    Separator
    Theirs
    None
}

$markerCharacterCount = 7

$oursMarker = [string]::new('<', $markerCharacterCount)
$baseMarker = [string]::new('|', $markerCharacterCount)
$separatorMarker = [string]::new('=', $markerCharacterCount)
$theirsMarker = [string]::new('>', $markerCharacterCount)

$beforeLines = @()
$oursLines = @()
$theirsLines = @()
$afterLines = @()
$scanMode = [MarkerScan]::Ours

Get-Content -Path $file |
    ForEach-Object {
        $line = $_
        switch ($scanMode) {
            ([MarkerScan]::Ours.ToString()) {
                if ($line.StartsWith($oursMarker)) {
                    $scanMode = [MarkerScan]::BaseOrSeparator
                    return
                } else {
                    $beforeLines += ,$line
                }
            }
            ([MarkerScan]::BaseOrSeparator.ToString()) {
                if ($line.StartsWith($baseMarker)) {
                    $scanMode = [MarkerScan]::Separator
                    return
                } elseif ($line.StartsWith($separatorMarker)) {
                    $scanMode = [MarkerScan]::Theirs
                    return
                } else {
                    $oursLines += ,$line
                }
            }
            ([MarkerScan]::Separator.ToString()) {
                if ($line.StartsWith($separatorMarker)) {
                    $scanMode = [MarkerScan]::Theirs
                    return
                }
            }
            ([MarkerScan]::Theirs.ToString()) {
                if ($line.StartsWith($theirsMarker)) {
                    $scanMode = [MarkerScan]::None
                    return
                } else {
                    $theirsLines += ,$line
                }
            }
            ([MarkerScan]::None.ToString()) {
                $afterLines += ,$line
            }
        }
    }

function Read-ConflictSpecification {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string[]] $Line,

        [Parameter()]
        [string] $Text
    )
    begin {
        $lines = @($Line)
    }
    process {
        if (-not $Text) {
            return @()
        }

        $indexes = $Text -split ',' |
            ForEach-Object {
                [int]::Parse($_)
            }

        $selectedLines = @()
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($i -in $indexes) {
                $selectedLines += ,$lines[$i]
            }
        }

        return $selectedLines
    }
}

$oursLines = Read-ConflictSpecification -Line $oursLines -Text $Ours
$theirsLines = Read-ConflictSpecification -Line $theirsLines -Text $Theirs

@($beforeLines) + @($oursLines) + @($theirsLines) + @($afterLines) |
    Set-Content -Path $file
