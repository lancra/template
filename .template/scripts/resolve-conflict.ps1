<#
.SYNOPSIS
Resolves the first conflict for a file.

.DESCRIPTION
Scans the matched file for conflict markers, extracting the lines from the ours
and theirs blocks. The specification is applied in the provided order, producing
the collection of selected lines. These lines are then used to replace the full
conflict section.

.PARAMETER Path
The path of the file to resolve conflicts for. Supports glob patterns and
restricts matches to a single file.

.PARAMETER Specification
The specification of indexes or index ranges to select from the target conflict
section. This is made up of one or many segments prefixed with the target symbol
and suffixed with the index or index range. The "<" symbol represents the ours
block and the ">" symbol represents the theirs block. If no specification is
provided, the full conflict section is removed from the file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter()]
    [string] $Specification
)

$items = @(Get-Item -Path $Path)
if ($items.Length -eq 0) {
    throw "Unable to resolve conflicts for unknown path '$Path'."
} elseif ($items.Length -gt 1) {
    $itemsDisplay = "'$(($items |
        Select-Object -ExpandProperty FullName) -join "', '")'"
    throw "Unable to resolve conflicts for multiple items: $itemsDisplay."
}

enum IndexRangeTarget {
    Ours
    Theirs
}

$script:rangeGroupName = 'range'
$script:rangesPattern = "(?<$rangeGroupName>[<>]\d(-\d)?)"

class IndexRange {
    [IndexRangeTarget] $Target
    [int] $Start
    [int] $End

    IndexRange([IndexRangeTarget] $target, [int] $start, [int] $end) {
        $this.Target = $target
        $this.Start = $start
        $this.End = $end
    }

    static [IndexRange] FromText([string] $text) {
        if (-not ($text -match $script:rangesPattern)) {
            throw "The range '$text' is invalid."
        }

        $rangeTargetCharacter = $text[0]
        $targetValue = switch ($rangeTargetCharacter) {
            '<' { [IndexRangeTarget]::Ours }
            '>' { [IndexRangeTarget]::Theirs }
            default { throw "The target on the range '$text' is unrecognized." }
        }

        $values = $text.Substring(1) -split '-'

        $startValue = [int]$values[0]

        if ($values.Length -eq 1) {
            return [IndexRange]::new($targetValue, $startValue, $startValue)
        }

        $endValue = [int]$values[1]

        if ($startValue -gt $endValue) {
            throw "The start value must be less than the end value on the range '$text'."
        }

        return [IndexRange]::new($targetValue, $startValue, $endValue)
    }
}

class ConflictSpecification {
    [IndexRange[]] $Ranges

    ConflictSpecification([IndexRange[]] $ranges) {
        $this.Ranges = $ranges
    }

    static [ConflictSpecification] FromText([string] $text) {
        if (-not $text) {
            return [ConflictSpecification]::new(@())
        }

        $indexRangeGroups = $text |
            Select-String -AllMatches -Pattern $script:rangesPattern |
            Select-Object -ExpandProperty Matches |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $script:rangeGroupName
        $matchedLength = $indexRangeGroups |
            Measure-Object -Property Length -Sum |
            Select-Object -ExpandProperty Sum
        if ($matchedLength -lt $text.Length) {
            [ConflictSpecification]::WriteMatchError($text, $indexRangeGroups)
        }

        $indexRanges = $indexRangeGroups |
            ForEach-Object {
                [IndexRange]::FromText($_.Value)
            }

        return [ConflictSpecification]::new($indexRanges)
    }

    hidden static [void] WriteMatchError([string] $text, [System.Text.RegularExpressions.Group[]] $groups) {
        $matchedIndexes = $groups |
            ForEach-Object {
                $groupIndexes = @()
                for ($i = $_.Index; $i -lt ($_.Index + $_.Length); $i++) {
                    $groupIndexes += $i
                }

                return $groupIndexes
            }

        $underlineStartCode = "`e[4m"
        $underlineEndCode = "`e[24m"
        $errorBuilder = [System.Text.StringBuilder]::new()
        [void]$errorBuilder.Append("The conflict specification text '")

        $wasMatchedIndex = $false
        for ($i = 0; $i -lt $text.Length; $i++) {
            $isMatchedIndex = $i -in $matchedIndexes
            if ($isMatchedIndex -and -not $wasMatchedIndex) {
                [void]$errorBuilder.Append($underlineStartCode)
                $wasMatchedIndex = $true
            }

            if (-not $isMatchedIndex -and $wasMatchedIndex) {
                [void]$errorBuilder.Append($underlineEndCode)
                $wasMatchedIndex = $false
            }

            [void]$errorBuilder.Append($text[$i])
        }

        if ($wasMatchedIndex) {
            [void]$errorBuilder.Append($underlineEndCode)
        }

        [void]$errorBuilder.Append("' was not fully matched.")
        $conflictSpecificationMatchError = $errorBuilder.ToString()
        throw $conflictSpecificationMatchError
    }
}

$file = $items[0]
$conflictSpecification = [ConflictSpecification]::FromText($Specification)

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

$selectedLines = @()
$conflictSpecification.Ranges |
    ForEach-Object {
        $sourceLines = $_.Target -eq [IndexRangeTarget]::Ours ? $oursLines : $theirsLines
        $selectedLines += ,$sourceLines[($_.Start)..($_.End)]
    }

@($beforeLines) + @($selectedLines) + @($afterLines) |
    Set-Content -Path $file
