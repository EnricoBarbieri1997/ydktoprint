param(
    [string]$url = "https://images.ygoprodeck.com/images/cards/",
    [string]$path = "\decks\",
    [string]$cardsPath = "\cards\",
    [string]$tmpPath = "\tmp\"
)

$cardsCount = @{}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$scriptDir$path"
function isNumeric
{
    param(
      [string] $InString
    )
    [Int32]$OutNumber = $null

    if ([Int32]::TryParse($InString,[ref]$OutNumber)){
        #Write-Host "Valid Number"
        return $true
    } else {
        #Write-Host "Invalid Number"
        #error code here
        return $false
    }
}
function ParseFileContent
{
    param(
      [string] $fullName
    )
    Get-Content $fullName | 
    ForEach-Object {
        if(isNumeric($_))
        {
            if($cardsCount.Contains($_))
            {
                $cardsCount[$_]++
            }
            else
            {
                $cardsCount[$_] = 1
            }
        }
    }
}
function ParseFolder
{
    param(
      [string] $path
    )
    Get-ChildItem $path -Filter *.ydk | 
    Foreach-Object {
        ParseFileContent $_.FullName
    }
}
function GetCardData
{
    param (
        [string]$passcode
    )
    $request = "$url$passcode"
    $cardData = Invoke-WebRequest $request | ConvertFrom-Json
    return $cardData
}

function downloadCard
{
    param (
        [string]$passcode
    )
    $cardUrl = "$url$passcode.jpg"
    Invoke-WebRequest $cardUrl -OutFile "$PSScriptRoot$tmpPath$passcode.jpg"
}

function copyCard
{
    param (
        [string]$passcode,
        [int]$count
    )
    for ($i = 0; $i -lt $count; $i++) {
        Copy-Item "$PSScriptRoot$tmpPath$passcode.jpg" -Destination "$PSScriptRoot$cardsPath$passcode-$($i+1).jpg"
    }
}

function WriteDeckList
{
    param (
        [hashtable]$cards
    )
    foreach ($c in $cards.GetEnumerator())
    {
        downloadCard $c.Key
        copyCard $c.Key $c.Value
    }    
}
ParseFolder $path
WriteDeckList $cardsCount
"End"