function Run-PISS()
{
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
            Version:        1.0
            Creation Date:  24 March 2020
            Purpose:        Perform speed test in intervals w/logging
            Ookla:          https://www.speedtest.net/apps/cli
            Pwsh Core:      https://github.com/PowerShell/PowerShell/releases

        .EXAMPLE
            Run-SpeedTest -Interval 15
    #>
    param(
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][Int]$Interval = 15,
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][Int]$Timeout = 100,
        [Parameter(Mandatory = $false,ValueFromPipeline = $true)][String]$LogDir = $PSScriptRoot
    )

    Set-Location $PSScriptRoot;

    [String]$ScriptOS = "";
    if(!($PSVersionTable.PSEdition -eq "Core"))
    {
        Write-Error "Must be run with Powershell Core."
        Write-Warning "Visit https://github.com/PowerShell/PowerShell/releases and install powershell for your Operating System."
        return;
    }

    #Checking for required speedtest program
    try
    {
        switch($true)
        {
            $IsWindows
            {
                if(!(Test-Path -Path .\speedtest.exe))
                {
                    #Downloads Speedtest CLI, unpackages it, and then verifies the files are in the same directory.
                    Invoke-WebRequest -Uri https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-win64.zip -OutFile .\ookla.zip;
                    Expand-Archive -Path .\ookla.zip -DestinationPath .\;
                    Remove-Item -Path .\ookla.zip -Force;
                    if(!(Test-Path -Path .\speedtest.exe))
                    {
                        Write-Warning "Missing $PSScriptRoot\Speedtest.exe file! Verify Speedtest.exe exists and/or download it from Ookla."
                        return;
                    };
                };
            }
            $IsMacOS
            {
                Write-Error "Operating System not supported yet."
            }
            $IsLinux
            {
                $IsRoot = whoami
                if(!($IsRoot -eq "root"))
                {
                    Write-Error "Must be running as root (ie sudo, su, etc)";
                    return;
                }
                else
                {
                    $OSVersion = Get-Content -Path /etc/os-release
                    $Fedora = $false;
                    foreach($string in $OSVersion)
                    {
                        #Checks for all flavors of RPM linux.
                        if($string.ToString().ToUpper().Contains("FEDORA") -or `
                           $string.ToString().ToUpper().Contains("RHEL") -or `
                           $string.ToString().ToUpper().Contains("CENTOS")){
                            $Fedora = $true;
                            break;
                        }
                    }

                    if($Fedora)
                    {
                        if(!(Get-Command "speedtest" -ErrorAction SilentlyContinue))
                        {
                            #Installs Speedtest and installs is, then verifies it is installed. (Requires root).
                            #Verify all URLs/package names to ensure no malicious packages are being installed.
                            Invoke-WebRequest -Uri https://bintray.com/ookla/rhel/rpm -OutFile ./bintray-ookla-rhel.repo;
                            Move-Item -Path ./bintray-ookla-rhel.repo -Destination /etc/yum.repos.d/;
                            yum install -y speedtest;
                        };
                    }
                    else
                    {
                        Write-Error "Operating System not supported yet."
                    };
                };
            }
            default
            {
                Write-Error "Operating System not supported yet."
            }
        };

    }
    catch
    {
        Write-Warning $_;
        return;
    };

    $NextTime = (Get-Date).TimeOfDay;
    $Host.UI.RawUI.WindowTitle = "Running Ookla Speed Test every $Interval Minutes..."
    $RunTimeHH = $NextTime.Hours; 
    if($RunTimeHH.ToString().Length -eq 1)
    { 
        $RunTimeHH = "0$RunTimeHH";
    };
    $RunTimeMM = $NextTime.Minutes; 
    if($RunTimeMM.ToString().Length -eq 1)
    { 
        $RunTimeMM = "0$RunTimeMM" 
    };

    #Date Formatting
    $RunTimeDay = (Get-Date).Day;
    $RunTimeMonth = (Get-Date).Month;
    $RunTimeYear = (Get-Date).Year;
    $RunTimeFullDate = $RunTimeMonth.ToString()+"."+$RunTimeDay.ToString()+"."+$RunTimeYear.ToString()+"_"+$RunTimeHH.ToString()+$RunTimeMM.ToString();

    #Log File Name
    $LogFileName = "Ookla_$($RuntimeFullDate.ToString()).csv"
    if($LogDir -eq $PSScriptRoot)
    {
        #Continue
    }
    else
    {
        if(Test-Path -Path $LogDir -ErrorAction SilentlyContinue)
        {
            $LogMessage = "Log File "+$RuntimeFullDate.ToString()+".csv generated here: " + $LogDir.ToString();
        }
        else
        {
            try
            {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null;
                Write-Host "$LogDir directory created"
            }
            catch
            {
                Write-Warning "Failed to create directory $LogDir"
                Write-Error $_;
            }
            if(!(Test-Path -Path $LogDir))
            {
                Write-Error $_
                Write-Warning "Defaulting log locaiton to: $PSScriptRoot"
                $LogDir = $PSScriptRoot;
                $LogMessage = "Log File "+$RuntimeFullDate.ToString()+".csv generated here: " + $LogDir.ToString();
            };
        };
    };
    Write-Host $LogMessage;

    #CSV Log File Headers 
    Add-Content -Path $LogDir\$LogFileName -Value "Date, Time, Server, State, NodeID, ISP, Latency, LatencyUnit, Jitter, JitterUnit, DownSpeed, DownSpeedUnit, DownSize, DownSizeUnit, UpSpeed, UpSpeedUnit, UpSize, UpSizeUnit, PacketLoss, ResultURL";

    while($true)
    {
        #Resetting all variables
        $LogTimeDate = $LogTime = $Server = $State = $NodeID = $ISP = $Latency = $LatencyUnit = $Jitter = $JitterUnit = $DownSpeed = $DownSpeedUnit = $DownSize = $DownSizeUnit = $UpSpeed = $UpSpeedUnit = $UpSize = $UpSpeedUnit = $PacketLoss = $URL = "";
        $TimeStamped = (Get-Date).TimeOfDay
        $LogHH = $TimeStamped.Hours; 
        if($LogHH.ToString().Length -eq 1)
        { 
            $LogHH = "0$LogHH";
        };
        $LogMM = $TimeStamped.Minutes; 
        if($LogMM.ToString().Length -eq 1)
        { 
            $LogMM = "0$LogMM";
        };
        $LogTimeDay = (Get-Date).Day;
        $LogTimeMonth = (Get-Date).Month;
        $LogTimeYear = (Get-Date).Year;
        $LogTimeDate = $LogTimeMonth.ToString()+"/"+$LogTimeDay.ToString()+"/"+$LogTimeYear.ToString();
        $LogTime = $LogHH.ToString()+":"+$LogMM.ToString();

        if($NextTime.Hours -eq $TimeStamped.Hours -and $NextTime.Minutes -eq $TimeStamped.Minutes)
        {
            $NextTime = (Get-Date).AddMinutes($Interval).TimeOfDay;
            <#
                Speedtest.exe runs with default operators (ie server based on ping, output, etc).
                Adding additional parameters after speedtest.exe may change the result format that is written to the log file.
            #>
            
            switch($true)
            {
                $IsWindows
                {
                    $Job = Start-Job -ScriptBlock { param($Path) Set-Location -Path $Path; $output = .\speedtest.exe --accept-license; Add-Content -Path .\temp.txt -Value $output; } -ArgumentList $PSScriptRoot;
                }
                $IsMacOS
                {

                }
                $IsLinux
                {
                    $Job = Start-Job -ScriptBlock { param($Path) Set-Location -Path $Path; $output = speedtest --accept-license; Add-Content -Path .\temp.txt -Value $output; } -ArgumentList $PSScriptRoot;
                }
            };

            $JobDone = $false;
            for($i = 1; $i -lt $Timeout; $i++)
            {
                if($Job.State -eq "Completed")
                {
                    Write-Progress -Activity "Speed Test" -Status "Done" -PercentComplete 100;
                    Start-Sleep -Seconds 1;
                    $JobDone = $true;
                    break;
                }
                else
                {
                    $JobDone = $false;
                };
                Write-Progress -Activity "Speed Test" -Status "In Progress" -SecondsRemaining ($Timeout - $i) -PercentComplete $i;
                Start-Sleep -Seconds 1;
            };
            if($JobDone -eq $false)
            {
                Write-Progress -Activity "Speed Test FAILED" -Status "ERROR" -PercentComplete 100;
                Write-Warning "Job Errored, speed test most likely failed due to network complications!";
            }
            else
            {
                $Result = Get-Content -Path .\temp.txt;
                foreach($line in $Result)
                {
                    if($line.ToString().Contains("Server:"))
                    {
                        $String = $line.ToString();
                        $String = $String.Replace("Server:","").Trim();
                        $Server = $String.Substring(0, $String.IndexOf(",")).Trim();
                        $String = $String.Replace($Server, "").Trim();
                        $String = $String.Replace(",", "").Trim();
                        $State = $String.Substring(0, $String.IndexOf("(")).Trim();
                        $String = $String.Replace($State,"").Trim()
                        $NodeID = $String.Replace("(","").Replace(")","").Replace("id = ", "").Trim();
                    };
                    if($line.ToString().Contains("ISP:"))
                    {
                        $String = $line.ToString();
                        $ISP = $String.Replace("ISP: ","").Trim();
                    };
                    if($line.ToString().Contains("Latency:"))
                    {
                        $String = $line.ToString();
                        $String = $String.Replace("Latency:","").Trim();                
                        $Latency = $String.Substring(0,$String.IndexOf("(")-1).Trim();
                        $String = $String.Replace($Latency,"").Trim();
                        $Temp = $Latency.Substring(0, $Latency.IndexOf(" ")).Trim();
                        $LatencyUnit = $Latency.Replace($Temp,"").Trim();
                        $Latency = $Temp;
                        $Jitter = $String.Replace("(","").Replace(")","").Replace("jitter","").Trim();
                        $Temp = $Jitter.Substring(0, $Jitter.IndexOf(" ")).Trim();
                        $JitterUnit = $Jitter.Replace($Temp,"").Trim();
                        $Jitter = $Temp;
                        if($Latency -eq ""){ $Jitter -eq "ERROR"; };
                        if($LatencyUnit -eq ""){ $JitterUnit -eq "ERROR"; };
                        if($Jitter -eq ""){ $Jitter -eq "ERROR"; };
                        if($JitterUnit -eq ""){ $JitterUnit -eq "ERROR"; };

                    };
                    if($line.ToString().Contains("Download:"))
                    {
                        $String = $line.ToString();
                        $String = $String.Replace("Download:","").Trim();
                        $DownSpeed = $String.Substring(0, $String.IndexOf("(")).Trim();
                        $String = $String.Replace($DownSpeed,"").Trim();
                        $Temp = $DownSpeed.Substring(0, $DownSpeed.IndexOf(" ")).Trim();
                        $DownSpeedUnit = $DownSpeed.Replace($Temp,"").Trim();
                        $DownSpeed = $Temp;
                        $DownSize = $String.Replace("data used:","").Replace("(","").Replace(")","").Trim();
                        $Temp = $DownSize.Substring(0, $DownSize.IndexOf(" ")).Trim();
                        $DownSizeUnit = $DownSize.Replace($Temp,"").Trim();
                        $DownSize = $Temp;
                        if($DownSpeed -eq ""){ $Jitter -eq "ERROR"; };
                        if($DownSpeedUnit -eq ""){ $JitterUnit -eq "ERROR"; };
                        if($DownSize -eq ""){ $Jitter -eq "ERROR"; };
                        if($DownSizeUnit -eq ""){ $JitterUnit -eq "ERROR"; };
                    };
                    if($line.ToString().Contains("Upload:")){
                        $String = $line.ToString();
                        $String = $String.Replace("Upload:","").Trim();
                        $UpSpeed = $String.Substring(0, $String.IndexOf("(")).Trim();
                        $String = $String.Replace($UpSpeed,"").Trim();
                        $Temp = $UpSpeed.Substring(0, $UpSpeed.IndexOf(" ")).Trim();
                        $UpSpeedUnit = $UpSpeed.Replace($Temp,"").Trim();
                        $UpSpeed = $Temp;
                        $UpSize = $String.Replace("data used:","").Replace("(","").Replace(")","").Trim();
                        $Temp = $UpSize.Substring(0, $UpSize.IndexOf(" ")).Trim();
                        $UpSizeUnit = $UpSize.Replace($Temp,"").Trim();
                        $UpSize = $Temp;
                        if($UpSpeed -eq ""){ $Jitter -eq "ERROR"; };
                        if($UpSpeedUnit -eq ""){ $JitterUnit -eq "ERROR"; };
                        if($UpSize -eq ""){ $Jitter -eq "ERROR"; };
                        if($UpSizeUnit -eq ""){ $JitterUnit -eq "ERROR"; };
                    };
                    if($line.ToString().Contains("Packet Loss:")){
                        $String = $line.ToString();
                        $PacketLoss = $String.Replace("Packet Loss:","").Trim();
                        if($PacketLoss -eq ""){ $PacketLoss -eq "ERROR"; };
                    };
                    if($line.ToString().Contains("URL:")){
                        $String = $line.ToString();
                        $URL = $String.Replace("Result URL:","").Trim();
                        if($URL -eq ""){ $URL -eq "ERROR"; };
                    };
                };

                #Logs Results and posts last set of results to the console.
                Write-Progress -Activity "Speed Test Completed" -Status $LogMessage -Completed;
                Clear-Host;
                Add-Content -Path $LogDir\$LogFileName -Value "$LogTimeDate, $LogTime, $Server, $State, $NodeID, $ISP, $Latency, $LatencyUnit, $Jitter, $JitterUnit, $DownSpeed, $DownSpeedUnit, $DownSize, $DownSizeUnit, $UpSpeed, $UpSpeedUnit, $UpSize, $UpSpeedUnit, $PacketLoss, $URL"
                Write-Host "`r`n`r`n`r`n`r`n";
                $t = Import-Csv -Path $LogDir\$LogFileName;
                $t[$t.Count -1]
                Remove-Item -Path $PSScriptRoot\temp.txt;
            };
        };
        Start-Sleep -Seconds 1;
        Write-Progress -Activity "Waiting for next speed test @$($NextTime.ToString().SubString(0,$NextTime.ToString().IndexOf(".")-3))" -Status "zzZZzzz";
    }; 
};
