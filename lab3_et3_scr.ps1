# RUN THIS SCRIPT ON PC WHERE IS DB

[CmdletBinding()] 

Param ( 

[parameter(Mandatory=$true,HelpMessage="Remote IP. [e.g. - D:]")] 
[string]$remoteIP,
[parameter(Mandatory=$true,HelpMessage="Password for SQL DB")] 
[SecureString]$pass 

)

$Login = "Administrator"
$Creds = Get-Credential -UserName $Login -Message "Enter user password"

#################################################################### GET inforation about PC

try {

    $Result = Invoke-Command -ArgumentList $arrPath -ScriptBlock {

        $OS = Get-WmiObject Win32_OperatingSystem
        $RAM = Get-WmiObject CIM_PhysicalMemory | Measure-Object -Property Capacity -Sum | foreach {[math]::round(($_.sum / 1GB),2)} 
        $CPUInfo = (Get-WmiObject Win32_Processor).NumberOfCores

        $NetRegKey = (Get-ItemProperty ‘HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release

        Switch ($NetRegKey) {
           378389 {$NetFrameworkVersion = "4.5"}
           378675 {$NetFrameworkVersion = "4.5.1"}
           378758 {$NetFrameworkVersion = "4.5.1"}
           379893 {$NetFrameworkVersion = "4.5.2"}
           393295 {$NetFrameworkVersion = "4.6"}
           393297 {$NetFrameworkVersion = "4.6"}
           394254 {$NetFrameworkVersion = "4.6.1"}
           394271 {$NetFrameworkVersion = "4.6.1"}
           394802 {$NetFrameworkVersion = "4.6.2"}
           394806 {$NetFrameworkVersion = "4.6.2"}
           460798 {$NetFrameworkVersion = "4.7"}
           460805 {$NetFrameworkVersion = "4.7"}
           461308 {$NetFrameworkVersion = "4.7.1"}
           461310 {$NetFrameworkVersion = "4.7.1"}
           461814 {$NetFrameworkVersion = "4.7.2"}
           461808 {$NetFrameworkVersion = "4.7.2"}
           461814 {$NetFrameworkVersion = "4.7.2"}
           Default {$NetFrameworkVersion = "Net Framework 4.5 or later is not installed."}
        }

        $winName = ($OS.Name).split("|")

        New-Object -TypeName PSObject -Property @{

            'NF' = $NetFrameworkVersion
            'hostName' = $OS.PSComputerName
            'OSName' = $winName[0] 
            'OSVersion' = $OS.Version
            'RAM' = $RAM 
            'CPUInfo' = $CPUInfo

        }

    } -ComputerName $remoteIP -Credential $Creds

    Write-Host "GET inforation about PC - DONE!" -ForegroundColor White -BackgroundColor Green

}
catch [system.exception] {

    Write-Host "Caught a system exception (GET inforation about PC)" -ForegroundColor White -BackgroundColor Red

}

#################################################################### Debug Variables

#Write-Host "NF:" $Result.NF
#Write-Host "hostName:" $Result.hostName
#Write-Host "OSName:" $Result.OSName
#Write-Host "OSVersion:" $Result.OSVersion
#Write-Host "RAM:" $Result.RAM
#Write-Host "CPUInfo:" $Result.CPUInfo

####################################################################

$hostName = ($Result.hostName).Replace("-", "_")

#################################################################### Export to CSV

$Result | select -Property NF,hostName,OSName,OSVersion,RAM,CPUInfo | Export-Csv -path "C:\SerInv_$($hostName).csv" -NoTypeInformation
$chkFile = Get-Item -Path "C:\SerInv_$($hostName).csv"

if ($chkFile) {

    Write-Host "Export to CSV - DONE!" -ForegroundColor White -BackgroundColor Green

} else {
    
    Write-Host "FILE CSV NOT FOUND!" -ForegroundColor White -BackgroundColor Red
    Exit

}

#################################################################### Querys

$Query_CrTable = "
CREATE TABLE test.dbo.$hostName
(  
    NF varchar(50) NOT NULL,   
    hostName varchar(50) NOT NULL,
	OSName varchar(50) NOT NULL, 	
    OSVersion varchar(50) NOT NULL,
	RAM varchar(50) NOT NULL,
    CPUInfo varchar(50) NOT NULL,  	
);
"

$Query_FillingTable = @"
BULK
INSERT test.dbo.$hostName
FROM 'C:\SerInv_$hostName.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
)

--Check the content of the table.

SELECT REPLACE(NF,'"','') NF,
REPLACE([hostName],'"','') [hostName],
REPLACE([OSVersion],'"','') [OSVersion],
REPLACE([RAM],'"','') [RAM],
REPLACE([CPUInfo],'"','') [CPUInfo]

FROM test.dbo.$hostName

"@

####################################################################

try {

    Invoke-Sqlcmd -ServerInstance localhost -Username 'Sa' -Password $pass -Query $Query_CrTable
    Write-Host "Create Table - DONE!" -ForegroundColor White -BackgroundColor Green

}
catch [system.exception] {

    Write-Host "Caught a system exception (Create Table)" -ForegroundColor White -BackgroundColor Red

}

try {

    Invoke-Sqlcmd -ServerInstance localhost -Username 'Sa' -Password $pass -Query $Query_FillingTable
    Write-Host "Filling Table - DONE!" -ForegroundColor White -BackgroundColor Green

}
catch [system.exception] {

    Write-Host "Caught a system exception (Filling Table)" -ForegroundColor White -BackgroundColor Red

}