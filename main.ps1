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
$cardCmWidth = 5.9
$cardCmHeight = 8.6
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

function savePage
{
    if($null -eq $page)
    {
        return
    }
    $page.Save("$PSScriptRoot$($cardsPath)page-$pageCount.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $global:page = $null
}

function copyCard
{
    param (
        [string]$passcode,
        [int]$count
    )
    $cardBitmap = [BitmapConstructors]::FromFileWithSize("$PSScriptRoot$tmpPath$passcode.jpg", $cardsPixelWidth, $cardsPixelHeight)

    for ($i = 0; $i -lt $count; $i++) {
        if($cardsOnCurrentPageCount -eq 9)
        {
            $global:cardsOnCurrentPageCount = 0
            $global:pageCount += 1
            savePage
        }
        if($null -eq $page)
        {
            $global:page = [BitmapConstructors]::WithSize($A4Width, $A4Height)
            $global:pageGraphics = [System.Drawing.Graphics]::FromImage($page)
            $page.SetResolution($DPI, $DPI)
        }
        $row = [Math]::Floor($cardsOnCurrentPageCount / 3)
        $col = $cardsOnCurrentPageCount % 3
        $x = [Math]::Floor($horizontalPadding + $col * $cardsPixelWidth)
        $y = [Math]::Floor($verticalPadding + $row * $cardsPixelHeight)

        $pageGraphics.DrawImage($cardBitmap, $x, $y, $cardsPixelWidth, $cardsPixelHeight)
        
        $global:cardsOnCurrentPageCount += 1
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
    savePage
}
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition $BitmapConstructorsDeclaration -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives
ParseFolder $path
WriteDeckList $cardsCount
"End"