[CmdletBinding()]
[OutputType([PSObject])]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

$todoLines = Get-Content -Path $Path

$indication = '*'
$indicatorGroupName = 'indicator'
$idGroupName = 'id'
$messageGroupName = 'message'
$commitMatches = $todoLines |
    Select-String -Pattern "(?<$indicatorGroupName>[$indication ]{1}) (?<$idGroupName>[0-9a-f]{40}) (?<$messageGroupName>.+)" |
    Select-Object -ExpandProperty Matches

$nextCommitMatch = $commitMatches |
    ForEach-Object {
        $indicatedGroup = $_ |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $indicatorGroupName |
            Where-Object -Property Value -NE $indication
        if ($indicatedGroup) {
            return $_
        }
    } |
    Select-Object -First 1
if (-not $nextCommitMatch) {
    return $null
}

function Get-CommitGroupValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Text.RegularExpressions.Match] $Commit,

        [Parameter(Mandatory)]
        [string] $Group
    )
    process {
        $Commit |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $Group |
            Select-Object -ExpandProperty Value
    }
}

return [PSCustomObject]@{
    Line = $nextCommitMatch.Value
    Id = Get-CommitGroupValue -Commit $nextCommitMatch -Group $idGroupName
    Message = Get-CommitGroupValue -Commit $nextCommitMatch -Group $messageGroupName
}
