Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-TMAzureSqlServer
(
    [Parameter(Mandatory=$true)]
    [string] $Name
)
{
    # Validation - check that sql server doesn't exist
    $rgn = Get-TMAzureWorkSet -ResourceGroupName
    $loc = Get-TMAzureWorkSet -Location
    $cred = Get-TMAzureWorkSet -SqlAdminCredential

    if (!$rgn) {
        throw "Resource Group is not set"
    }
    if (!$loc) {
        throw "Location is not set"
    }
    if (!$cred) {
        throw "SQL Admin Credential is not set" 
    }
    if ($Name -notmatch ".*sql[\d]*$") {
        Warn "Best practices recommend a SQL Server name end with 'sql' or 'sql<number>'"
    }
    if ($Name -cne $Name.ToLower()) {
        Warn "Best practice suggests SQL Server names should be lowercase"
    }
    $notPresent = $false
    $sqlserver = Get-AzureRmSqlServer -ResourceGroupName $rgn -Name $Name -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent) {
        Info "Creating SQL Server $Name"
        $sqlserver = New-AzureRmSqlServer -ResourceGroupName $rgn -ServerName $Name -Location $loc -SqlAdministratorCredentials $cred -ErrorAction Stop
        } Else {
            Info "SQL Server $Name already exists"
    }
    Set-TMAzureWorkSet -SqlServer $sqlserver
    return $sqlserver
}

function Set-TMAzureSqlElasticPool
(
    [Parameter(Mandatory=$true)]
    [string]$ElasticPoolName,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Basic", "Standard", "Premium", ignorecase = $True)]
    [string]$Edition,
    [Parameter(Mandatory=$false)]
    [Int32]$Dtu
) {
    $rgn = Get-TMAzureWorkSet -ResourceGroupName
    $sn = Get-TMAzureWorkSet -SQLServerName
    # Validation
    if (!$rgn) {
        throw "Resource Group is not set"
    }
    if (!$sn) {
        throw "SQL Server is not set"
    }
    if ($Edition -eq "Basic" ) {
        [int[]] $TMAzureElasticPoolBasicDTU = 50,100,200,300,400,800,1200,1600
        if (!($TMAzureElasticPoolBasicDTU -contains $Dtu))
        {
            Info "DTU's for $Edition must be set to $TMAzureElasticPoolBasicDTU DTU's "
            throw "Basic Edition of the Elastic Pool doesn't allow $Dtu DTU's" + `
            "See https://docs.microsoft.com/en-us/azure/sql-database/sql-database-dtu-resource-limits-elastic-pools#elastic-pool-storage-sizes-and-performance-levels"
        }
    }
    if ($Edition -eq "Standard") {
        [int[]] $TMAzureElasticPoolStandardDTU = 50,100,200,300,400,800,1200,1600,2000,2500,3000
        if (!($TMAzureElasticPoolStandardDTU -contains $Dtu))
        {
            Info "DTU's for $Edition must be set to $TMAzureElasticPoolStandardDTU DTU's "
            throw "Standard Edition of the Elastic Pool doesn't allow $Dtu DTU's" + `
            "See https://docs.microsoft.com/en-us/azure/sql-database/sql-database-dtu-resource-limits-elastic-pools#elastic-pool-storage-sizes-and-performance-levels"
        }
    }
    if ($Edition -eq "Premium") {
        [int[]] $TMAzureElasticPoolPremiumDTU = 125,250,500,1000,1500,2000,2500,3000,3500,4000
        if (!($TMAzureElasticPoolPremiumDTU -contains $Dtu))
        {
            Info "DTU's for $Edition must be set to $TMAzureElasticPoolPremiumDTU DTU's "
            throw "Premium Edition of the Elastic Pool doesn't allow $Dtu DTU's" + `
            "See https://docs.microsoft.com/en-us/azure/sql-database/sql-database-dtu-resource-limits-elastic-pools#elastic-pool-storage-sizes-and-performance-levels"
        }
    }
    if ($ElasticPoolName -cne $ElasticPoolName.ToLower()) {
        Warn "Best practice suggests Elastic Pool names should be lowercase"
    }
    if (!$ElasticPoolName.endsWith("-ep")) {
        Warn "Best practices recommend a Elastic Pool name end with '-ep'"
    }
    $notPresent = $false
    # Checks if the Elastic Pool already exists
    $elasticpool = Get-AzureRmSqlElasticPool -ResourceGroupName $rgn -ServerName $sn `
    -ElasticPoolName $ElasticPoolName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    # Creates the Elastic Pool if it doesn't exit
    if ($notPresent) {
        Info "Creating Elastic Pool $ElasticPoolName on $sn"
        $elasticpool = New-AzureRmSqlElasticPool -ResourceGroupName $rgn `
        -ElasticPoolName $ElasticPoolName -ServerName $sn -Edition $Edition -Dtu $Dtu 
    } else {
        Info "Elastic Pool $ElasticPoolName on $sn already exists"
    }
    Set-TMAzureWorkSet -SqlElasticPool $elasticpool
    return $elasticpool
}

function Set-TMAzureSqlDatabase
(
    [Parameter(Mandatory = $true, position = 0)]
    [string]$DatabaseName
) {
    $rgn = Get-TMAzureWorkSet -ResourceGroupName
    if (!$rgn) {
       throw "ResourceGroup is not set"
    }
    $sn = Get-TMAzureWorkSet -SqlServerName
    if (!$sn) {
       throw "SqlServerName not set"
    }
    if ($DatabaseName -cne $DatabaseName.ToLower()) {
       Warn "Best practice suggests DatabaseNames should be lowercase"
    }

    $notPresent = $false
    $db = Get-AzureRmSqlDatabase -DatabaseName $DatabaseName -ServerName $sn `
    -ResourceGroupName $rgn -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent) {
        Info "Creating database $DatabaseName"
        $epName = Get-TMAzureWorkSet -SqlElasticPoolName
        if ($epName) {
            $db = New-AzureRmSqlDatabase -DatabaseName $DatabaseName -ServerName $sn -ElasticPoolName $epName `
            -ResourceGroupName $rgn -ErrorAction Stop
        } else {
            $db = New-AzureRmSqlDatabase -DatabaseName $DatabaseName -ServerName $sn `
            -ResourceGroupName $rgn -ErrorAction Stop
        }    
    } else {
        Info "Databae $DatabaseName already exists"
    }
    return $db
}