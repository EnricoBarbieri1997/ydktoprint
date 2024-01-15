param(
    [string]$url = "https://images.ygoprodeck.com/images/cards/",
    [string]$path = "\decks\",
    [string]$cardsPath = "\cards\",
    [string]$tmpPath = "\tmp\"
)

$cardsCount = @{}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$scriptDir$path"

$DPI = 300
$pixelPerCm = $DPI * (1/2.54)
$cardCmWidth = 5.88 # 5.9
$cardCmHeight = 8.58 # 8.6
$A4CmWidth = 21
$A4CmHeight = 29.7
$cardsPixelWidth = [Math]::Floor($cardCmWidth * $pixelPerCm)
$cardsPixelHeight = [Math]::Floor($cardCmHeight * $pixelPerCm)
$A4Width = [Math]::Floor($A4CmWidth * $pixelPerCm)
$A4Height = [Math]::Floor($A4CmHeight * $pixelPerCm)
$horizontalPadding = [Math]::Floor(($A4CmWidth - $cardCmWidth * 3) / 2 * $pixelPerCm)
$verticalPadding = [Math]::Floor(($A4CmHeight - $cardCmHeight * 3) / 2 * $pixelPerCm)

$page = $null
$pageGraphics = $null
$cardsOnCurrentPageCount = 0
$pageCount = 0

$BitmapConstructorsDeclaration = @"
using System;
using System.Drawing;
public class BitmapConstructors
{
  public static Bitmap FromFileWithSize(string filename, Int32 width, Int32 height)
    {
        return new Bitmap(Image.FromFile(filename), width, height);
    }
  public static Bitmap WithSize(Int32 width, Int32 height)
    {
        return new Bitmap(width, height);
    }
}
"@

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
            if($script:cardsCount.Contains($_))
            {
                $script:cardsCount[$_]++
            }
            else
            {
                $script:cardsCount[$_] = 1
            }
        }
    }
}

function ParseFolder
{
    param(
      [string] $script:path
    )
    Get-ChildItem $script:path -Filter *.ydk | 
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
    if (!(Test-Path "$PSScriptRoot$tmpPath$passcode.jpg"))
    {
        $cardUrl = "$url$passcode.jpg"
        Invoke-WebRequest $cardUrl -OutFile "$PSScriptRoot$tmpPath$passcode.jpg"
    }
}

function initPage
{
    $script:page = [BitmapConstructors]::WithSize($script:A4Width, $script:A4Height)
    $script:pageGraphics = [System.Drawing.Graphics]::FromImage($script:page)
    $script:page.SetResolution($script:DPI, $script:DPI)
}

function savePage
{
    $script:page.Save("$PSScriptRoot$($cardsPath)page-$script:pageCount.png", [System.Drawing.Imaging.ImageFormat]::Png)
    initPage
}

function copyCard
{
    param (
        [string]$passcode,
        [int]$count
    )
    $cardBitmap = [BitmapConstructors]::FromFileWithSize("$PSScriptRoot$tmpPath$passcode.jpg", $script:cardsPixelWidth, $script:cardsPixelHeight)

    for ($i = 0; $i -lt $count; $i++) {
        $row = [Math]::Floor($script:cardsOnCurrentPageCount / 3)
        $col = $script:cardsOnCurrentPageCount % 3
        $x = [Math]::Floor($script:horizontalPadding + $col * $script:cardsPixelWidth)
        $y = [Math]::Floor($script:verticalPadding + $row * $script:cardsPixelHeight)

        $script:pageGraphics.DrawImage($cardBitmap, $x, $y, $script:cardsPixelWidth, $script:cardsPixelHeight)
        
        $script:cardsOnCurrentPageCount += 1

        if(9 -eq $script:cardsOnCurrentPageCount)
        {
            $script:cardsOnCurrentPageCount = 0
            $script:pageCount += 1
            savePage
        }
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
    if(9 -ne $script:cardsOnCurrentPageCount -and 0 -ne $script:cardsOnCurrentPageCount)
    {
        $script:pageCount += 1
        savePage
    }
}
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $BitmapConstructorsDeclaration -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives
Write-Host $PSVersionTable
ParseFolder $script:path
initPage
WriteDeckList $script:cardsCount
"End"