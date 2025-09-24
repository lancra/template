[CmdletBinding()]
param(
    [Parameter()]
    [string[]] $File
)

$script:staticGroupName = 'static'
$script:aliasGroupName = 'alias'
$script:namespaceGroupName = 'namespace'
$importPattern = "^using ((?<$staticGroupName>static)\ |(?<$aliasGroupName>@?\w+)?\s?=\s?)?(?<$namespaceGroupName>\w+?(\.\w+?)*?);$"

enum NamespaceImportKind {
    Standard = 0
    Alias = 1
    Static = 2
}

enum NamespaceFirstSegmentKind {
    System = 0
    Other = 1
}

class NamespaceImport : System.IComparable {
    [int] $LineNumber
    [NamespaceImportKind] $Kind
    [string[]] $Segments
    [bool] $IsStatic
    [string] $AliasName

    NamespaceImport([int] $lineNumber, [NamespaceImportKind] $kind, [string[]] $segments, [bool] $isStatic, [string] $aliasName) {
        $this.LineNumber = $lineNumber
        $this.Kind = $kind
        $this.Segments = $segments
        $this.IsStatic = $isStatic
        $this.AliasName = $aliasName
    }

    static [NamespaceImport] FromMatch([Microsoft.PowerShell.Commands.MatchInfo] $matchInfo) {
        $match = $matchInfo |
            Select-Object -ExpandProperty Matches -First 1
        $groups = $match |
            Select-Object -ExpandProperty Groups

        $staticGroup = $groups |
            Where-Object -Property Name -EQ $script:staticGroupName
        $aliasGroup = $groups |
            Where-Object -Property Name -EQ $script:aliasGroupName
        $namespaceGroup = $groups |
            Where-Object -Property Name -EQ $script:namespaceGroupName

        $isImportStatic = $staticGroup.Success
        $importAliasName = $aliasGroup.Value
        $importSegments = $namespaceGroup.Value.Split('.')

        $importKind = $isImportStatic `
            ? [NamespaceImportKind]::Static `
            : $importAliasName `
                ? [NamespaceImportKind]::Alias `
                : [NamespaceImportKind]::Standard

        return [NamespaceImport]::new($matchInfo.LineNumber, $importKind, $importSegments, $isImportStatic, $importAliasName)
    }

    [int] CompareTo([object] $obj) {
        if ($null -eq $obj) {
            return -1
        }

        $other = $obj -as [NamespaceImport]
        if ($null -eq $other) {
            throw "Unable to compare '$($obj.GetType())' to NamespaceImport."
        }

        $kindComparison = $this.Kind.CompareTo($other.Kind)
        if ($kindComparison -ne 0) {
            return $kindComparison
        }

        if ($this.Kind -eq [NamespaceImportKind]::Alias) {
            $aliasNameComparison = $this.AliasName.CompareTo($other.AliasName)
            if ($aliasNameComparison -ne 0) {
                return $aliasNameComparison
            }
        }

        $maximumSegmentsCount = [Math]::Max($this.Segments.Count, $other.Segments.Count)
        for ($i = 0; $i -lt $maximumSegmentsCount; $i++) {
            if ($i -gt $this.Segments.Count) {
                return -1
            }

            if ($i -gt $other.Segments.Count) {
                return 1
            }

            $digitPadding = 10
            $thisSegment = [regex]::Replace($this.Segments[$i], '\d+', { $args[0].Value.PadLeft($digitPadding) })
            $otherSegment = [regex]::Replace($other.Segments[$i], '\d+', { $args[0].Value.PadLeft($digitPadding) })

            if ($i -eq 0) {
                $thisSegmentKind = ($thisSegment -as [NamespaceFirstSegmentKind]) ?? [NamespaceFirstSegmentKind]::Other
                $otherSegmentKind = ($otherSegment -as [NamespaceFirstSegmentKind]) ?? [NamespaceFirstSegmentKind]::Other

                $segmentKindComparison = $thisSegmentKind.CompareTo($otherSegmentKind)
                if ($segmentKindComparison -ne 0) {
                    return $segmentKindComparison
                }
            }

            $segmentComparison = $thisSegment.CompareTo($otherSegment)
            if ($segmentComparison -ne 0) {
                return $segmentComparison
            }
        }

        return 0
    }

    [bool] Equals([object] $obj) {
        $other = $obj -as [NamespaceImport]
        if ($null -eq $other) {
            return $false
        }

        return $this.CompareTo($other) -eq 0
    }

    [string] ToString() {
        $builder = [System.Text.StringBuilder]::new()
        [void]$builder.Append('using ')

        if ($this.IsStatic) {
            [void]$builder.Append('static ')
        } elseif ($this.AliasName) {
            [void]$builder.Append("$($this.AliasName) = ")
        }

        [void]$builder.Append(($this.Segments -join '.'))
        [void]$builder.Append(';')

        return $builder.ToString()
    }
}

$csharpExtension = '.cs'

if ($File.Length -eq 0) {
    $File = (@(& git diff --name-only --staged) |
        Where-Object { [System.IO.Path]::GetExtension($_) -eq $csharpExtension }) ?? @()
}

$File |
    ForEach-Object {
        Write-Verbose "Sorting namespace imports in '$_'."
        $fileItem = Get-Item -Path $_ -ErrorAction SilentlyContinue
        if ($null -eq $fileItem) {
            Write-Error "The provided path '$_' does not exist."
        } elseif ($fileItem.PSIsContainer) {
            Write-Error "The provided path '$_' is not a file."
        } elseif ($fileItem.Extension -ne $csharpExtension) {
            Write-Error "The provided path '$_' is not a C# file."
        }

        $imports = Select-String -Path $_ -Pattern $importPattern |
            ForEach-Object {
                [NamespaceImport]::FromMatch($_)
            } |
            Sort-Object
        if ($null -eq $imports) {
            return
        }

        $lineNumberMeasurement = $imports |
            Measure-Object -Property LineNumber -Minimum -Maximum
        $minimumNamespaceIndex = $lineNumberMeasurement.Minimum - 1
        $maximumNamespaceIndex = $lineNumberMeasurement.Maximum - 1

        $lines = Get-Content -Path $_

        $beforeLines = @()
        if ($minimumNamespaceIndex -ne 0) {
            $beforeLines = $lines[0..($minimumNamespaceIndex - 1)]
        }

        $afterLines = @()
        if ($maximumNamespaceIndex -lt ($lines.Length - 1)) {
            $afterLines = $lines[($maximumNamespaceIndex + 1)..($lines.Length - 1)]
        }

        $importLines = $imports |
            Select-Object -Unique |
            ForEach-Object {
                $_.ToString()
            }

        @($beforeLines) + @($importLines) + @($afterLines) |
            Set-Content -Path $_
    }
