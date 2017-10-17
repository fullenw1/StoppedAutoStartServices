# StoppedAutoStartServices
Find stopped automatic starting services

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
