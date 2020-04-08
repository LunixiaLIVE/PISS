function Run-PISS(){
    <#
        .SYNOPSIS
            This function performs performs a speed test using the 
            speedtest.exe from Ookla in intervals and logs the results to a CSV file.
            IF the speedtest.exe file does not exist, this script will attempt to download
            it automatically, unzip it from the archive file and then run it.
            IF the script fails to download the speedtest.exe file, download it manually
            and place it in the same directory as this script

        .DESCRIPTION
            Powershell Interval SpeedTest Script (PISS).
            The Interval variable is optional, and the default value is 15 minutes

        .PARAMETER Interval
            How often (in minutes) you want the speed test to run

        .PARAMETER Timeout
            How much time (in seconds) you want to wait before terminating the speed test
            The default value is 100 seconds

        .OUTPUTS
            mm.dd.yyy_hhmm.csv log file is writting to the same directory as this script at runtime.
            The latest speed test to run also gets returned to the console

        .NOTES
            Author:         LunixiaLIVE
            Version:        1.0.2
            Creation Date:  24 March 2020
            Purpose:        Perform speed test in intervals w/logging
            Ookla:          https://www.speedtest.net/apps/cli
            Pwsh Core:      https://github.com/PowerShell/PowerShell/releases

        .EXAMPLE
            Run-PISS -Interval 15
            Run-PISS -Timeout 120
            Run-PISS -LogDir /tmp/speedtest
            Run-PISS -Interval 15 -Timeout 120 -LogDir /tmp/speedtest
    #>
    param(
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][Int]$Interval = 15,
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][Int]$Timeout = 100,
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][String]$LogDir = $PSScriptRoot
    );

    Set-Location $PSScriptRoot;
    [String]$ScriptOS = "";
    if(!($PSVersionTable.PSEdition.ToString().ToUpper() -eq "CORE")){
        Write-Error "Must be run with Powershell Core.";
        Write-Warning "Visit https://github.com/PowerShell/PowerShell/releases and install powershell for your Operating System.";
        Write-Warning "Current supported Operating Systems are: Windows 10 & Redhat flavored Linux (Fedora, Redhat, CentOS)";
        return;
    };

    function PrependZero(){
        param($var)
        if($var.ToString().Length -eq 1){ 
            return "0$var";
        }else{
            return $var;
        };
    };

    function ErrorCheck(){
        param($var)
        if($var -eq ""){
            return "ERROR"
        }else{
            return $var;
        };
    };

    #Checking for required speedtest program
    try{
        switch($true){
            $IsWindows{
                if(!(Test-Path -Path .\speedtest.exe)){
                    Write-Warning "The program speedtest.exe will be downloaded from:";
                    Write-Warning "https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-win64.zip";
                    Write-Warning "Do you want to continue?";
                    $DL = Read-Host -Prompt "y/n?";
                    if($DL.ToString().ToLower() -eq "y"){
                        #Downloads Speedtest CLI, unpackages it, and then verifies the files are in the same directory.;
                        Invoke-WebRequest -Uri https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-win64.zip -OutFile .\ookla.zip;
                        Expand-Archive -Path .\ookla.zip -DestinationPath .\;
                        Remove-Item -Path .\ookla.zip -Force;
                    };
                    if(!(Test-Path -Path .\speedtest.exe)){
                        Write-Warning "Missing $PSScriptRoot\Speedtest.exe file! Verify Speedtest.exe exists and/or download it from Ookla."
                        return;
                    };
                };
            }
            $IsMacOS{
                Write-Error "Operating System not supported yet.";
            }
            $IsLinux
            {
                $IsRoot = whoami;
                if(!($IsRoot -eq "root")){
                    Write-Error "Must be running as root (ie sudo, su, etc)";
                    return;
                }else{
                    $OSVersion = Get-Content -Path /etc/os-release
                    $Fedora = $false;
                    foreach($string in $OSVersion){
                        #Checks for all flavors of RPM linux.
                        if($string.ToString().ToUpper().Contains("FEDORA") -or `
                           $string.ToString().ToUpper().Contains("RHEL") -or `
                           $string.ToString().ToUpper().Contains("CENTOS")){
                            $Fedora = $true;
                            break;
                        };
                    };
                    if($Fedora){
                        if(!(Get-Command "speedtest" -ErrorAction SilentlyContinue)){
                            #Installs Speedtest and installs is, then verifies it is installed. (Requires root).;
                            #Verify all URLs/package names to ensure no malicious packages are being installed.;
                            Invoke-WebRequest -Uri https://bintray.com/ookla/rhel/rpm -OutFile ./bintray-ookla-rhel.repo;
                            Move-Item -Path ./bintray-ookla-rhel.repo -Destination /etc/yum.repos.d/;
                            yum install -y speedtest;
                        };
                    }else{
                        Write-Error "Operating System not supported yet.";
                    };
                };
            }
            default{
                Write-Error "Operating System not supported yet.";
            }
        };
    }catch{
        Write-Warning $_;
        return;
    };

    $NextTime = (Get-Date).TimeOfDay;
    $Host.UI.RawUI.WindowTitle = "Running Ookla Speed Test every $Interval Minutes...";
    [String]$LogMessage = ""
    #Date Formatting
    $RunTimeHH = PrependZero -var $NextTime.Hours; 
    $RunTimeMM = PrependZero -var $NextTime.Minutes; 
    $RunTimeFullDate = "$((Get-Date).Month.ToString()).$((Get-Date).Day.ToString()).$((Get-Date).Year.ToString())_$($RunTimeHH.ToString())$($RunTimeMM.ToString())";

    #Log File Name & Location
    $LogFileName = "Ookla_$($RuntimeFullDate.ToString()).csv"
    if(!($LogDir -eq $PSScriptRoot)){
        if(Test-Path -Path $LogDir -ErrorAction SilentlyContinue){
            $LogMessage = "Log File "+$RuntimeFullDate.ToString()+".csv generated here: " + $LogDir.ToString();
        }else{
            try{
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null;
                Write-Host "$LogDir directory created";
            }catch{
                Write-Warning "Failed to create directory $LogDir";
                Write-Error $_;
            }
            if(!(Test-Path -Path $LogDir)){
                Write-Error $_;
                Write-Warning "Defaulting log locaiton to: $PSScriptRoot";
                $LogDir = $PSScriptRoot;
                $LogMessage = "Log File "+$RuntimeFullDate.ToString()+".csv generated here: " + $LogDir.ToString();
            };
        };
    };

    Write-Host $LogMessage;
    Add-Content -Path $LogDir\$LogFileName -Value "Date, Time, Server, State, NodeID, ISP, Latency, LatencyUnit, Jitter, JitterUnit, DownSpeed, DownSpeedUnit, DownSize, DownSizeUnit, UpSpeed, UpSpeedUnit, UpSize, UpSizeUnit, PacketLoss, ResultURL";

    while($true){
        #Resetting all variables
        $LogTimeDate = $LogTime = $Server = $State = $NodeID = $ISP = $Latency = $LatencyUnit = $Jitter = $JitterUnit = $DownSpeed = $DownSpeedUnit = $DownSize = $DownSizeUnit = $UpSpeed = $UpSpeedUnit = $UpSize = $UpSpeedUnit = $PacketLoss = $URL = "";
        $TimeStamped = (Get-Date).TimeOfDay;
        $LogHH = PrependZero -var $TimeStamped.Hours;
        $LogMM = PrependZero -var $TimeStamped.Minutes;
        $LogTimeDate = "$((Get-Date).Month.ToString())/$((Get-Date).Day.ToString())/$((Get-Date).Year.ToString())";
        $LogTime = $LogHH.ToString()+":"+$LogMM.ToString();

        if($NextTime.Hours -eq $TimeStamped.Hours -and $NextTime.Minutes -eq $TimeStamped.Minutes){
            $NextTime = (Get-Date).AddMinutes($Interval).TimeOfDay;
            <#
                Speedtest.exe runs with default operators (ie server based on ping, output, etc).
                Adding additional parameters after speedtest.exe may change the result format that is written to the log file.
            #>
            switch($true){
                $IsWindows{
                    $Job = Start-Job -ScriptBlock { param($Path) Set-Location -Path $Path; $output = .\speedtest.exe --accept-license; Add-Content -Path .\temp.txt -Value $output; } -ArgumentList $PSScriptRoot;
                    break;
                }
                $IsMacOS{
                    #In Development...
                    break;
                }
                $IsLinux{
                    $Job = Start-Job -ScriptBlock { param($Path) Set-Location -Path $Path; $output = speedtest --accept-license; Add-Content -Path .\temp.txt -Value $output; } -ArgumentList $PSScriptRoot;
                    break;
                }
            };

            $JobDone = $false;
            for($i = 1; $i -lt $Timeout; $i++){
                if($Job.State -eq "Completed"){
                    Write-Progress -Activity "Speed Test" -Status "Done" -PercentComplete 100;
                    Start-Sleep -Seconds 1;
                    $JobDone = $true;
                    break;
                }else{
                    $JobDone = $false;
                };
                Write-Progress -Activity "Speed Test" -Status "In Progress" -SecondsRemaining ($Timeout - $i) -PercentComplete $i;
                Start-Sleep -Seconds 1;
            };
            if($JobDone -eq $false){
                Write-Progress -Activity "Speed Test FAILED" -Status "ERROR" -PercentComplete 100;
                Write-Warning "Job Errored, speed test most likely failed due to network complications!";
            }else{
                $Result = Get-Content -Path .\temp.txt;
                foreach($line in $Result){
                    if($line.ToString().ToUpper().Contains("SERVER:")){
                        $String = $line.ToString().ToUpper().Trim();
                        $String = $String.ToString().ToUpper().Replace("SERVER:","").Trim();
                        $Server = $String.ToString().ToUpper().Substring(0, $String.IndexOf(",")).Trim();
                        $String = $String.ToString().ToUpper().Replace($Server, "").Trim();
                        $String = $String.ToString().ToUpper().Replace(",", "").Trim();
                        $State  = $String.ToString().ToUpper().Substring(0, $String.IndexOf("(")).Trim();
                        $String = $String.ToString().ToUpper().Replace($State,"").Trim()
                        $NodeID = $String.ToString().ToUpper().Replace("(","").Replace(")","").Replace("ID = ", "").Trim();
                        $Server = ErrorCheck -var $Server;
                        $State = ErrorCheck -var $State;
                        $NodeID = ErrorCheck -var $NodeID;
                    };
                    if($line.ToString().ToUpper().Contains("ISP:")){
                        $String = $line.ToString().ToUpper().Trim();
                        $ISP = $String.ToString().ToUpper().Replace("ISP: ","").Trim();
                        $ISP = ErrorCheck -var $ISP;
                    };
                    if($line.ToString().ToUpper().Contains("LATENCY:")){
                        $String = $line.ToString().ToUpper().Trim();
                        $String = $String.ToString().ToUpper().Replace("LATENCY:","").Trim();                
                        $Latency = $String.ToString().ToUpper().Substring(0,$String.IndexOf("(")-1).Trim();
                        $String = $String.ToString().ToUpper().Replace($Latency,"").Trim();
                        $Temp = $Latency.ToString().ToUpper().Substring(0, $Latency.IndexOf(" ")).Trim();
                        $LatencyUnit = $Latency.ToString().ToUpper().Replace($Temp,"").Trim();
                        $Latency = $Temp.ToString().ToUpper().Trim();
                        $Jitter = $String.ToString().ToUpper().Replace("(","").Replace(")","").Replace("JITTER","").Trim();
                        $Temp = $Jitter.ToString().ToUpper().Substring(0, $Jitter.IndexOf(" ")).Trim();
                        $JitterUnit = $Jitter.ToString().ToUpper().Replace($Temp,"").Trim();
                        $Jitter = $Temp.ToString().ToUpper().Trim();
                        $Latency = ErrorCheck -var $Latency;
                        $LatencyUnit = ErrorCheck -var $LatencyUnit;
                        $Jitter = ErrorCheck -var $Jitter;
                        $JitterUnit = ErrorCheck -var $JitterUnit;
                    };
                    if($line.ToString().ToUpper().Contains("DOWNLOAD:")){
                        $String        = $line.ToString().ToUpper().Replace("DOWNLOAD:","").Trim();
                        $DownSpeed     = $String.ToString().ToUpper().Substring(0, $String.IndexOf("(")).Trim();
                        $String        = $String.ToString().ToUpper().Replace($DownSpeed,"").Trim();
                        $Temp          = $DownSpeed.ToString().ToUpper().Substring(0, $DownSpeed.IndexOf(" ")).Trim();
                        $DownSpeedUnit = $DownSpeed.ToString().ToUpper().Replace($Temp,"").Trim();
                        $DownSpeed     = $Temp.ToString().ToUpper().Trim();
                        $DownSize      = $String.ToString().ToUpper().Replace("DATA USED:","").Replace("(","").Replace(")","").Trim();
                        $Temp          = $DownSize.ToString().ToUpper().Substring(0, $DownSize.IndexOf(" ")).Trim();
                        $DownSizeUnit  = $DownSize.ToString().ToUpper().Replace($Temp,"").Trim();
                        $DownSize      = $Temp.ToString().ToUpper();
                        $DownSpeed = ErrorCheck -var $DownSpeed;
                        $DownSpeedUnit = ErrorCheck -var $DownSpeedUnit;
                        $DownSize = ErrorCheck -var $DownSize;
                        $DownSizeUnit = ErrorCheck -var $DownSizeUnit;
                    };
                    if($line.ToString().ToUpper().Contains("UPLOAD:")){
                        $String        = $line.ToString().ToUpper().Replace("UPLOAD:","").Trim();
                        $UpSpeed       = $String.ToString().ToUpper().Substring(0, $String.IndexOf("(")).Trim();
                        $String        = $String.ToString().ToUpper().Replace($UpSpeed,"").Trim();$String
                        $Temp          = $UpSpeed.ToString().ToUpper().Substring(0, $UpSpeed.IndexOf(" ")).Trim();
                        $UpSpeedUnit   = $UpSpeed.ToString().ToUpper().Replace($Temp,"").Trim();
                        $UpSpeed       = $Temp.ToString().ToUpper().Trim();
                        $UpSize        = $String.ToUpper().Replace("DATA USED:","").Replace("(","").Replace(")","").Trim();
                        $Temp          = $UpSize.ToString().ToUpper().Substring(0, $UpSize.IndexOf(" ")).Trim();
                        $UpSizeUnit    = $UpSize.ToString().ToUpper().Replace($Temp,"").Trim();
                        $UpSize        = $Temp.ToString().ToUpper();
                        $UpSpeed = ErrorCheck -var $UpSpeed;
                        $UpSpeedUnit = ErrorCheck -var $UpSpeedUnit;
                        $UpSize = ErrorCheck -var $UpSize;
                        $UpSizeUnit = ErrorCheck -var $UpSizeUnit;
                    };
                    if($line.ToString().ToUpper().Contains("PACKET LOSS:")){
                        $String = $line.ToString().ToUpper().Trim();
                        $PacketLoss = $String.ToString().ToUpper().Replace("PACKET LOSS:","").Trim();
                        $PacketLoss = ErrorCheck -var $PacketLoss;
                    };
                    if($line.ToString().ToUpper().Contains("URL:")){
                        $String = $line.ToString().ToUpper().Trim();
                        $URL = $String.ToString().ToUpper().Replace("RESULT URL:","").Trim();
                        $URL = ErrorCheck -var $URL;
                    };
                };

                #Logs Results and posts last set of results to the console.;
                Write-Progress -Activity "Speed Test Completed" -Status $LogMessage -Completed;
                Clear-Host;
                Add-Content -Path $LogDir\$LogFileName -Value "$LogTimeDate, $LogTime, $Server, $State, $NodeID, $ISP, $Latency, $LatencyUnit, $Jitter, $JitterUnit, $DownSpeed, $DownSpeedUnit, $DownSize, $DownSizeUnit, $UpSpeed, $UpSpeedUnit, $UpSize, $UpSizeUnit, $PacketLoss, $URL";
                Write-Host "`r`n`r`n`r`n`r`n";
                $t = Import-Csv -Path $LogDir\$LogFileName;
                $t[$t.Count -1];
                Remove-Item -Path $PSScriptRoot\temp.txt;
            };
        };
        Start-Sleep -Seconds 1;
        Write-Progress -Activity "Waiting for next speed test @$($NextTime.ToString().SubString(0,$NextTime.ToString().IndexOf(".")-3))" -Status "zzZZzzz";
    }; 
};

if(!($PSVersionTable.PSEdition.ToString().ToUpper() -eq "CORE")){
    Write-Error "Must be run with Powershell Core.";
    Write-Warning "Visit https://github.com/PowerShell/PowerShell/releases and install powershell for your Operating System.";
    return;
};

if(!(Get-Command -Name Run-PISS -ErrorAction SilentlyContinue)){
    . .\Run-PISS.ps1;
    Write-Host "Function has been imported";
    Write-Host "Run-PISS";
    Write-Host "    Optional Parameters:";
    Write-Host "    [Int][-Interval]";
    Write-Host "    [Int][-Timeout]";
    Write-Host "    [String][-LogDir]";
};