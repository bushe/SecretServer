function Convert-SecStrToStr
{
    [cmdletbinding()]
    param($secstr)
    Try
    {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secstr)
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    Catch
    {
        Write-Error "Failed to convert secure string to string: $_"
    }
}


function Get-TemplateTable {

    $TemplateTable = @{}
    
    Get-SSTemplate | ForEach-Object {
        $TemplateTable.Add($_.ID, $_.Name)
    }

    $TemplateTable
}


function Invoke-Sqlcmd2 
{
    <# 
    .SYNOPSIS 
        Runs a T-SQL script. 

    .DESCRIPTION 
        Runs a T-SQL script. Invoke-Sqlcmd2 only returns message output, such as the output of PRINT statements when -verbose parameter is specified.
        Paramaterized queries are supported. 

        Help details below borrowed from Invoke-Sqlcmd

    .PARAMETER ServerInstance
        One or more ServerInstances to query. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

    .PARAMETER Database
        A character string specifying the name of a database. Invoke-Sqlcmd2 connects to this database in the instance that is specified in -ServerInstance.

        If a SQLConnection is provided, we explicitly switch to this database

    .PARAMETER Query
        Specifies one or more queries to be run. The queries can be Transact-SQL (? or XQuery statements, or sqlcmd commands. Multiple queries separated by a semicolon can be specified. Do not specify the sqlcmd GO separator. Escape any double quotation marks included in the string ?). Consider using bracketed identifiers such as [MyTable] instead of quoted identifiers such as "MyTable".

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-Sqlcmd2. The file can contain Transact-SQL statements, (? XQuery statements, and sqlcmd commands and scripting variables ?). Specify the full path to the file.

    .PARAMETER Credential
        Specifies A PSCredential for SQL Server Authentication connection to an instance of the Database Engine.
        
        If -Credential is not specified, Invoke-Sqlcmd attempts a Windows Authentication connection using the Windows account running the PowerShell session.
        
        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when Invoke-Sqlcmd2 times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer between 0 and 65534. If 0 is specified, connection attempts do not time out.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value 

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER SqlParameters
        Hashtable of parameters for parameterized SQL queries.  http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

        Example:
            -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
            -SqlParameters @{"ServerName = "c-is-hyperv-1"}

    .PARAMETER AppendServerInstance
        If specified, append the server instance to PSObject and DataRow output

    .PARAMETER SQLConnection
        If specified, use an existing SQLConnection.
            We attempt to open this connection if it is closed

    .INPUTS 
        None 
            You cannot pipe objects to Invoke-Sqlcmd2 

    .OUTPUTS
       As PSObject:     System.Management.Automation.PSCustomObject
       As DataRow:      System.Data.DataRow
       As DataTable:    System.Data.DataTable
       As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
       As SingleValue:  Dependent on data type in first column.

    .EXAMPLE 
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1" 
    
        This example connects to a named instance of the Database Engine on a computer and runs a basic T-SQL query. 
        StartTime 
        ----------- 
        2010-08-12 21:21:03.593 

    .EXAMPLE 
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -InputFile "C:\MyFolder\tsqlscript.sql" | Out-File -filePath "C:\MyFolder\tsqlscript.rpt" 
    
        This example reads a file containing T-SQL statements, runs the file, and writes the output to another file. 

    .EXAMPLE 
        Invoke-Sqlcmd2  -ServerInstance "MyComputer\MyInstance" -Query "PRINT 'hello world'" -Verbose 

        This example uses the PowerShell -Verbose parameter to return the message output of the PRINT command. 
        VERBOSE: hello world 

    .EXAMPLE
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU -gt 8}
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU}

        This example uses the PSObject output type to allow more flexibility when working with results.
        
        If we used DataRow rather than PSObject, we would see the following behavior:
            Each row where VCNumCPU does not exist would produce an error in the first example
            Results would include rows where VCNumCPU has DBNull value in the second example

    .EXAMPLE
        'Instance1', 'Server1/Instance1', 'Server2' | Invoke-Sqlcmd2 -query "Sp_databases" -as psobject -AppendServerInstance

        This example lists databases for each instance.  It includes a column for the ServerInstance in question.
            DATABASE_NAME          DATABASE_SIZE REMARKS        ServerInstance                                                     
            -------------          ------------- -------        --------------                                                     
            REDACTED                       88320                Instance1                                                      
            master                         17920                Instance1                                                      
            ...                                                                                              
            msdb                          618112                Server1/Instance1                                                                                                              
            tempdb                        563200                Server1/Instance1
            ...                                                     
            OperationsManager           20480000                Server2                                                            

    .EXAMPLE
        #Construct a query using SQL parameters
            $Query = "SELECT ServerName, VCServerClass, VCServerContact FROM tblServerInfo WHERE VCServerContact LIKE @VCServerContact AND VCServerClass LIKE @VCServerClass"

        #Run the query, specifying values for SQL parameters
            Invoke-Sqlcmd2 -ServerInstance SomeServer\NamedInstance -Database ServerDB -query $query -SqlParameters @{ VCServerContact="%cookiemonster%"; VCServerClass="Prod" }
            
            ServerName    VCServerClass VCServerContact        
            ----------    ------------- ---------------        
            SomeServer1   Prod          cookiemonster, blah                 
            SomeServer2   Prod          cookiemonster                 
            SomeServer3   Prod          blah, cookiemonster                 

    .EXAMPLE
        Invoke-Sqlcmd2 -SQLConnection $Conn -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1" 
    
        This example uses an existing SQLConnection and runs a basic T-SQL query against it

        StartTime 
        ----------- 
        2010-08-12 21:21:03.593 


    .NOTES 
        Version History 
        poshcode.org - http://poshcode.org/4967
        v1.0         - Chad Miller - Initial release 
        v1.1         - Chad Miller - Fixed Issue with connection closing 
        v1.2         - Chad Miller - Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation 
        v1.3         - Chad Miller - Added As parameter to control DataSet, DataTable or array of DataRow Output type 
        v1.4         - Justin Dearing <zippy1981 _at_ gmail.com> - Added the ability to pass parameters to the query.
        v1.4.1       - Paul Bryson <atamido _at_ gmail.com> - Added fix to check for null values in parameterized queries and replace with [DBNull]
        v1.5         - Joel Bennett - add SingleValue output option
        v1.5.1       - RamblingCookieMonster - Added ParameterSets, set Query and InputFile to mandatory
        v1.5.2       - RamblingCookieMonster - Added DBNullToNull switch and code from Dave Wyatt. Added parameters to comment based help (need someone with SQL expertise to verify these)
                 
        github.com   - https://github.com/RamblingCookieMonster/PowerShell
        v1.5.3       - RamblingCookieMonster - Replaced DBNullToNull param with PSObject Output option. Added credential support. Added pipeline support for ServerInstance.  Added to GitHub
                       RamblingCookieMonster - Added AppendServerInstance switch.
                       RamblingCookieMonster - Updated OutputType attribute, comment based help, parameter attributes (thanks supersobbie), removed username/password params
                       RamblingCookieMonster - Added help for sqlparameter parameter.
                       RamblingCookieMonster - Added ErrorAction SilentlyContinue handling to Fill method
        v1.6.0         RamblingCookieMonster - Added SQLConnection parameter and handling.  Is there a more efficient way to handle the parameter sets?

    .LINK
        https://github.com/RamblingCookieMonster/PowerShell

    .FUNCTIONALITY
        SQL
    #>

    [CmdletBinding( DefaultParameterSetName='Ins-Que' )]
    [OutputType([System.Management.Automation.PSCustomObject],[System.Data.DataRow],[System.Data.DataTable],[System.Data.DataTableCollection],[System.Data.DataSet])]
    param(
        [Parameter( ParameterSetName='Ins-Que',
                    Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQL Server Instance required...' )]
        [Parameter( ParameterSetName='Ins-Fil',
                    Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQL Server Instance required...' )]
        [Alias( 'Instance', 'Instances', 'ComputerName', 'Server', 'Servers' )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ServerInstance,

        [Parameter( Position=1,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false)]
        [string]
        $Database,
    
        [Parameter( ParameterSetName='Ins-Que',
                    Position=2,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Con-Que',
                    Position=2,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [string]
        $Query,
        
        [Parameter( ParameterSetName='Ins-Fil',
                    Position=2,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Con-Fil',
                    Position=2,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $InputFile,
        
        [Parameter( ParameterSetName='Ins-Que',
                    Position=3,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false)]
        [Parameter( ParameterSetName='Ins-Fil',
                    Position=3,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter( Position=4,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $QueryTimeout=600,
    
        [Parameter( ParameterSetName='Ins-Fil',
                    Position=5,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName='Ins-Que',
                    Position=5,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $ConnectionTimeout=15,
    
        [Parameter( Position=6,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateSet("DataSet", "DataTable", "DataRow","PSObject","SingleValue")]
        [string]
        $As="DataRow",
    
        [Parameter( Position=7,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Collections.IDictionary]
        $SqlParameters,

        [Parameter( Position=8,
                    Mandatory=$false )]
        [switch]
        $AppendServerInstance,

        [Parameter( ParameterSetName = 'Con-Que',
                    Position=9,
                    Mandatory=$false,
                    ValueFromPipeline=$false,
                    ValueFromPipelineByPropertyName=$false,
                    ValueFromRemainingArguments=$false )]
        [Parameter( ParameterSetName = 'Con-Fil',
                    Position=9,
                    Mandatory=$false,
                    ValueFromPipeline=$false,
                    ValueFromPipelineByPropertyName=$false,
                    ValueFromRemainingArguments=$false )]
        [Alias( 'Connection', 'Conn' )]
        [ValidateNotNullOrEmpty()]
        [System.Data.SqlClient.SQLConnection]
        $SQLConnection
    ) 

    Begin
    {
        if ($InputFile) 
        { 
            $filePath = $(Resolve-Path $InputFile).path 
            $Query =  [System.IO.File]::ReadAllText("$filePath") 
        }

        Write-Verbose "Running Invoke-Sqlcmd2 with ParameterSet '$($PSCmdlet.ParameterSetName)'.  Performing query '$Query'"

        If($As -eq "PSObject")
        {
            #This code scrubs DBNulls.  Props to Dave Wyatt
            $cSharp = @'
                using System;
                using System.Data;
                using System.Management.Automation;

                public class DBNullScrubber
                {
                    public static PSObject DataRowToPSObject(DataRow row)
                    {
                        PSObject psObject = new PSObject();

                        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
                        {
                            foreach (DataColumn column in row.Table.Columns)
                            {
                                Object value = null;
                                if (!row.IsNull(column))
                                {
                                    value = row[column];
                                }

                                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                            }
                        }

                        return psObject;
                    }
                }
'@

            Try
            {
                Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml' -ErrorAction stop
            }
            Catch
            {
                If(-not $_.ToString() -like "*The type name 'DBNullScrubber' already exists*")
                {
                    Write-Warning "Could not load DBNullScrubber.  Defaulting to DataRow output: $_"
                    $As = "Datarow"
                }
            }
        }

        #Handle existing connections
        if($PSBoundParameters.Keys -contains "SQLConnection")
        {

            if($SQLConnection.State -notlike "Open")
            {
                Try
                {
                    $SQLConnection.Open()
                }
                Catch
                {
                    Throw $_
                }
            }

            if($Database -and $SQLConnection.Database -notlike $Database)
            {
                Try
                {
                    $SQLConnection.ChangeDatabase($Database)
                }
                Catch
                {
                    Throw "Could not change Connection database '$($SQLConnection.Database)' to $Database`: $_"
                }
            }

            if($SQLConnection.state -like "Open")
            {
                $ServerInstance = @($SQLConnection.DataSource)
            }
            else
            {
                Throw "SQLConnection is not open"
            }
        }

    }
    Process
    {
        foreach($SQLInstance in $ServerInstance)
        {
            Write-Verbose "Querying ServerInstance '$SQLInstance'"

            if($PSBoundParameters.Keys -contains "SQLConnection")
            {
                $Conn = $SQLConnection
            }
            else
            {
                if ($Credential) 
                {
                    $ConnectionString = "Server={0};Database={1};User ID={2};Password=`"{3}`";Trusted_Connection=False;Connect Timeout={4}" -f $SQLInstance,$Database,$Credential.UserName,$Credential.GetNetworkCredential().Password,$ConnectionTimeout
                }
                else 
                {
                    $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $SQLInstance,$Database,$ConnectionTimeout
                } 
            
                $conn = New-Object System.Data.SqlClient.SQLConnection
                $conn.ConnectionString = $ConnectionString 
                Write-Debug "ConnectionString $ConnectionString"


                Try
                {
                    $conn.Open() 
                }
                Catch
                {
                    Write-Error $_
                    continue
                }
            }

            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
            if ($PSBoundParameters.Verbose) 
            { 
                $conn.FireInfoMessageEventOnUserErrors=$true 
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" } 
                $conn.add_InfoMessage($handler) 
            }
    

            $cmd = New-Object system.Data.SqlClient.SqlCommand($Query,$conn) 
            $cmd.CommandTimeout=$QueryTimeout

            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        { $cmd.Parameters.AddWithValue($_.Key, $_.Value) }
                        Else
                        { $cmd.Parameters.AddWithValue($_.Key, [DBNull]::Value) }
                    } > $null
            }
    
            $ds = New-Object system.Data.DataSet 
            $da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
    
            Try
            {
                [void]$da.fill($ds)
                $conn.Close()
            }
            Catch
            { 
                $Err = $_
                $conn.Close()

                switch ($ErrorActionPreference.tostring())
                {
                    {'SilentlyContinue','Ignore' -contains $_} {}
                    'Stop' {     Throw $Err }
                    'Continue' { Write-Error $Err}
                    Default {    Write-Error $Err}
                }              
            }

            if($AppendServerInstance)
            {
                #Basics from Chad Miller
                $Column =  New-Object Data.DataColumn
                $Column.ColumnName = "ServerInstance"
                $ds.Tables[0].Columns.Add($Column)
                Foreach($row in $ds.Tables[0])
                {
                    $row.ServerInstance = $SQLInstance
                }
            }

            switch ($As) 
            { 
                'DataSet' 
                {
                    $ds
                } 
                'DataTable'
                {
                    $ds.Tables
                } 
                'DataRow'
                {
                    $ds.Tables[0]
                }
                'PSObject'
                {
                    #Scrub DBNulls - Provides convenient results you can use comparisons with
                    #Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
                    foreach ($row in $ds.Tables[0].Rows)
                    {
                        [DBNullScrubber]::DataRowToPSObject($row)
                    }
                }
                'SingleValue'
                {
                    $ds.Tables[0] | Select-Object -ExpandProperty $ds.Tables[0].Columns[0].ColumnName
                }
            }
        }
    }
} #Invoke-Sqlcmd2


function Verify-SecretConnection {
    [cmdletbinding()]
    param(
        $Proxy,
        $Token
    )
    
    if($Token -notlike "")
    {
        $Result = $Proxy.whoami($Token)
        if(@($Result.Errors).count -gt 0)
        {
            throw "Not connected: $($Result.errors | out-string)`nuse New-SSToken to generate a token"
        }
        else
        {
            Write-Verbose "Proxy with token"
            $Proxy
        }
    }
    else
    {

        if(-not $Proxy.whoami)
        {
            Write-Warning "Your proxy does not appear connected.  Creating new connection to $($Proxy.url)"
            try
            {
                New-WebServiceProxy -uri $Proxy.url -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
        else
        {
            Write-Verbose "Proxy without token"
            $Proxy
        }
    }
}


function Connect-SecretServer {
    <#
    .SYNOPSIS
        Create a connection to secret server

    .DESCRIPTION
        Create a connection to secret server

        Default action updates $SecretServerConfig.Proxy which most functions use as a default

        If you specify a winauthwebservices endpoint, we remove any existing Token from your module configuration.

    .PARAMETER Uri
        Uri to connect to. Defaults to $SecretServerConfig.Uri

    .PARAMETER Credentials
        User credentials to authenticate to SecretServer. Defaults to Get-Credential

    .PARAMETER Radius
        Switch to connect with RADIUS credentials. Prompts for creditials 

    .PARAMETER Organization
        String for Organization, Default to ""

    .PARAMETER Domain
        String for Domain

    .EXAMPLE
        Connect-SecretServerRADIUS
        
        # Prompts for Domain credentials
        # Prompts for RADIUS token/password
        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the $SecretServerConfig.Token to generated value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>    
    param(
        $Uri="https://pwmanager.corp.athenahealth.com/SecretServer/webservices/SSWebservice.asmx",
        $Credentials=(Get-Credential -Message "Enter Domain Credentials"),
        [switch]$Radius,
        [string]$Organization="",
        [string]$Domain="corp"
    )


    Try
    {
        #Import the config.  Clear out any legacy references to Proxy in the config file.
        $SecretServerConfig = $null
        $SecretServerConfig = Get-SecretServerConfig -Source "ConfigFile" -ErrorAction Stop | Select -Property * -ExcludeProperty Proxy | Select -Property *, Proxy

        $SSUri = $SecretServerConfig.Uri

        #Connect to SSUri, if it exists
        If($SSUri)
        {
            try
            {
                $SecretServerConfig.Proxy = New-SSConnection -Uri $SSUri -ErrorAction stop -Passthru
            }
            catch
            {
                Write-Warning "Error creating proxy for '$SSUri': $_"
            }
        }
    }
    Catch
    {   
        Write-Warning "Error reading $PSScriptRoot\SecretServer_$($env:USERNAME).xml: $_"
    }
    
    $Proxy =  New-WebServiceProxy -Uri $Uri #(Get-SecretServerConfig | Select -ExpandProperty Uri)
    
    if($Radius){
        $RadiusCreds = (Get-Credential -UserName "Radius Password" -Message "Enter Radius Password")
        $Login = ($Proxy.AuthenticateRADIUS($Credentials.UserName,$Credentials.GetNetworkCredential().Password,$Organization,$Domain,"$([string]$RadiusCreds.GetNetworkCredential().Password)"))
        if($Login.Errors){
            Write-Error "Login Failure: $($Login.Errors)"
            break
        }
        else{
            Write-Verbose "Login Successful" -Verbose
        }
        $Token = $Login.Token
        $Credentials = $null
        Set-SecretServerConfig -Token $Token -Uri $Uri
    }
    else{
        $Login = $Proxy.Authenticate($Credentials.UserName, $Credentials.GetNetworkCredential().Password, $Organization, $Domain)
        if($Login.Errors){
            Write-Error "Login Failure: $($Login.Errors)"
            break
        }
        else{
            Write-Verbose "Login Successful" -Verbose
        }
        $Token = $Login.Token
        $Credentials = $null
        Set-SecretServerConfig -Token $Token -Uri $Uri        
    }
}


function Copy-SSPassword {
    <#
    .SYNOPSIS
        Copy password to clipboard from secret server.

    .DESCRIPTION
        Copy password to clipboard from secret server.
        
    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [string]$SearchTerm = $null,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=1)]
        [int]$SecretId = $null
    )
    function Clippy{
        param(
            [Parameter(ValueFromPipeline=$true)]
            [string]$Clip
        )
        Process{
            [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
            [Windows.Forms.Clipboard]::SetDataObject($Clip, $true)
        }
    }

    if($SearchTerm){
        $Secret = Get-Secret -SearchTerm $SearchTerm | Out-GridView -OutputMode Single
        (Get-Secret -SecretId $Secret.SecretId -As Credential).Credential.GetnetworkCredential().Password | Clippy
        Write-Verbose "Password now on clipboard for:" -Verbose
        $Secret
    }
    elseif($SecretId){
        $Secret = Get-Secret -SecretId $SecretId -As Credential
        $Secret.Credential.GetnetworkCredential().Password | Clippy
        Write-Verbose "Password now on clipboard for:" -Verbose
        $Secret
    }
}


function Get-Secret
{
    <#
    .SYNOPSIS
        Get details on secrets from secret server

    .DESCRIPTION
        Get details on secrets from secret server.

        Depending on your configuration, the search will generally include other fields (e.g. Notes).
        For this reason, we do not strip out results based on the search term, we leave this to the end user.

    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER As
        Summary (Default)  Do not return secret details, only return the secret summary.  No audit event triggered
        Credential         Build credential from stored domain (optional), username, password
        PlainText          Return password in ***plain text***
        Raw                Return raw 'secret' object, with settings and permiss
        
    .PARAMETER LoadSettingsAndPermissions
        Load permissions and settings for each secret.  Only applicable for Raw output.
    
    .PARAMETER IncludeDeleted
        Include deleted secrets

    .PARAMETER IncludeRestricted
        Include restricted secrets

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .PARAMETER Token
        Token for your query.  If you do not use Windows authentication, you must request a token.

        See Get-Help Get-SSToken

    .EXAMPLE
        Get-Secret

        #View a summary of all secrets your session account has access to

    .EXAMPLE
        $Credential = ( Get-Secret -SearchTerm "SVC-RemedyProd" -As Credential ).Credential

        # Get secret data for SVC-RemedyProd as a credential object, store it for later use

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [string]$SearchTerm = $null,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=1)]
        [int]$SecretId = $null,

        [validateset("Credential", "PlainText", "Raw", "Summary")]
        [string]$As = "Summary",

        [switch]$LoadSettingsAndPermissions,

        [switch]$IncludeDeleted,

        [switch]$IncludeRestricted,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token

    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        $WebServiceProxy = Verify-SecretConnection -Proxy $WebServiceProxy -Token $Token


        #If the ID was specified, we need a way to go from secret template ID to secret template name...
        if($SecretId -and $As -ne "Raw")
        {
            $TemplateTable = Get-TemplateTable
        }
    }
    Process
    {

        if(-not $SecretId)
        {
            #Find all passwords we have visibility to
                if($Token)
                {
                    $AllSecrets = @( $WebServiceProxy.SearchSecrets($Token,$SearchTerm,$IncludeDeleted,$IncludeRestricted).SecretSummaries )
                }
                else
                {
                    $AllSecrets = @( $WebServiceProxy.SearchSecrets($SearchTerm,$IncludeDeleted,$IncludeRestricted).SecretSummaries )
                }
        }
        else
        {
            #If IDs were specified, create objects with a SecretId we will pull
                $AllSecrets = $SecretId | ForEach-Object {[pscustomobject]@{SecretId = $_}}
        }

        #Return summaries, if we didn't request more...
        if($As -like "Summary")
        {
            if($SecretId)
            {
                Write-Warning "To see more than the SecretId, use -As Raw, Credential, or Plaintext when getting a secret based on SecretId"
            }
            $AllSecrets
        }
        else
        {
            #Extract the secrets
                foreach($Secret in $AllSecrets)
                {

                    Try
                    {
                        if($Token)
                        {
                            $SecretOutput = $WebServiceProxy.GetSecret($Token,$Secret.SecretId,$LoadSettingsAndPermissions, $null)
                        }
                        else
                        {
                            $SecretOutput = $WebServiceProxy.GetSecret($Secret.SecretId,$LoadSettingsAndPermissions, $null)
                        }

                        if($SecretOutput.Errors -and $SecretOutput.Errors.Count -gt 0)
                        {
                            Write-Error "Secret server returned error $($SecretOutput.Errors | Out-String)"
                            continue
                        }
                        $SecretDetail = $SecretOutput.Secret
                    }
                    Catch
                    {
                        Write-Error "Error retrieving secret $($Secret | Out-String)"
                        continue
                    }

                    if($As -like "Raw")
                    {
                        $SecretDetail
                    }
                    else
                    {
                        #Start building up output
                        $Hash = [ordered]@{
                            SecretId = $Secret.SecretId
                            SecretType = $Secret.SecretTypeName
                            SecretName = $Secret.SecretName
                            SecretErrors = $SecretOutput.SecretErrors
                        }

                        #If we obtained by Id, we don't have the same fields above... get them from SecretDetail
                        if($SecretId)
                        {
                            $SecretTypeId = $SecretDetail.SecretTypeId
                            $Hash.SecretId = $SecretDetail.Id
                            $Hash.SecretType = $TemplateTable.$SecretTypeId
                            $Hash.SecretName = $SecretDetail.Name
                        }

                        #Items contains a collection of properties about the secret that can change based on the type of secret
                            foreach($Item in $SecretDetail.Items)
                            {
                                #If they want the credential, we convert to a secure string
                                if($Item.FieldName -like "Password" -and $As -notlike "PlainText")
                                {
                                    if($Item.Value.Length -and $Item.Value.Length -notlike 0)
                                    {
                                        $password = $Item.Value | ConvertTo-SecureString -asPlainText -Force
                                    }
                                    else
                                    {
                                        $password = "Could not access password"
                                    }
                                    $Hash.Add($Item.FieldName, $password)
                                }
                                else
                                {
                                    $Hash.Add($Item.FieldName, $Item.Value)
                                }
                            }

                        #If they want a credential, compose the username, create the credential
                        if($As -like "Credential" -and $Hash.Contains("Password") -and $Hash.Contains("Username"))
                        {
                            if($Hash.Domain)
                            {
                                $User = $Hash.Domain, $Hash.Username -join "\"
                            }
                            elseif($Hash.Machine)
                            {
                                $User = $Hash.Machine, $Hash.Username -join "\"
                            }
                            else
                            {
                                if($Hash.Username -notlike "")
                                {
                                    $User = $Hash.Username
                                }
                                else
                                {
                                    $User = "NONE"
                                }
                            }

                            if($Password -notlike "Could not access password")
                            {
                                $Hash.Credential = New-Object System.Management.Automation.PSCredential($user,$password)
                            }
                            else
                            {
                                $Hash.Credential = $password
                            }
                        }

                        #Output
                            [pscustomobject]$Hash
                    }
                }
        }
    }
}


function Get-SecretActivity
{
    <#
    .SYNOPSIS
        Get secret activity from secret server database

    .DESCRIPTION
        Get secret activity from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER UserName
        UserName to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER SecretName
        SecretName to search for.  Accepts wildcards as * or %

    .PARAMETER Action
        Action to search for.  Accepts wildcards as * or %

    .PARAMETER IPAddress
        IPAddress to search for.  Accepts wildcards as * or %

    .PARAMETER StartDate
        Search for activity after this start date

    .PARAMETER EndDate
        Search for activity before this end date

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SecretActivity -SecretName SQL-DB-2014* -Action WebServiceView

        #Get Secret activity for secrets with name like SQL-DB-2014*, Showing only WebServiceView actions.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SecretActivity -UserName cmonster -StartDate $(get-date).adddays(-1) -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show secret activity for cmonster over the past day

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$SecretName,
        [datetime]$StartDate = (Get-Date).AddDays(-7),
        [datetime]$EndDate,
        [string[]]$Action,
        [string]$IPAddress,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Set up the where statement and sql parameters
        $JoinQuery = @("1=1")
        $SQLParameters = @{}
        $SQLParamKeys = echo UserName, UserId, SecretName, IPAddress, StartDate, EndDate

        if($PSBoundParameters.ContainsKey('StartDate'))
        {
                $JoinQuery += "[DateRecorded] >= @StartDate"
        }
        if($PSBoundParameters.ContainsKey('EndDate'))
        {
                $JoinQuery += "[DateRecorded] <= @EndDate"
        }
        if($PSBoundParameters.ContainsKey('Action'))
        {
            $Count = 0
            $PartialWhere = "("
            $PartialWhere += $(
                foreach($Act in $Action)
                {
                    "[Action] LIKE @Action$Count"
                    $SQLParameters."Action$Count" = $Action[$Count].Replace('*','%')
                    $Count++
                }
            ) -join " OR "
            $JoinQuery += "$PartialWhere)"
        }

        foreach($SQLParamKey in $SQLParamKeys)
        {
            if($PSBoundParameters.ContainsKey($SQLParamKey))
            {
                $Val = $PSBoundParameters.$SQLParamKey
                If($Val -is [string])
                {
                    $Val = $Val.Replace('*','%')
                    $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey"
                }

                $SQLParameters.$SQLParamKey = $Val
            }
        }

        $Where = $JoinQuery -join " AND "

    #The query
        $Query = "
		    SELECT 
			    a.DateRecorded,
			    upn.DisplayName,
                u.UserId,
                u.UserName,
			    fp.FolderPath,
			    s.SecretName,
			    a.Action,
			    a.Notes,
			    a.IPAddress
		    FROM tbauditsecret a WITH (NOLOCK)
			    INNER JOIN tbuser u WITH (NOLOCK)
				    ON u.userid = a.userid
				    AND u.OrganizationId = 1
			    INNER JOIN vUserDisplayName upn WITH (NOLOCK)
				    ON u.UserId = upn.UserId
			    INNER JOIN tbsecret s WITH (NOLOCK)
				    ON s.secretid = a.secretid 
			    LEFT JOIN vFolderPath fp WITH (NOLOCK)
				    ON s.FolderId = fp.FolderId
		    WHERE $Where
		    ORDER BY 
			    1 DESC, 2, 3, 4, 5, 6, 7
        "

    #Define Invoke-SqlCmd2 params
        $SqlCmdParams = @{
            ServerInstance = $ServerInstance
            Database = $Database
            Query = $Query
            As = 'PSObject'
        }
        if($Credential){
            $SqlCmdParams.Credential = $Credential
        }
        
        if($SQLParameters.Keys.Count -gt 0)
        {
            $SqlCmdParams.SQLParameters = $SQLParameters
        }
    
    #Give some final verbose output
    Write-Verbose "Query:`n$($Query | Out-String)`n`SQlParameters:`n$($SQlParameters | Out-String)"

    Invoke-Sqlcmd2 @SqlCmdParams
}


function Get-SecretAudit
{
    <#
    .SYNOPSIS
        Get audit trail for a secret from secret server

    .DESCRIPTION
        Get audit trail for a secret from secret server

    .PARAMETER SearchTerm
        If specified, obtain audit trail for all passwords matching this search term.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        Secret Id to audit.

    .PARAMETER Uri
        uri for your win auth web service.

    .PARAMETER WebServiceProxy
        Existing web service proxy from SecretServerConfig variable

    .EXAMPLE
        Get-SecretAudit -SearchTerm "SQL"

        #Get all secret audit records for secrets that matched the searchterm SQL

    .EXAMPLE
        Get-SecretAudit -SecretId 5

        #Get all secret audit records for secret with ID 5

    .EXAMPLE
        Get-Secret -SearchTerm "SQL" | Get-SecretAudit

        #Functional equivalent to Get-SecretAudit -SearchTerm "SQL"

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [string]$SearchTerm = $null,

        [Parameter( Mandatory=$false,
            ValueFromPipelineByPropertyName=$true,
            ValueFromRemainingArguments=$false,
            Position=1)]
        [int[]]$SecretId,

        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )
    Begin
    {
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
        
        #spit out errors and results for given id
        function Get-SSSecAudit 
        {
            [cmdletbinding()]
            param($id)
            if($Token){
                $result = $WebServiceProxy.GetSecretAudit($Token,$id)
            }
            else{
                $result = $WebServiceProxy.GetSecretAudit($id)
            }
            if($result.Errors)
            {
                Write-Error "Error obtaining Secret Audit for $id`:`n$($Result.Errors | Out-String)"
            }
            if($result.SecretAudits)
            {
                $result.SecretAudits
            }
        }

        #Search for secrets if searchterm was specified
        if($SearchTerm)
        {
            Write-Verbose "Calling Get-Secret for searchterm $SearchTerm"
            @( Get-Secret -SearchTerm $SearchTerm ) | ForEach-Object {
                Get-SSSecAudit -id $_.SecretId
            }
        }

    }
    Process
    {
        foreach($Id in $SecretId)
        {
            Get-SSSecAudit -id $Id
        }   
    }
}


function Get-SecretPermission
{
    <#
    .SYNOPSIS
        Get secret permissions from secret server

    .DESCRIPTION
        Get secret permissions from secret server.

        We return one object per access control entry.
        Some properties are hidden by default, use Select-Object or Get-Member to explore.
    
    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER IncludeDeleted
        Include deleted secrets

    .PARAMETER IncludeRestricted
        Include restricted secrets

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-SecretPermission -Id 5

        #Get Secret permissions for Secret ID 5

    .EXAMPLE
        Get-Secret -SearchTerm "SVC-Webcommander" | Get-SecretPermission

        # Get secret permissions for any results found by the SearchTerm 'SVC-WebCommander'

    .EXAMPLE
        Get-SecretPermission -Id 5 | Select -Property *

        #Get Secret permissions for Secret ID 5, include all properties

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [int[]]$SecretId = $null,

        [switch]$IncludeDeleted,

        [switch]$IncludeRestricted,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        

    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }

        #Set up a type name an default properties
        #This should be in the module def, but for simplicity of updates, here for now...
            $TypeName = "SecretServer.SecretPermissions"
            $defaultDisplaySet = echo SecretName Name DomainName View Edit Owner
            Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force

    }
    Process
    {
        foreach($Id in $SecretId)
        {
            Try
            {
                #If we don't remove this key, it is bound to Get-Secret below...
                if($PSBoundParameters.ContainsKey('SecretId'))
                {
                    $PSBoundParameters.Remove('SecretId') | Out-Null
                }

                $Raw = Get-Secret @PSBoundParameters -As Raw -LoadSettingsAndPermissions -ErrorAction Stop -SecretId $Id
            }
            Catch
            {
                Write-Error "Error obtaining permissions for secret id '$id':`n$_"
                Continue
            }

            if($Raw)
            {

                #Get some initial data...
                $init = [pscustomobject]@{
                    SecretName = $Raw.Name
                    SecretId = $Raw.Id
                    SecretTypeId = $Raw.SecretTypeId
                    CurrentUserHasView = $Raw.SecretPermissions.CurrentUserHasView
                    CurrentUserHasEdit = $Raw.SecretPermissions.CurrentUserHasEdit
                    CurrentUserHasOwner = $Raw.SecretPermissions.CurrentUserHasOwner
                    InheritPermissionsEnabled = $Raw.SecretPermissions.InheritPermissionsEnabled
                    IsChangeToPermissions = $Raw.SecretPermissions.IsChangeToPermissions
                }

                #Now loop through each ACE, merge initial data with ACE data
                $Permissions = $Raw.SecretPermissions.Permissions
                foreach($Permission in $Permissions)
                {
                    $Output = $init | Select -Property *, 
                        @{ label = "Name";       expression = {$Permission.UserOrGroup.Name} },
                        @{ label = "DomainName"; expression = {$Permission.UserOrGroup.DomainName} },
                        @{ label = "IsUser";     expression = {$Permission.UserOrGroup.IsUser} },
                        @{ label = "GroupId";    expression = {$Permission.UserOrGroup.GroupId} },
                        @{ label = "UserId";     expression = {$Permission.UserOrGroup.UserId} },
                        @{ label = "View";       expression = {$Permission.View} },
                        @{ label = "Edit";       expression = {$Permission.Edit} },
                        @{ label = "Owner";      expression = {$Permission.Owner} }

                    #Provide a friendly type name that will inherit the default properties
                        $Output.PSTypeNames.Insert(0,$TypeName)
                        $Output
                } 
            }
        }

    }
}


Function Get-SecretServerConfig {
    <#
    .SYNOPSIS
        Get Secret Server module configuration.

    .DESCRIPTION
        Get Secret Server module configuration

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [ValidateSet("Variable","ConfigFile")]$Source = "Variable"
    )

    if(-not (Test-Path -Path "$PSScriptRoot\SecretServer_$($env:USERNAME).xml" -ErrorAction SilentlyContinue))
    {
        Try
        {
            Write-Verbose "Did not find config file $PSScriptRoot\SecretServer_$($env:USERNAME).xml attempting to create"
            [pscustomobject]@{
                Uri = $null
                Token = $null
                ServerInstance = $null
                Database = $null
            } | Export-Clixml -Path "$PSScriptRoot\SecretServer_$($env:USERNAME).xml" -Force -ErrorAction Stop
        }
        Catch
        {
            Write-Warning "Failed to create config file $PSScriptRoot\SecretServer_$($env:USERNAME).xml: $_"
        }
    }    

    if($Source -eq "Variable" -and $SecretServerConfig)
    {
        $SecretServerConfig
    }
    else
    {
        Import-Clixml -Path "P:\Scripts\SecretServer\SecretServer\SecretServer_$($env:USERNAME).xml"
    }

}


function Get-SSFolder
{
    <#
    .SYNOPSIS
        Get details on folders from secret server

    .DESCRIPTION
        Get details on folders from secret server

    .PARAMETER Name
        Name to search for.  Accepts wildcards as '*'.

    .PARAMETER Id
        Id to search for.  Accepts wildcards as '*'.

    .PARAMETER FolderPath
        Full folder path to search for.  Accepts wildcards as '*'

    .PARAMETER Uri
        uri for your win auth web service.

    .PARAMETER WebServiceProxy
        Existing web service proxy from SecretServerConfig variable

    .EXAMPLE
        Get-SSFolder -FolderPath "*Systems*Service Accounts"

    .EXAMPLE
        Get-SSFolder -Id 55

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [string]$Name = '*',
        [string]$Id = '*',
        [string]$FolderPath = '*',
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )
    
    if(-not $WebServiceProxy.whoami)
    {
        Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
        try
        {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }
    
    #Find all folders, filter on name.  We need all to build the folderpath tree
    if($Token){
        $Folders = @( $WebServiceProxy.SearchFolders($Token,$null).Folders )
    }
    else{
        $Folders = @( $WebServiceProxy.SearchFolders($null).Folders )
    }

    #Loop through folders.  Get the full folder path
        foreach($Folder in $Folders)
        {
            $FolderName = $Folder.Name
            $FolderId = $Folder.Id
            $ParentId = $Folder.ParentFolderId
            $FullPath = "$FolderName"
            While($ParentID -notlike -1)
            {
                $WorkingFolder = $Folders | Where-Object {$_.Id -like $ParentId}
                $WorkingFolderName = $WorkingFolder.Name
                
                $FullPath = $WorkingFolderName, $FullPath -join "\"

                $ParentID = $WorkingFolder.ParentFolderId
            }
            $Folder | Add-Member -MemberType NoteProperty -Name "FolderPath" -Value $FullPath -force
        }
        
    #Filter on the specified parameters
        $Folders = $Folders | Where-Object {$_.FolderPath -like $FolderPath -and $_.Name -like $Name -and $_.Id -like $Id}

    $Folders

}


function Get-SSFolderPermission
{
    <#
    .SYNOPSIS
        Get secret folder permissions from secret server database

    .DESCRIPTION
        Get secret folder permissions from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER FolderPath
        FolderPath to search for.  Accepts wildcards as * or %

    .PARAMETER InheritPermissions
        Whether permissions are inherited.  Yes or no.

    .PARAMETER Principal
        User or group to search for.  Accepts wildcards as * or %

    .PARAMETER Permissions
        Specific access to search for.  View, Edit, or Owner.

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSFolderPermission -Principal '*support* -Permissions View

        #Get Secret Server folder permissions for groups or users matching 'Support', with view or greater permissions.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSFolderPermission '*High Privilege*' -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show Folder Permissions to any folder with path matching 'High Privilege'

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$FolderPath,
        [validateset("yes","no")][string]$InheritPermissions,
        [string]$Principal,
        [validateset("View","Edit","Owner")]
        [string[]]$Permissions,
        [string]$UserId,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Build up the query
    $JoinQuery = @()
    $SQLParameters = @{}
    $SQLParamKeys = echo FolderPath, InheritPermissions, Principal, Permissions

    foreach($SQLParamKey in $SQLParamKeys)
    {
        if($PSBoundParameters.ContainsKey($SQLParamKey))
        {
            $val = $PSBoundParameters.$SQLParamKey
            switch($SQLParamKey)
            {
                'InheritPermissions'
                {
                    $JoinQuery += "[Inherit Permissions] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey
                }
                'Principal'
                {
                    $JoinQuery += "[DisplayName] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
                }
                'Permissions'
                {
                    $count = 0
                    foreach($Perm in $Permissions)
                    {
                        $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey$Count"
                        $SQLParameters."$SQLParamKey$Count" = "%$($val[$count])%"
                        $Count++
                    }
                }
                'FolderPath'
                {
                    $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
                }
            }
        }
    }

    $Where = $null
    if($JoinQuery.count -gt 0)
    {
        $Where = " AND $($JoinQuery -join " AND ")"
    }

    $Query = "
        SELECT	
	        fp.FolderPath,
	        gfp.[Inherit Permissions] AS [InheritPermissions],
	        gdn.[DisplayName] AS [Principal],
	        gfp.[Permissions],
            gdn.[GroupId]
        FROM  vGroupFolderPermissions gfp WITH (NOLOCK)
	        INNER JOIN vFolderPath fp WITH (NOLOCK)
		        ON fp.FolderId = gfp.FolderId
	        INNER JOIN vGroupDisplayName gdn WITH (NOLOCK)
		        ON gdn.GroupId = gfp.GroupId
        WHERE
	        gfp.OrganizationId = 1 $Where
        ORDER BY 1,2,3,4
        OPTION (HASH JOIN)"

    Write-Verbose "Query:`n$($Query | Out-String)`n`nSQLParams:`n$($SQLParameters | Out-String)"


#common parameters for SQL queries
    $SqlCmdParams = @{
        ServerInstance = $ServerInstance
        Database = $Database
        As = 'PSObject'
        Query = $Query
    }

    If($Credential)
    {
        $SqlCmdParams.Credential = $Credential
    }
    If($SQLParameters.Keys.Count -gt 0)
    {
        $SqlCmdParams.SQLParameters = $SQLParameters
    }

    Invoke-Sqlcmd2 @SqlCmdParams | Foreach {
        $Permissions = $_.Permissions -split "/"
        [pscustomobject]@{
            FolderPath = $_.FolderPath
            InheritPermissions = $_.InheritPermissions
            Principal = $_.Principal
            View = $Permissions -contains "View"
            Edit = $Permissions -contains "Edit"
            Owner = $Permissions -contains "Owner"
            Permissions = $_.Permissions
            GroupId = $_.GroupId
        }
    }

}


function Get-SSGroupMembership
{
    <#
    .SYNOPSIS
        Get secret server group membership from database

    .DESCRIPTION
        Get secret server group membership from database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER UserName
        UserName to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER GroupName
        GroupName to search for.  Accepts wildcards as * or %

    .PARAMETER GroupId
        GroupId to search for.  Accepts wildcards as * or %

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSGroupMembership -UserName cmonster -GroupName *server*

        #Get group membership for cmonster, where the group is like *server*.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE
        Get-SSGroupMembership -UserName cmonster | Select -ExpandProperty GroupName

        #Get all group membership for cmonster, expand the group name.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSGroupMembership -GroupId 3 -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer |
            Select -ExpandProperty UserName
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Get users in group 3, list the UserName only

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$GroupName,
        [string]$GroupId,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Set up the where statement and sql parameters
        $JoinQuery = @()
        $SQLParameters = @{}
        $SQLParamKeys = echo UserName, UserId, GroupName, GroupId

        foreach($SQLParamKey in $SQLParamKeys)
        {
            if($PSBoundParameters.ContainsKey($SQLParamKey))
            {
                $col = $SQLParamKey
                if($col -like 'GroupId'){$col = 'g.GroupId'}
                $JoinQuery += "$col LIKE @$SQLParamKey"
                $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
            }
        }

        if($JoinQuery.count -gt 0)
        {
            $Where = " AND ( $($JoinQuery -join " AND ") )"
        }

    $Query = "
		SELECT	
			gdn.DisplayName AS [GroupName],
            gdn.GroupId,
            u.UserName,
            u.UserId,
			CASE g.Active 
			WHEN 1 THEN 'Yes'
			WHEN 0 THEN 'No'
			END AS [IsGroupActive]
		FROM tbGroup g WITH (NOLOCK)
			INNER JOIN vGroupDisplayName gdn WITH (NOLOCK)
				ON g.GroupId = gdn.GroupId
			LEFT JOIN tbUserGroup ug WITH (NOLOCK)
				ON g.GroupId = ug.GroupId
			LEFT JOIN tbUser u WITH (NOLOCK)
				ON ug.UserId = u.UserId 
				AND u.OrganizationId = 1
			LEFT JOIN vUserDisplayName udn WITH (NOLOCK)
				ON u.UserId = udn.UserId 
		WHERE
			(u.[Enabled] = 1 OR u.UserId IS NULL)
			AND
			g.IsPersonal = 0
			AND
			g.OrganizationId = 1
			AND
			g.SystemGroup = 0
            $WHERE
		ORDER BY
			[GroupName] ASC ,2 
    "

    #Define Invoke-SqlCmd2 params
        $SqlCmdParams = @{
            ServerInstance = $ServerInstance
            Database = $Database
            Query = $Query
            As = 'PSObject'
        }
        if($Credential){
            $SqlCmdParams.Credential = $Credential
        }
        
        if($SQLParameters.Keys.Count -gt 0)
        {
            $SqlCmdParams.SQLParameters = $SQLParameters
        }
    
    #Give some final verbose output
    Write-Verbose "Query:`n$($Query | Out-String)`n`SQlParameters:`n$($SQlParameters | Out-String)"

    Invoke-Sqlcmd2 @SqlCmdParams
}


function Get-SSTemplate
{
    <#
    .SYNOPSIS
        Get details on secret templates from secret server

    .DESCRIPTION
        Get details on secret templates from secret server

    .PARAMETER Name
        Name to search for.  Accepts wildcards as '*'.

    .PARAMETER Id
        Id to search for.  Accepts wildcards as '*'.

    .PARAMETER Raw
        If specified, return raw template object

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-SSTemplate -Name "Windows*"

    .EXAMPLE
        Get-SSTemplate -Id 6001

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [string[]]$Name = $null,
        [string]$Id = $null,
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [switch]$Raw,
        [string]$Token = $SecretServerConfig.Token        
    )

    if(-not $WebServiceProxy.whoami)
    {
        Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
        try
        {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }

    #Find all templates, filter on name
        if($Token){
            $AllTemplates = @( $WebServiceProxy.GetSecretTemplates($Token).SecretTemplates )
        }
        else{
            $AllTemplates = @( $WebServiceProxy.GetSecretTemplates().SecretTemplates )
        }

        if($Name)
        {
            $AllTemplates = $AllTemplates | Foreach-Object {
                $ThisName = $_.Name
                foreach($InputName in $Name)
                {
                    If($Thisname -like $InputName ) { $_ }
                }
            }
        }
        
        if($Id)
        {
            $AllTemplates  = $AllTemplates | Where-Object {$_.Id -like $Id}
        }
        
    #Extract the secrets
        if($Raw)
        {
            $AllTemplates
        }
        else
        {
            foreach($Template in $AllTemplates)
            {
                #Start building up output
                    [pscustomobject]@{
                        ID = $Template.Id
                        Name = $Template.Name
                        Fields = $Template.Fields.Displayname -Join ", "
                    }
            }
        }
}


Function Get-SSTemplateField
{
    <#
    .SYNOPSIS
        Get fields on secret templates from secret server

    .DESCRIPTION
        Get fields on secret templates from secret server

    .PARAMETER Name
        Template Name to search for.  Accepts wildcards as '*'.

    .PARAMETER ID
        Template ID to search for.

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-SSTemplateField -name "Active Directory*"

    .EXAMPLE
        Get-SSTemplateField -Id 6001

    .EXAMPLE
        Get-SSTemplate -Name Wind* | Get-SSTemplateField

        # Find templates starting with Wind, get fields for these templates

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=0)]
        [String]$Id = '*',

        [string[]]$Name = $null,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token        
    )
    Begin
    {

        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }

        #Find all templates, filter on name
            if($Token){
                $AllTemplates = @( $WebServiceProxy.GetSecretTemplates($Token).SecretTemplates )
            }
            else{
                $AllTemplates = @( $WebServiceProxy.GetSecretTemplates().SecretTemplates )
            }

            if($Name)
            {
                $AllTemplates = $AllTemplates | Foreach-Object {
                    $ThisName = $_.Name
                    foreach($InputName in $Name)
                    {
                        If($Thisname -like $InputName ) { $_ }
                    }
                }
            }
    }
    Process
    {
        Write-Verbose "Working on ID $ID"
        foreach($TemplateID in $ID)
        {
            $AllTemplates | where {$_.Id -like $TemplateID} | ForEach-Object {
                foreach($Field in $_.Fields)
                {
                    [pscustomobject]@{
                        TemplateId = $_.ID
                        TemplateName = $_.Name
                        DisplayName = $Field.DisplayName
                        Id = $Field.Id
                        IsPassword = $Field.IsPassword
                        IsUrl = $Field.IsUrl
                        IsNotes = $Field.IsNotes
                        IsFile = $Field.IsFile
                    }
                }
            }
        }
    }
}


Function Get-SSUser
{
    <#
    .SYNOPSIS
        Get secret users from secret server database

    .DESCRIPTION
        Get secret users from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
        Some properties are hidden by default, use Select-Object or Get-Member to explore.
    
    .PARAMETER Username
        Username to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER DisplayName
        DisplayName to search for.  Accepts wildcards as * or %

    .PARAMETER EmailAddress
        EmailAddress to search for.  Accepts wildcards as * or %

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER LogicalJoin
        Parameters will be joined with AND or OR

    .PARAMETER DefaultProperties
        Properties to display in the default output

        Default: "UserId", "UserName", "DisplayName", "LastLogin", "Created", "Enabled", "EmailAddress"

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSUser -UserName cookie*

        #Get Secret Server users with name starting 'cookie'.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSUser -DisplayName *monster* -DefaultProperties UserId, DisplayName -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show UserId and DisplayName for users with a displayname like %monster%

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$DisplayName,
        [string]$EmailAddress,

        [string][validateset("OR","AND")]$LogicalJoin = "AND",
        [string[]]$DefaultProperties = @("UserId", "UserName", "DisplayName", "LastLogin", "Created", "Enabled", "EmailAddress"),
        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Give a friendly type name, set default properties
    $TypeName = "SecretServer.User"
    Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $DefaultProperties -Force

    #common parameters for SQL queries
    $params = @{
        ServerInstance = $ServerInstance
        Database = $Database
        Credential = $Credential
    }

    $UserQuery = "SELECT * FROM tbUser WHERE 1=1 "
    $JoinQuery = @()
    $SQLParameters = @{}
    $SQLParamKeys = echo UserName, UserId, DisplayName, EmailAddress

    foreach($SQLParamKey in $SQLParamKeys)
    {
        if($PSBoundParameters.ContainsKey($SQLParamKey))
        {
            $JoinQuery += "$SQLParamKey LIKE @$SQLParamKey"
            $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
        }
    }

    if($JoinQuery.count -gt 0)
    {
        $UserQuery = "$UserQuery AND ( $($JoinQuery -join " $LogicalJoin ") )"
    }

    Write-Verbose "Query:`n$($UserQuery | Out-String)`n`nSQLParams:`n$($SQLParameters | Out-String)"
    
    Try
    {
        $Results = @( Invoke-Sqlcmd2 @params -Query $UserQuery -SqlParameters $SQLParameters -as PSObject)
        Foreach($Result in $Results)
        {
            #Provide a friendly type name that will inherit the default properties
            $Result.PSTypeNames.Insert(0,$TypeName)
            $Result
        }
    }
    Catch
    {
        Throw $_
    }
}


function Get-SSVersion
{
    <#
    .SYNOPSIS
        Gets the version of Secret Server.

    .DESCRIPTION
        Gets the version of Secret Server.

    .EXAMPLE
        #Compares the version of Secret Server against a known version.
        
        $Version = Get-SSVersion
        if ($Version -lt [Version]"8.0.0") 
    
    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    Process
    {
        if($Token){
            $VersionResult = $WebServiceProxy.VersionGet($Token)
        }
        else{
            $VersionResult = $WebServiceProxy.VersionGet()
        }
        if ($VersionResult.Errors.Length -gt 0)
        {
            Throw "Secret Server reported an error while calling VersionGet."
        }
        Return [Version]$VersionResult.Version
    }
}


function New-Secret
{
    <#
    .SYNOPSIS
        Create a new secret in secret server

    .DESCRIPTION
        Create a new secret in secret server

        This code only handles a pre-specified set of Secret templates defined in SecretType.

        Any fields not included in the parameters here are set to null

    .PARAMETER SecretType
        Secret Template to use

    .PARAMETER SecretName
        Secret Name

    .PARAMETER Domain
        For AD template, domain

    .PARAMETER Resource
        For Password template, resource
    
    .PARAMETER Server
        For SQL account template, Server

    .PARAMETER URL
        For Web template, URL

    .PARAMETER Machine
        For Windows template, Machine

    .PARAMETER Username
        Username

    .PARAMETER Password
        Password

        This takes a secure string, not a string

    .PARAMETER Notes
        Notes

    .PARAMETER FolderID
        Specific ID for the folder to create the secret within

    .PARAMETER FolderPath
        Folder path for the folder to create the secret within.  Accepts '*' as wildcards, but must return a single folder. 

    .PARAMETER Force
        If specified, suppress prompt for confirmation

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .PARAMETER Token
        Token for your query.  If you do not use Windows authentication, you must request a token.

        See Get-Help Get-SSToken

    .EXAMPLE
        New-Secret -SecretType 'Active Directory Account' -Domain Contoso.com -Username SQLServiceX -password $Credential.Password -notes "SQL Service account for SQLServerX\Instance" -FolderPath "*SQL Service"

        Create an active directory account for Contoso.com, user SQLServiceX, include notes that point to the SQL instance running it, specify a folder path matching SQL Service. 

    .EXAMPLE
        
        $SecureString = Read-Host -AsSecureString -Prompt "Enter password"
        New-Secret -SecretType 'SQL Server Account' -Server ServerNameX -Username sa -Password $SecureString -FolderID 25

        Create a secure string we will pass in for the password.
        Create a SQL account secret for the sa login on instance ServerNameX, put it in folder 25 (DBA).

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding(DefaultParameterSetName = "AD", SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [parameter( Mandatory = $True )]
        [validateset("Active Directory Account", "SQL Server Account", "Web Password", "Windows Account", "Password")]
        [string]$SecretType,

        [parameter( ParameterSetName = "AD",
                    Mandatory = $True )]
        [string]$Domain,

        [parameter( ParameterSetName = "PW",
                    Mandatory = $True )]
        [string]$Resource,

        [parameter( ParameterSetName = "SQL",
                    Mandatory = $True )]
        [string]$Server,

        [parameter( ParameterSetName = "WEB",
                    Mandatory = $True )]
        [string]$URL,
              
        [parameter( ParameterSetName = "WIN",
                    Mandatory = $True )]
        [string]$Machine,       

        [parameter(ParameterSetName = "AD", Mandatory = $True )]
        [parameter(ParameterSetName = "PW", Mandatory = $False)]
        [parameter(ParameterSetName = "SQL", Mandatory = $True )]
        [parameter(ParameterSetName = "WEB", Mandatory = $True )]
        [parameter(ParameterSetName = "WIN", Mandatory = $True )]
        [string]$Username,

        [System.Security.SecureString]$Password = (Read-Host -AsSecureString -Prompt "Password for this secret:"),
        
        [string]$Notes,

        [int]$FolderID,

        [string]$FolderPath,

        [parameter(ParameterSetName = "PW", Mandatory = $True)]
        [parameter(ParameterSetName = "WEB", Mandatory = $True )]
        [parameter(ParameterSetName = "AD", Mandatory = $False )]
        [parameter(ParameterSetName = "SQL", Mandatory = $False )]
        [parameter(ParameterSetName = "WIN", Mandatory = $False )]
        [string]$SecretName,
        
        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token
    )

    $RejectAll = $false
    $ConfirmAll = $false

    $WebServiceProxy = Verify-SecretConnection -Proxy $WebServiceProxy -Token $Token

    Write-Verbose "PSBoundParameters:`n$($PSBoundParameters | Out-String)`nParameterSetName: $($PSCmdlet.ParameterSetName)"

    $InputHash = @{
        Username = $Username
        Password = $Password
        Notes = $Notes
    }

    $SecretTypeParams = @{
        AD = "Active Directory Account"
        SQL = "SQL Server Account"
        WEB = "Web Password"
        WIN = "Windows Account"
        PW = "Password"
    }

    if($SecretType -notlike $SecretTypeParams.$($PSCmdlet.ParameterSetName))
    {
        Throw "Invalid secret type.  For more information, run   Get-Help New-Secret -Full"
    }
    
    #Verify the template and get the ID
        $Template = @( Get-SSTemplate -Name $SecretType )
        if($Template.Count -ne 1)
        {
            Throw "Error finding template for $SecretType.  Template results:`n$( $Template | Format-List -Property * -Force | Out-String )"
        }
        $SecretTypeId = $Template.ID

    #Verify the folder and get the ID
        $FolderHash = @{}
        if($FolderID)
        {
            $FolderHash.ID = $FolderID
        }
        if($FolderPath)
        {
            $FolderHash.FolderPath = $FolderPath
        }

        $Folder = @( Get-SSFolder @FolderHash )
        if($Folder.Count -ne 1)
        {
            Throw "Error finding folder for $FolderHash.  Folder results:`n$( $Folder | Format-List -Property * -Force | Out-String ).  Valid folders: $(Get-SSFolder | ft -AutoSize | Out-String)"
        }
        $FolderId = $Folder.ID

    try
    {

        switch($PSCmdlet.ParameterSetName)
        {
            'AD'
            {
                $InputHash.Domain = $Domain.ToLower()
            
                #Format is domain\user
                $ShortDomain = $InputHash.Domain.split(".")[0].ToLower()
                $SecretName = "$ShortDomain\$($InputHash.Username)"
            }

            'PW'
            {
                $InputHash.Resource = $Resource
            }

            'SQL'
            {
                $Server = $Server.ToLower()

                #format is instance::user.  We use :: as instances may have a \ and would look odd.
                $InputHash.Server = $Server
                $SecretName = "$Server`::$($Username.tolower())"
            }

            'WEB'
            {
                $InputHash.URL = $URL
            }

            'WIN'
            {
                $Machine = $Machine.ToLower()
                $InputHash.Machine = $Machine

                #Format is machine\user
                $SecretName = "$Machine\$UserName"
            }
        }
    }
    catch
    {
        Throw "Error creating InputHash: $_"
    }


    #We control the order of fields, ensure all are present, by retrieving them and pulling user specified values from fields that exist.
    #TODO - Down the road we can provide a parameter for some sort of hash that allows ad hoc user specified fields, use this same methodology to ensure they are correct.
        $Fields = $Template | Get-SSTemplateField -erroraction stop

        $VerboseString = "InputHash:`n$($InputHash | Out-String)`n`nFields:`n$($Fields.DisplayName | Out-String)`nSecretTypeId: $SecretTypeId`nSecretTemplateName: $($SecretTypeParams.($PSCmdlet.ParameterSetName))`nSecretName: $SecretName`nFolderPath: $($Folder.FolderPath)"

        $FieldValues = Foreach($FieldName in $Fields.DisplayName)
        {
            if($FieldName -eq "Password")
            {
                try
                {
                    Convert-SecStrToStr -secstr ($InputHash.$FieldName) -ErrorAction stop
                }
                catch
                {
                    Throw "$_"
                }
            }
            else
            {
                $InputHash.$FieldName
            }
        }
    
        #We have everything, add the secret
        if($PSCmdlet.ShouldProcess( "Added the Secret $VerboseString",
                                    "Add the Secret $VerboseString?",
                                    "Adding Secret" ))
        {

            if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to add the secret $VerboseString ?", "Adding $VerboseString", [ref]$ConfirmAll, [ref]$RejectAll)) {


                try
                {
                    if($Token){
                        $Output = $WebServiceProxy.AddSecret($Token,$SecretTypeId, $SecretName, $Fields.Id, $FieldValues, $FolderId)
                    }
                    else{
                        $Output = $WebServiceProxy.AddSecret($SecretTypeId, $SecretName, $Fields.Id, $FieldValues, $FolderId)
                    }

                    if($Output.Secret)
                    {
                        $Output.Secret
                    }

                    if($Output.Error)
                    {
                        Throw "Error adding secret: $($Output.Error | Out-string)"
                    }
                }
                catch
                {
                    Throw "Error adding secret: $_"
                }
            }
        }
}


function New-SSConnection
{
    <#
    .SYNOPSIS
        Create a connection to secret server

    .DESCRIPTION
        Create a connection to secret server

        Default action updates $SecretServerConfig.Proxy which most functions use as a default

        If you specify a winauthwebservices endpoint, we remove any existing Token from your module configuration.

    .PARAMETER Uri
        Uri to connect to.  Defaults to $SecretServerConfig.Uri

    .PARAMETER Passthru
        Return the proxy object

    .PARAMETER UpdateSecretConfig
        Update the Proxy set in SecretServer.xml and $SecretServerConfig.Proxy

    .EXAMPLE
        New-SSConnection

        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the Proxy property in SecretServer.xml to this value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>
    [cmdletbinding()]
    param(       
        [string]$Uri = $SecretServerConfig.Uri,

        [switch]$Passthru,

        [bool]$UpdateSecretConfig = $true,

        [bool]$UseDefaultCredential = $True
    )

    #Windows Auth works.  Uses SOAP
        try
        {
            $Params = @{
                uri = $Uri
                ErrorAction = 'Stop'
            }
            If($UseDefaultCredential)
            {
                $Params.Add("UseDefaultCredential", $True)
            }
            $Proxy = New-WebServiceProxy @Params
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
            
        if($passthru)
        {
            $Proxy
        }

        if($UpdateSecretConfig)
        {
            if(-not (Get-SecretServerConfig).Uri)
            {
                Set-SecretServerConfig -Uri $Uri
                $SecretServerConfig.Uri = $Uri
            }
            $SecretServerConfig.Proxy = $Proxy
            
            if($Uri -match "winauthwebservices")
            {
                Set-SecretServerConfig -Token ""
            }
        }
}


function New-SSFolder
{
    <#
    .SYNOPSIS
        Creates a new folder in Secret Server

    .DESCRIPTION
        Creates a new folder in Secret Server

    .PARAMETER FolderName
        The name of the new folder

    .PARAMETER ParentFolderId
        The ID of the parent folder

    .PARAMETER FolderType
        The type of folder. This is used to determine what icon is displayed in Secret Server.

    .PARAMETER Force
        If specified, suppress prompt for confirmation

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .PARAMETER Token
        Token for your query.  If you do not use Windows authentication, you must request a token.

        See Get-Help Get-SSToken

    .EXAMPLE
        New-Folder -FolderName 'My Cool Folder'
        
        Creates a new folder with no parent and uses the default folder icon.
        
    .EXAMPLE
        New-Folder -FolderName 'My Cool Folder' -FolderType Computer
        
        Creates a new folder with no parent and uses the Computer icon.
        
    .EXAMPLE
        New-Folder -FolderName 'My Cool Folder' -FolderType Computer -ParentFolderId 7
        
        Creates a new folder using the Computer icon with a parent of 7

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FolderName,
        
        [int]$ParentFolderId = -1,
        
        [validateset("Folder", "Customer", "Computer")]
        [string]$FolderType = "Folder",
        
        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token
    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    Process
    {
        switch ($FolderType) {
            "Folder" {$FolderTypeId = 1; break;}
            "Customer" {$FolderTypeId = 2; break;}
            "Computer" {$FolderTypeId = 3; break;}
        }
        #The FolderCreate SOAP method doesn't seem to follow conventions. Normally an "Errors" property contains errors from the server.
        #In this method, it just HTTP 500's with an exception.
        
        #Using windows auth, which lacks a token parameter.
        if ($Token -eq $null -or $Token -eq "")
        {
            $FolderResult = $WebServiceProxy.FolderCreate($FolderName, $ParentFolderId, $FolderTypeId)
        }
        #Else assume we are using token-based auth.
		else 
        {
            $FolderResult = $WebServiceProxy.FolderCreate($Token, $FolderName, $ParentFolderId, $FolderTypeId)
        }
        Return $FolderResult.FolderId
    }
}


function New-SSToken
{
    <#
    .SYNOPSIS
        Create a token for secret server

    .DESCRIPTION
        Create a token for secret server

        Default action updates $SecretServerConfig.Token

    .PARAMETER WebServiceProxy
        Proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Passthru
        Return the token object

    .PARAMETER UpdateSecretConfig
        Update the token set in SecretServer.xml and $SecretServerConfig.token

    .EXAMPLE
        New-SSConnection

        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the Proxy property in SecretServer.xml to this value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>
    [cmdletbinding()]
    param(       
        [System.Management.Automation.PSCredential]$Credential,

        [String]$Domain,
        
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Uri = $SecretServerConfig.Uri,

        [switch]$Passthru,

        [bool]$UpdateSecretConfig = $true
    )

    if(-not $WebServiceProxy.whoami)
    {
        Write-Warning "Your SecretServer proxy does not appear connected.  Creating new connection to $uri"
        try
        {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }

    if($Credential.UserName -match "\\")
    {
        $UserName = $Credential.UserName.Split("\")[1]
        $Domain = $Credential.UserName.Split("\")[0]
    }
    Else
    {
        $UserName = $Credential.UserName
    }

    $tokenResult = $WebServiceProxy.Authenticate($UserName, $Credential.GetNetworkCredential().password, '', $Domain)
    
    if($tokenResult.Errors.Count -gt 0)
    {
        Throw "Authentication Error: $($tokenResult.Errors[0])"
    }

    $token = $tokenResult.Token

    if($passthru)
    {
        $Token
    }

    if($UpdateSecretConfig)
    {
        Set-SecretServerConfig -Token $Token
        $SecretServerConfig.Token = $Token
    }


}


function Set-Secret
{
    <#
    .SYNOPSIS
        Set details on secrets from secret server.

    .DESCRIPTION
        Set details on secrets from secret server.

        If the specified SearchTerm and SearchID find more than a single Secret, we throw an error

    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER SecretName
        If specified, update to this Secret Name

    .PARAMETER Username
        If specified, update to this username

    .PARAMETER Password
        If specified, update to this Password.

        This takes a secure string, not a string

    .PARAMETER Notes
        If specified, update to this Notes

    .PARAMETER Server
        If specified, update to this Server

    .PARAMETER URL
        If specified, update to this URL

    .PARAMETER Resource
        If specified, update to this Resource

    .PARAMETER Machine
        If specified, update to this Machine

    .PARAMETER Domain
        If specified, update to this Domain

    .PARAMETER Force
        If specified, suppress prompt for confirmation

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-Secret webcommander | Set-Secret -Notes "Nothing to see here"

        #Get the secret for webcommander, set the notes field to 'nothing to see here'.
        #If multiple results matched webcommander, we would get an error.

    .EXAMPLE
        
        #Get the password we will pass in.  We need a secure string.  There are many ways to do this...
        $Credential = Get-Credential -username none -message 'Enter a password'
        
        #Change the secret password for secret 5
        Set-Secret -SecretId 5 -Password $Credential.Password

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=0)]
        [int]$SecretId,

        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=1)]
        [string]$SearchTerm = $null,

        [String]$SecretName,
        [string]$Username,
        [System.Security.SecureString]$Password,
        [string]$Notes,
        
        [string]$Server,
        [string]$URL,
        [string]$Resource,
        [string]$Machine,
        [string]$Domain,

        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )
    Begin
    {
        $RejectAll = $false
        $ConfirmAll = $false

        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    Process
    {

        #Find all passwords we have visibility to
        if($Token){
            $SecretSummary = @( $WebServiceProxy.SearchSecrets($Token,$SearchTerm,$false,$false).SecretSummaries)
        }
        else{
            $SecretSummary = @( $WebServiceProxy.SearchSecrets($SearchTerm,$false,$false).SecretSummaries)   
        }

            if($SecretId)
            {
                $SecretSummary = @( $SecretSummary | Where-Object {$_.SecretId -like $SecretId} )
            }
    
            if($SecretSummary.count -ne 1)
            {
                Throw "To edit a secret, you must specify a searchterm or secret ID that returns only a single secret to modify: $($AllSecrets.count) secrets found"
            }

        #Get the secret
            try
            {
                $Secret = $WebServiceProxy.GetSecret($SecretSummary.SecretId,$false, $null) | Select -ExpandProperty Secret -ErrorAction stop
            }
            catch
            {
                Throw "Error obtaining secret: $_"
            }
            
            #These are properties that might be set...
            $CommonProps = Echo Username, Password, Notes, Server, URL, Resource, Machine, Domain
            
            #Update the properties.  We can loop over some common field names we offer as parameters
            if($PSCmdlet.ShouldProcess( "Processed the Secret '$($Secret | Out-String)'",
                                        "Process the Secret '$($Secret | Out-String)'?",
                                        "Processing Secret" ))
            {
                $NewSecretPropsString = $PSBoundParameters.GetEnumerator() | Where-Object {$CommonProps -contains $_.Key} | Format-Table -AutoSize | Out-String

                if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change existing`n'$($Secret | Out-String)`n with changes:`n$NewSecretPropsString'?", "Processing '$($Secret | Out-String)'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                    if($SecretName)
                    {
                        $Secret.Name = $SecretName
                    }

                    foreach($CommonProp in $CommonProps)
                    {
                        if($PSBoundParameters.ContainsKey($CommonProp))
                        {
                            #Get value for this field... convert password to string
                            if($CommonProp -eq "Password")
                            {
                                Try
                                {
                                    $Val = Convert-SecStrToStr -secstr $PSBoundParameters[$CommonProp] -ErrorAction stop
                                }
                                Catch
                                {
                                    Throw "$_"
                                }
                            }
                            else
                            {
                                $Val = $PSBoundParameters[$CommonProp]
                            }

                            if($Secret.Items.FieldName -contains $CommonProp)
                            {
                                $Secret.Items | ForEach-Object {
                                    if($_.FieldName -like $CommonProp)
                                    {
                                        Write-Verbose "Changing $CommonProp from '$($_.Value)' to '$Val'"
                                        $_.Value = $Val
                                    }
                                }
                            }
                            else
                            {
                                Write-Error "You specified parameter '$CommonProp'='$Val'. This property does not exist on this secret."
                            }
                        }

                    }
        
                    $WebServiceProxy.UpdateSecret($Secret)
                }
            }
    }
}


function Set-SecretServerConfig {
    <#
    .SYNOPSIS
        Set Secret Server module configuration.

    .DESCRIPTION
        Set Secret Server module configuration, and live $SecretServerConfig global variable.

        This data is used as the default for most commands.

    .PARAMETER Proxy
        Specify a proxy to use

        This is not stored in the XML

    .PARAMETER Uri
        Specify a Uri to use

    .PARAMETER ServerInstance
        SQL Instance to query for commands that hit Secret Server database

    .PARAMETER Database
        SQL database to query for commands that hit Secret Server database

    .PARAMETER Token
        Specify a Token to use

    .Example
        $Uri = 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

        $Proxy = New-WebServiceProxy -Uri $uri -UseDefaultCredential

        Set-SecretServerConfig -Proxy $Proxy -Uri $Uri

    .Example
        Set-SecretServerConfig -Uri 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$Proxy,
        [string]$Uri,
        [string]$Token,
        [string]$ServerInstance,
        [string]$Database
    )

    Try
    {
        $Existing = Get-SecretServerConfig -ErrorAction stop
    }
    Catch
    {
        Throw "Error getting Secret Server config: $_"
    }

    foreach($Key in $PSBoundParameters.Keys)
    {
        if(Get-Variable -name $Key)
        {
            #We use add-member force to cover cases where we add props to this config...
            $Existing | Add-Member -MemberType NoteProperty -Name $Key -Value $PSBoundParameters.$Key -Force
        }
    }

    #Write the global variable and the xml
    $Global:SecretServerConfig = $Existing
    $Existing | Select -Property * -ExcludeProperty Proxy | Export-Clixml -Path "$PSScriptRoot\SecretServer_$($env:USERNAME).xml" -force

}


#Included Statements:



Export-ModuleMember -Alias * -Function "Get-SecretAudit","Get-SSVersion","Get-SecretServerConfig","Connect-SecretServer","New-Secret","Get-SSTemplate","Set-SecretServerConfig","Get-SSGroupMembership","Copy-SSPassword","New-SSFolder","Get-SecretActivity","Get-SecretPermission","Set-Secret","New-SSToken","Get-SSFolderPermission","Get-Secret","Get-SSFolder","New-SSConnection","Get-SSTemplateField","Get-SSUser"
