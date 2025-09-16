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
The comma-separated line indexes or index ranges to use from the ours conflict
block.

.PARAMETER Theirs
The comma-separated line indexes or index ranges to use from the theirs conflict
block.
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

class IndexRange {
    [int] $Start
    [int] $End

    IndexRange([int] $start, [int] $end) {
        $this.Start = $start
        $this.End = $end
    }

    static [IndexRange] FromText([string] $text) {
        $values = $text -split '-'
        if ($values.Length -gt 2) {
            throw "The range '$text' may contain only a single hyphen."
        }

        $startSegment = $values[0]
        $startValue = $startSegment -as [int]
        if ($null -eq $startValue) {
            throw "The start segment '$startSegment' on the range '$text' must be an integer."
        }

        if ($values.Length -eq 1) {
            return [IndexRange]::new($startValue, $startValue)
        }

        $endSegment = $values[1]
        $endValue = $endSegment -as [int]
        if ($null -eq $endValue) {
            throw "The end segment '$endSegment' on the range '$text' must be an integer."
        }

        if ($startValue -gt $endValue) {
            throw "The start segment must be less than the end segment on the range '$text'."
        }

        return [IndexRange]::new($startValue, $endValue)
    }
}

class ConflictSpecification {
    [IndexRange[]] $Ranges
    [int[]] $Indexes

    ConflictSpecification([IndexRange[]] $ranges) {
        $this.Ranges = $ranges
        $this.Indexes = $ranges |
            ForEach-Object {
                $rangeIndexes = @()
                for ($i = $_.Start; $i -le $_.End; $i++) {
                    $rangeIndexes += $i
                }

                $rangeIndexes
            } |
            Select-Object -Unique |
            Sort-Object
    }

    static [ConflictSpecification] FromCsv([string] $csv) {
        if (-not $csv) {
            return [ConflictSpecification]::new(@())
        }

        if (-not ($csv -match '^(\d+(-\d+)?)(,(\d+(-\d+)?))*$')) {
            throw "The conflict specification '$csv' must be a comma-separated list of index ranges."
        }

        $indexRanges = $csv -split ',' |
            ForEach-Object {
                [IndexRange]::FromText($_)
            }

        return [ConflictSpecification]::new($indexRanges)
    }
}

$file = $items[0]

$oursConflictSpecification = [ConflictSpecification]::FromCsv($Ours)
$theirsConflictSpecification = [ConflictSpecification]::FromCsv($Theirs)

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
        [Parameter(Mandatory)]
        [ConflictSpecification] $Specification,

        [Parameter()]
        [string[]] $Line
    )
    begin {
        $lines = @($Line)
    }
    process {
        if ($Specification.Ranges.Length -eq 0) {
            return @()
        }

        $selectedLines = @()
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($i -in $Specification.Indexes) {
                $selectedLines += ,$lines[$i]
            }
        }

        return $selectedLines
    }
}

$oursLines = Read-ConflictSpecification -Specification $oursConflictSpecification -Line $oursLines
$theirsLines = Read-ConflictSpecification -Specification $theirsConflictSpecification -Line $theirsLines

@($beforeLines) + @($oursLines) + @($theirsLines) + @($afterLines) |
    Set-Content -Path $file
