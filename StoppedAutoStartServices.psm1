function Get-StoppedAutoStartService
{
    <#
    .SYNOPSIS
    Get the list of stopped services which are of type AutoStart and can also restart them at the same time.

    .DESCRIPTION
    The cmdlet gets the list of stopped services which are of type AutoStart.
    It can also restart them at the same time if requested so.

    .PARAMETER ComputerName
    The computer of which you want to check the service list.

    .PARAMETER AsJob
    Start the check and the service restart as a job.

    .PARAMETER StartService
    Use this parameter if you want to restart all stopped services.

    .PARAMETER IncludeInShortName
    A regular expression pattern to compare to the list of service short names.

    .PARAMETER IncludeInDisplayName
    A regular expression pattern to compare to the list of service display names.

    .PARAMETER ExcludeInShortName
    A regular expression pattern to compare to the list of service short names.

    .PARAMETER ExcludeInDisplayName
    A regular expression pattern to compare to the list of service display names.

    .PARAMETER Credential
    Alternate credential with Administrator access to the target computer.

    .EXAMPLE
    The list of computers is piped to the cmdlet and some services are filtered out by displayname.

    Get-Content -Path C:\Temp\ServerList.txt | Get-StoppedAutoStartService -ExcludeInDisplayName 'Remote registry','windows Update','software protection'

    .EXAMPLE
    All services including the word 'Remote' in the displayname are checked on the Comp1 computer and an alternate credential is used.

    Get-StoppedAutoStartService -ComputerName Comp1 -IncludeInDisplayname 'Remote' -Credential MyDomain\JohnDo

    .EXAMPLE
    All automatic services which are stopped are restarted on the current computer.

    Get-StoppedAutoStartService -StartService

    .EXAMPLE
    The list of computers is piped to the cmdlet and all computers are processed as jobs.

    Get-Content -Path C:\Temp\ServerList.txt | Get-StoppedAutoStartService -AsJob

    .NOTES
    General notes
    #>

    [Alias('gsas')]

    [CmdletBinding()]

    [OutputType('System.Array' , ParameterSetName = '__AllParameterSets')]
    [OutputType('System.Management.Automation.Job', ParameterSetName = 'AsJob')]

    Param(
        [parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = '.',

        [Parameter(ParameterSetName = 'AsJob')]
        [switch]$AsJob,

        [switch]$StartService,

        [ValidateNotNullOrEmpty()]
        [string[]]$IncludeInShortName,

        [ValidateNotNullOrEmpty()]
        [string[]]$IncludeInDisplayName,

        [ValidateNotNullOrEmpty()]
        [string[]]$ExcludeInShortName,

        [ValidateNotNullOrEmpty()]
        [string[]]$ExcludeInDisplayName,

        [pscredential]$Credential
    )

    Begin
    {
        If ($PSBoundParameters['Debug'])
        {$DebugPreference = 'Continue'}

        $BasicFilter = "-Filter `"state='stopped' and startmode='auto'`""
        $PropertyList = '-Property ProcessId,Name,StartMode,State,Status,Exitcode,DisplayName'
        $ScriptBlockString = 'Get-CimInstance -ClassName Win32_Service {0} {1}' -f $BasicFilter, $PropertyList
        $InclusionFilterScriptString = ''
        $ExclusionFilterScriptString = ''

        #region Inclusions
        If ($PSBoundParameters['IncludeInShortName'])
        {
            $ShortNameInclusionString = ''

            #Create a regular expression with a pipe between Inclusions
            foreach ($Inclusion in $IncludeInShortName)
            {
                $ShortNameInclusionString = '{0}|{1}' -f $ShortNameInclusionString, $Inclusion
            }

            #Remove the pipe at the beginning
            $ShortNameInclusionString = $ShortNameInclusionString -replace '^\|', ''

            #Add the regular expression to the InclusionFilterScriptString
            $InclusionFilterScriptString = "(`$_.Name -Match '{0}')" -f $ShortNameInclusionString
        }

        If ($PSBoundParameters['IncludeInDisplayName'])
        {
            $DisplayNameInclusionString = ''

            #Create a regular expression with a pipe between Inclusions
            foreach ($Inclusion in $IncludeInDisplayName)
            {
                $DisplayNameInclusionString = '{0}|{1}' -f $DisplayNameInclusionString, $Inclusion
            }

            #Remove the pipe at the beginning
            $DisplayNameInclusionString = $DisplayNameInclusionString -replace '^\|', ''

            #Add the regular expression to the InclusionFilterScriptString
            If ($InclusionFilterScriptString)
            {$InclusionFilterScriptString = "({0}) -or (`$_.DisplayName -Match '{1}')" -f $InclusionFilterScriptString, $DisplayNameInclusionString}
            Else {$InclusionFilterScriptString = "`$_.DisplayName -Match '{0}'" -f $DisplayNameInclusionString}
        }
        #endregion

        #region Exclusions
        If ($PSBoundParameters['ExcludeInShortName'])
        {
            $ShortNameExclusionString = ''

            #Create a regular expression with a pipe between exclusions
            foreach ($Exclusion in $ExcludeInShortName)
            {
                $ShortNameExclusionString = '{0}|{1}' -f $ShortNameExclusionString, $Exclusion
            }

            #Remove the pipe at the beginning
            $ShortNameExclusionString = $ShortNameExclusionString -replace '^\|', ''

            #Add the regular expression to the ExclusionFilterScriptString
            $ExclusionFilterScriptString = "(`$_.Name -NotMatch '{0}')" -f $ShortNameExclusionString
        }

        If ($PSBoundParameters['ExcludeInDisplayName'])
        {
            $DisplayNameExclusionString = ''

            #Create a regular expression with a pipe between exclusions
            foreach ($Exclusion in $ExcludeInDisplayName)
            {
                $DisplayNameExclusionString = '{0}|{1}' -f $DisplayNameExclusionString, $Exclusion
            }

            #Remove the pipe at the beginning
            $DisplayNameExclusionString = $DisplayNameExclusionString -replace '^\|', ''

            #Add the regular expression to the ExclusionFilterScriptString
            If ($ExclusionFilterScriptString)
            {$ExclusionFilterScriptString = "({0}) -and (`$_.DisplayName -NotMatch '{1}')" -f $ExclusionFilterScriptString, $DisplayNameExclusionString}
            Else {$ExclusionFilterScriptString = "`$_.DisplayName -NotMatch '{0}'" -f $DisplayNameExclusionString}
        }
        #endregion

        #region Combine Inclusion and Exclusion
        $CombinedFilterScriptString = ''

        If ($InclusionFilterScriptString -and $ExclusionFilterScriptString)
        {
            $CombinedFilterScriptString = "($InclusionFilterScriptString) -and ($ExclusionFilterScriptString)"
        }
        elseif ($InclusionFilterScriptString)
        {
            $CombinedFilterScriptString = $InclusionFilterScriptString
        }
        elseif ($ExclusionFilterScriptString)
        {
            $CombinedFilterScriptString = $ExclusionFilterScriptString
        }

        If ($CombinedFilterScriptString)
        {
            $CombinedFilterScriptString = "`{$CombinedFilterScriptString`}"
            $ScriptBlockString = '{0} | Where-Object -FilterScript {1}' -f $ScriptBlockString, $CombinedFilterScriptString
        }
        #endregion

        If ($PSBoundParameters['StartService'])
        {
            $ScriptBlockString = '{0} |Start-Service' -f $ScriptBlockString

            If ($PSBoundParameters['Verbose'])
            {$ScriptBlockString = '{0} -Verbose' -f $ScriptBlockString}
        }

        $Parameters = @{
            ComputerName = ''
            ScriptBlock  = [scriptblock]::Create($ScriptBlockString)
        }

        $Parameters.ScriptBlock | Out-String | Write-Debug

        If ($PSBoundParameters['AsJob'])
        {
            $Parameters.Add('AsJob', $true)
            $Parameters.Add('JobName', 'GetStoppedAutoStartService')
        }

        If ($PSBoundParameters['Credential'])
        {$Parameters.Add('Credential', $Credential)}
    }

    Process
    {
        foreach ($Computer in $ComputerName)
        {
            Write-Verbose -Message "Workging on $Computer..."

            $Parameters.ComputerName = $Computer

            $Parameters | Out-String | Write-Debug

            Invoke-Command @Parameters
        }
    }
}
