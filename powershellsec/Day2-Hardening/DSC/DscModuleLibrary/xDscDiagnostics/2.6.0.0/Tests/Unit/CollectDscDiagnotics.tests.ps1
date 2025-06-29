<#
.Synopsis
   Unit tests for CollectDscDiagnostics.psm1
.DESCRIPTION


.NOTES
   Code in HEADER and FOOTER regions are standard and may be moved into DSCResource.Tools in
   Future and therefore should not be altered if possible.
#>


# TODO: Customize these parameters...
$Global:ModuleName      = 'CollectDscDiagnostics' # Example xNetworking
# /TODO

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else
{
    & git @('-C',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
Import-Module (Join-Path -Path $moduleRoot -ChildPath "$Global:ModuleName.psm1") -Force
#endregion

# TODO: Other Optional Init Code Goes Here...

# Begin Testing
try
{

    #region Pester Tests

    # The InModuleScope command allows you to perform white-box unit testing on the internal
    # (non-exported) code of a Script Module.
    InModuleScope $Global:ModuleName {

        #region Pester Test Initialization
        # TODO: Optional Load Mock for use in Pester tests here...
        #endregion


        #region Function Get-FolderAsZip
        Describe "$($Global:ModuleName)\Get-FolderAsZip" {
            Context -Name 'Without Session returning path' -Fixture {
                    <#[string]$sourceFolder,
              [string] $destinationPath,
              [System.Management.Automation.Runspaces.PSSession] $Session,
              [ValidateSet('Path','Content')]
              [string] $ReturnValue = 'Path',
          [string] $filename#>
                It 'Should zip a text file' {
                    $testFolder = 'testdrive:\ziptest'
                    md $testFolder > $null
                    $resolvedTestDrive = (Resolve-Path $testDrive)
                    $resolvedTestFolder  = (Resolve-Path $testFolder).ProviderPath
                    'test' | Out-File -FilePath (Join-path $resolvedTestFolder 'test.txt')

                    # Issue, should take powershell paths.
                    Get-FolderAsZip -sourceFolder $resolvedTestFolder -destinationPath (Join-path $resolvedTestDrive 'zipout') -filename test.zip

                    Test-path testdrive:\zipout\test.zip | should be $true
                }


            }
            Context -Name 'With Session returning content' -Fixture {

            }
        }
        #endregion


        #region Function Test-ContainerParameter
        Describe "$($Global:ModuleName)\Test-ContainerParameter" {
            $testFolder = 'testdrive:\testcontainerPath'
            md $testFolder > $null
            $testFile = (Join-path $testFolder 'test.txt')
            'test' | Out-File -FilePath $testFile

            it 'should throw when path is not container' {
                {Test-ContainerParameter -Path $testFile} | should throw 'Path parameter must be a valid container.'
            }
            it 'should not throw when path is not container' {
                {Test-ContainerParameter -Path $testFolder} | should not throw
            }
        }
        #endregion


        #region Function Export-EventLog
        Describe "$($Global:ModuleName)\Export-EventLog" {
            Context -Name 'Without Session' -Fixture {
                $testFolder = 'testdrive:\eventlogexporttest'
                md $testFolder > $null
                $resolvedTestDrive = (Resolve-Path $testDrive)
                $resolvedTestFolder  = (Resolve-Path $testFolder).ProviderPath
                it 'should generate a evtx file' {
                    Write-Verbose -Message "Path to export to: $resolvedTestFolder" -Verbose
                    Export-EventLog -Name Microsoft-Windows-DSC/Operational -Path $resolvedTestFolder
                    Test-path (Join-Path $testFolder Microsoft-Windows-DSC-Operational.evtx) | should be $true
                }
            }
            Context -Name 'With Session' -Fixture {
            }
        }
        #endregion

        #region Function Get-xDscDiagnosticsZip
        Describe "$($Global:ModuleName)\New-xDscDiagnosticsZip" {
            Context "invalid calls" {
                it "should throw" {
                    {$dataPoints = Get-xDscDiagnosticsZip -includedDataPoint @('test','test2')} | should throw 'Cannot validate argument on parameter ''includedDataPoint''. IncluedDataPoint must be an array of xDscDiagnostics datapoint objects.'
                }

            }
            $testFolder = 'testdrive:\GetxDscDiagnosticsZip'
            md $testFolder > $null
            $Global:GetxDscDiagnosticsZipPath = (Resolve-Path $testFolder)

            Context 'verify with high level mock' {


                Mock Invoke-Command -MockWith {return $Global:GetxDscDiagnosticsZipPath}
                Mock Get-FolderAsZip -MockWith { Write-Verbose "executing Get-FolderAsZip mock"}
                Mock Collect-DataPoint -MockWith {return $true}
                Mock Start-Process -MockWith { Write-Verbose "executing start-process mock"}

                it 'should collect data and zip the data' {
                    New-xDscDiagnosticsZip -confirm:$false
                    Assert-MockCalled -CommandName Invoke-Command -Times 2
                    Assert-MockCalled -CommandName Get-FolderAsZip -Times 1
                    Assert-MockCalled -CommandName Start-Process -Times 1
                    Assert-MockCalled -CommandName Collect-DataPoint -Times 10
                }
            }

            Context 'verify with high level mock with eventlog datapoints' {


                Mock Invoke-Command -MockWith {return $Global:GetxDscDiagnosticsZipPath}
                Mock Get-FolderAsZip -MockWith { Write-Verbose "executing Get-FolderAsZip mock"}
                Mock Collect-DataPoint -MockWith {return $true}
                Mock Start-Process -MockWith { Write-Verbose "executing start-process mock"}

                it 'should collect data and zip the data' {
                    New-xDscDiagnosticsZip -confirm:$false -includedDataPoint (@(Get-xDscDiagnosticsZipDataPoint).where{$_.name -like '*eventlog'})
                    Assert-MockCalled -CommandName Invoke-Command -Times 2
                    Assert-MockCalled -CommandName Get-FolderAsZip -Times 1
                    Assert-MockCalled -CommandName Start-Process -Times 1
                    Assert-MockCalled -CommandName Collect-DataPoint -Times 5
                }
            }

            context 'verify with lower level mocks' {
                $testPackageFolder = 'testdrive:\package'
                md $testPackageFolder > $null
                $Global:GetxDscDiagnosticsPackagePath = (Resolve-Path $testPackageFolder)
                Mock Get-ChildItem -MockWith {
                        dir -LiteralPath $Global:GetxDscDiagnosticsPackagePath
                    } -ParameterFilter {$Path -eq 'C:\Packages\Plugins\Microsoft.Powershell.*DSC'}
                Mock Get-ChildItem -MockWith {
                        dir -LiteralPath $Global:GetxDscDiagnosticsZipPath
                    } -ParameterFilter {$null -ne $path -and $Path -ne 'C:\Packages\Plugins\Microsoft.Powershell.*DSC' -and $path -notlike '*DscPackageFolder'}
                Mock Copy-Item -MockWith {
                        '' | out-file $destination -ErrorAction SilentlyContinue
                    } -ParameterFilter {$path -notmatch '\*.\*'}
                Mock Copy-Item -MockWith {} -ParameterFilter {$path -match '\*.\*'}
                Mock Test-Path -MockWith {
                        $true
                    } -ParameterFilter {$Path -eq "$env:windir\system32\configuration\DscEngineCache.mof"}
                mock Get-hotfix -MockWith {[PSCustomObject]@{mockedhotix='kb1'}}
                mock Get-DscLocalConfigurationManager -MockWith {[PSCustomObject]@{mockedmeta='meta1'}}
                mock Get-CimInstance -MockWith {[PSCustomObject]@{mockedwin32os='os1'}}
                mock Get-DSCResource -MockWith {[PSCustomObject]@{mockedresource='resource1'}}
                $statusCommand = get-Command -name Get-DscConfigurationStatus -ErrorAction SilentlyContinue
                if($statusCommand)
                {
                    mock Get-DscConfigurationStatus -MockWith {[PSCustomObject]@{mockedstatus='status1'}}
                }
                mock Get-Content -MockWith {[PSCustomObject]@{mockedEngineCache='engineCache1'}}

                Mock Get-FolderAsZip -MockWith {}
                Mock Start-Process -MockWith {}
                mock Export-EventLog -MockWith {}
                mock Test-PullServerPresent -MockWith {$true}
                Mock Collect-DataPoint -MockWith {return $true} -ParameterFilter {$Name -eq 'IISLogs'}


                it 'should collect data and zip the data' {
                    New-xDscDiagnosticsZip -confirm:$false
                    Assert-MockCalled -CommandName Get-FolderAsZip -Times 1 -Exactly
                    Assert-MockCalled -CommandName Start-Process -Times 1 -Exactly
                    Assert-MockCalled -CommandName Copy-item -Times 4 -Exactly
                    Assert-MockCalled -CommandName Get-HotFix -Times 1 -Exactly
                    Assert-MockCalled -CommandName Get-DscLocalConfigurationManager -Times 1 -Exactly
                    Assert-MockCalled -CommandName Get-CimInstance -Times 1 -Exactly
                    Assert-MockCalled -CommandName Get-DSCResource -Times 1 -Exactly
                    Assert-MockCalled -CommandName Get-Content -Times -0 -Exactly
                    Assert-MockCalled -CommandName Collect-DataPoint -Times 0 -Exactly
                    if($statusCommand)
                    {
                        Assert-MockCalled -CommandName Get-DscConfigurationStatus -Times 1 -Exactly
                    }
                    Assert-MockCalled -CommandName Export-EventLog -Times 3 -Exactly
                }
            }

            context 'verify alias' {
                it 'should be aliased' {
                    (get-alias -Name Get-xDscDiagnosticsZip).ResolvedCommand.Name | should be 'New-xDscDiagnosticsZip'
                }
            }
        }
        #endregion

        Describe "$($Global:ModuleName)\Get-XDscConfigurationDetail" {
            $testFile1='TestDrive:\id-0.details.json'
            $testFile2='TestDrive:\id-1.details.json'
            Mock Get-ChildItem -MockWith {@([PSCustomObject]@{
                FullName = $testFile1
            }
            [PSCustomObject]@{
                FullName = $testFile2
            }
            )}
            $status = new-object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -argumentList @('MSFT_DSCConfigurationStatus')
            $status.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create('JobId','id', [Microsoft.Management.Infrastructure.CimFlags]::None))
            $status.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create('Type','type', [Microsoft.Management.Infrastructure.CimFlags]::None))
            <#$status = [PSCustomObject] @{
                CimClass=@{
                    CimClassName='MSFT_DSCConfigurationStatus'
                }
                JobId='id'
                Type='type'
            }#>
            @(@{
                name='name1'
            }
            @{
                name='name2'
            }
            ) | convertto-json | out-file $testFile1
            @(@{
                name='name3'
            }
            @{
                name='name4'
            }
            ) | convertto-json | out-file $testFile2
            context "returning records from multiple files" {

                $results = $status | Get-XDscConfigurationDetail -verbose
                it 'should return 4 records' {
                    $results.Count | should be 4
                }
                it 'record 4 should be name4' {
                    $results[3].name | should be 'name4'
                    $results[0].name | should be 'name1'
                }

            }
            context "invalid input" {
                Write-verbose "ccn: $($status.CimClass.CimClassName)" -Verbose
                $invalidStatus = [PSCustomObject] @{JobId = 'id'; Type = 'type'}

                it 'should throw cannot process argument' {
                    {Get-XDscConfigurationDetail -verbose -ConfigurationStatus $invalidStatus}| should throw 'Cannot validate argument on parameter 'ConfigurationStatus'. Must be a configuration status object".'
                }
            }
        }

        Describe "$($Global:ModuleName)\Get-XDscConfigurationDetailByJobId" {
            $jobId = [System.Guid]::NewGuid().ToString('B')
            $testFile="TestDrive:\$jobId-0.details.json"

            $status = new-object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -argumentList @('MSFT_DSCConfigurationStatus')
            $status.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create('JobId','id', [Microsoft.Management.Infrastructure.CimFlags]::None))
            $status.CimInstanceProperties.Add([Microsoft.Management.Infrastructure.CimProperty]::Create('Type','type', [Microsoft.Management.Infrastructure.CimFlags]::None))

            @(@{
                name='name1'
            }
            @{
                name='name2'
            }
            ) | convertto-json | out-file $testFile

            context 'Get configuration details by job id' {
                # Path queried by Get-XDscConfigurationDetail to retrieve the configuration details file
                $gciParameter = "$env:windir\System32\Configuration\ConfigurationStatus\$jobId-?.details.json"
                
                Mock Get-ChildItem -MockWith {@([PSCustomObject]@{
                    FullName = $testFile
                } 
                )} -ParameterFilter { $Path -eq $gciParameter }

                $results = Get-XDscConfigurationDetail -jobId $jobId
                $results
                it 'should return 2 records' {
                    $results.Count | should be 2
                }
                it 'record 0 should be name1' {
                    $results[0].name | should be 'name1'
                }
                it 'record 1 should be name2' {
                    $results[1].name | should be 'name2'
                }
            }

           context 'Get configuration details using an invalid GUID for a job id' {
                it 'should throw cannot validate argument on parameter JobId' {
                    {Get-XDscConfigurationDetail -JobId 'foo'} | should throw "Cannot validate argument on parameter 'JobId'. JobId must be a valid GUID"
                }
            }

           context 'Get configuration details using a job id that does not exist' {
                $jobId = [System.Guid]::NewGuid().ToString('B')
                it 'should throw Cannot find configuration details for job' {
                    {Get-XDscConfigurationDetail -JobId $jobId} | should throw "Cannot find configuration details for job $jobId"
                }
            }           
        }

        Describe "$($Global:ModuleName)\Get-xDscDiagnosticsZipDataPoint" {
            it "should not throw" {
                {$dataPoints = Get-xDscDiagnosticsZipDataPoint} | should not throw
            }

            $dataPoints = @(Get-xDscDiagnosticsZipDataPoint)

            it "should return 17 points" {
                $dataPoints.Count | should be 17
            }

            foreach($dataPoint in $dataPoints) {
                Context "DataPoint $($dataPoint.Name)" {
                    it "should have name" {
                        $dataPoint.Name | should not benullorempty
                    }
                    it "should have description "{
                        $dataPoint.Description |  should not benullorempty
                    }
                    it "should have a target"{
                        $dataPoint.Target |  should not benullorempty
                    }
                    it "should be of type 'xDscDiagnostics.DataPoint'"{
                        $dataPoint.pstypenames[0] |  should be 'xDscDiagnostics.DataPoint'
                    }

                    it "should have 2 NoteProperties"{
                        @($dataPoint | get-member -MemberType NoteProperty).count | should be 3
                    }
                    it "should have 4 Methods"{
                        # Methods, Equals, GetHashCode, GetType, ToString
                        @($dataPoint | get-member -MemberType Method).count | should be 4
                    }
                    it "should have no other members"{
                        @($dataPoint | get-member).count | should be 7
                    }
                }
            }
        }

        # TODO: Pester Tests for any Helper Cmdlets

    }
    #endregion
}
finally
{
    #region FOOTER
    #endregion

    # TODO: Other Optional Cleanup Code Goes Here...
}
