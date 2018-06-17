﻿# Need to set some variables first....
[string]$dt1    = (Get-Date -Format 'yyyy/MM/dd HH:mm')
[string]$un     = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.ToLower()
[string]$server = '[server/report name here]'
[string]$report = '[report name here]'




# Vaguely based on 
# https://community.spiceworks.com/scripts/show/2450-change-cell-color-in-html-table-with-powershell-set-cellcolor
Function Set-CellColour
{
    Param ( [Object[]]$InputObject, [string]$Filter, [string]$Colour, [switch]$Row )
    Begin
    {
        $Property = ($Filter.Split(' ')[0])
        If ($Filter.ToUpper().IndexOf($Property.ToUpper()) -ge 0)
        {
            $Filter = $Filter.ToUpper().Replace($Property.ToUpper(), '$value')
            Try { [scriptblock]$Filter = [scriptblock]::Create($Filter) } Catch { Exit }
        } Else { Exit }
    }

    Process
    {
        ForEach ($input In $InputObject)
        {
            [string]$line = $input
            If ($line.IndexOf('<tr><th') -ge 0)
            {
                [int]$index = 0
                [int]$count = 0
                $search = $line | Select-String -Pattern '<th>(.*?)</th>' -AllMatches
                ForEach ($match in $search.Matches)
                {
                    If ($match.Groups[1].Value -eq $Property) { $index = $count }
                    $count++
                }
                If ($index -eq $search.Matches.Count) { $index = -99; Break }
            }

            If ($line -match '<tr><td')
            {
                $line = $line.Replace('<td></td>','<td> </td>')
                $search = $line | Select-String -Pattern '<td(.*?)</td>' -AllMatches
                If (($search -ne $null) -and ($search.Matches.Count -ne 0) -and ($index -ne -99))
                {
                    $value = ($search.Matches[$index].Groups[1].Value).Split('>')[1] -as [double]
                    If ($value -eq $null) { $value = ($search.Matches[$index].Groups[1].Value).Split('>')[1] }
                    If (Invoke-Command $Filter)
                    {
                        If ($Row -eq $true) { $line = $line.Replace('<td>', ('<td style="background:{0};">' -f $Colour)) }
                        Else {
                            [string[]]$arr = $line.Replace('><','>■<').Split('■')
                            If ($arr[$index + 1].StartsWith('<td'))
                            {
                                $arr[$index + 1] = $arr[$index + 1].Replace($search.Matches[$index].Value, ('<td style="background:{0};">{1}</td>' -f $Colour, $value))
                                $line = [string]::Join('', $arr)
                            }
                        }
                    }
                }
            }
            Write-Output $line
        }
    }

    End
    { }
}


# CSS for the output table...
[string]$css = @'
<style>
    html body       { font-family: Verdana, Geneva, sans-serif; font-size: 12px; height: 100%; margin: 0; overflow: auto; }
    #header         { background: #0066a1; color: #ffffff; width: 100% }
    #headerTop      { padding: 10px; }
    .logo1          { float: left;  font-size: 25px; font-weight: bold; padding: 0 7px 0 0; }
    .logo2          { float: left;  font-size: 25px; }
    .logo3          { float: right; font-size: 12px; text-align: right; }
    .headerRow1     { background: #66a3c7; height: 5px; }
    .serverRow      { background: #000000; color: #ffffff; font-size: 32px; padding: 10px; text-align: center; text-transform: uppercase; }
    .sectionRow     { background: #0066a1; color: #ffffff; font-size: 13px; padding: 1px 5px!important; font-weight: bold; height: 15px!important; }
    table           { background: #eaebec; border: #cccccc 1px solid; border-collapse: collapse; margin: 0; width: 100%; }
    table th        { background: #ededed; border-top: 1px solid #fafafa; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 45px; min-width: 55px; padding: 0px 15px; text-transform: capitalize; }
    table tr        { text-align: center; }
    table td        { background: #fafafa; border-top: 1px solid #ffffff; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 55px; min-width: 55px; padding: 0px 10px; }
    table td:first-child   { min-width: 175px; text-align: left; }
    table tr:last-child td { border-bottom: 0; }
    table tr:hover td      { background: #f2f2f2; }
    table tr:hover td.sectionRow { background: #0066a1; }
</style>
'@

# Page header rows...
[string]$body = @"
<div id="header"> 
    <div id="headerTop">
        <div class="logo1">ACME</div>
        <div class="logo2">$report</div>
        <div class="logo3">&nbsp;<br/>Generated by $un on $dt1</div>
        <div style="clear:both;"></div>
    </div>
    <div style="clear:both;"></div>
</div>
<div class="headerRow1"></div>
<div class="serverRow">$server</div>
<div class="headerRow1"></div>
"@


# Get a list of processes, and convert to HTML... 
[string[]]$html = Get-Process | Select Name, CPU, Handles, Path, Company, FileVersion | Sort Name | ConvertTo-Html -Head $css -Body $body

# EXAMPLES
# Colour some  cells depending on the filters, filters can contain any valid forumla...
$html = Set-CellColour -InputObject $html -Filter 'Handles -lt 100 -and Handles -gt 50' -Colour '#ffffc0'
$html = Set-CellColour -InputObject $html -Filter 'Handles -gt  99'                     -Colour '#ffc0c0'
$html = Set-CellColour -InputObject $html -Filter 'Handles -lt  51'                     -Colour '#c0ffc0'
$html = Set-CellColour -InputObject $html -Filter 'Name    -eq "ccmexec"'               -Colour 'Gray' -Row
$html = Set-CellColour -InputObject $html -Filter 'Name    -eq "chrome"'                -Colour '#c0c0ff'

# Output the entire HTML to a text file...
$html += '<table><tr><td class="sectionRow">&nbsp;</td></tr></table>'
$html | Out-File .\Out-FancyHTML_Result.html