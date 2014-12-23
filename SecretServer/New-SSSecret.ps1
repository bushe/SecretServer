﻿Function New-SSSecret
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

        If you don't specify this for AD, Windows, or SQL accounts, we use the following:
            AD:      domain\username
            Windows: machine\username
            SQL:     server::username

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

    .PARAMETER Notes
        Notes

    .PARAMETER FolderID
        Specific ID for the folder to create the secret within

    .PARAMETER FolderPath
        Folder path for the folder to create the secret within.  Accepts '*' as wildcards, but must return a single folder. 

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        New-SSSecret -SecretType 'Active Directory Account' -Domain Contoso.com -Username SQLServiceX -password "***********" -notes "SQL Service account for SQLServerX\Instance" -FolderPath "*SQL Service"

        Create an active directory account for Contoso.com, user SQLServiceX, include notes that point to the SQL instance running it, specify a folder path matching SQL Service. 

    .EXAMPLE
        New-SSSecret -SecretType 'SQL Server Account' -Server ServerNameX -Username sa -Password "**********" -FolderID 25

        Create a SQL account secret for the sa login on instance ServerNameX, put it in folder 25 (DBA)

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding(DefaultParameterSetName = "AD")]
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

        [parameter( Mandatory = $True)]
        [string]$Password,
        #TODO:  Combine username and Password into credential input.  Challenge: username may be optional...
        
        [string]$Notes,

        [int]$FolderID,

        [string]$FolderPath,

        [parameter(ParameterSetName = "PW", Mandatory = $True)]
        [parameter(ParameterSetName = "WEB", Mandatory = $True )]
        [parameter(ParameterSetName = "AD", Mandatory = $False )]
        [parameter(ParameterSetName = "SQL", Mandatory = $False )]
        [parameter(ParameterSetName = "WIN", Mandatory = $False )]
        [string]$SecretName,
        
        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy
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
            Throw "Invalid secret type.  For more information, run   Get-Help New-SSSecret -Full"
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
                    if(-not $PSBoundParameters.SecretName)
                    {
                        $SecretName = "$ShortDomain\$($InputHash.Username)"
                    }
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
                    if(-not $PSBoundParameters.SecretName)
                    {
                        $SecretName = "$Server`::$($Username.tolower())"
                    }
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
                    if(-not $PSBoundParameters.SecretName)
                    {
                        $SecretName = "$Machine\$UserName"
                    }
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

        
            Write-Verbose "InputHash:`n$($InputHash | Out-String)`n`nFields:`n$($Fields.DisplayName | Out-String)`nSecretTypeId: $SecretTypeId`nSecretName: $SecretName`nFolderPath: $($Folder.FolderPath)"

            $FieldValues = Foreach($FieldName in $Fields.DisplayName)
            {
                $InputHash.$FieldName
            }
        
        #We have everything...
        try
        {
            $Output = $WebServiceProxy.AddSecret($SecretTypeId, $SecretName, $Fields.Id, $FieldValues, $FolderId)

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