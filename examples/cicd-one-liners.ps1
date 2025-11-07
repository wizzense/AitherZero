#Requires -Version 7.0

<#
.SYNOPSIS
    CI/CD One-Liner Examples for AitherZero
.DESCRIPTION
    This file demonstrates powerful one-liner automation patterns using AitherZero's
    enhanced CI/CD capabilities, config file hierarchy, and workflow helpers.
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
#>

#region Configuration Hierarchy Examples

<#
Configuration precedence (highest to lowest):
1. Custom config file (via -ConfigFile parameter)
2. config.local.psd1 (local overrides, gitignored)
3. config.psd1 (base configuration)
#>

# Example 1: Get full merged configuration
$config = Get-MergedConfiguration
# Returns: config.psd1 merged with config.local.psd1 (if exists)

# Example 2: Get configuration with custom file
$prodConfig = Get-MergedConfiguration -ConfigFile "./config.production.psd1"
# Returns: config.psd1 < config.local.psd1 < config.production.psd1

# Example 3: Get specific value from merged config
$maxConcurrency = Get-MergedConfiguration -ConfigFile "./config.ci.psd1" -Section "Automation" -Key "MaxConcurrency"

# Example 4: Using the one-liner alias
$testConfig = azconfig -ConfigFile "./config.testing.psd1"

#endregion

#region One-Liner Workflow Examples

# Example 5: Run single script with custom config
azw -Script 0402 -ConfigFile "./config.ci.psd1"

# Example 6: Run sequence with custom config and output format
azw -Sequence "0402,0404,0407" -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./test-results.xml"

# Example 7: Run playbook with variables
azw -Playbook "test-full" -Variables @{MaxConcurrency=8; ContinueOnError=$true} -Quiet

# Example 8: Full CI/CD one-liner with error handling
azw -Playbook "ci-quick" -ConfigFile "./config.ci.psd1" -OutputFormat JSON -OutputPath "./results.json" -ThrowOnError -Quiet

#endregion

#region Testing One-Liners

# Example 9: Run all tests (unit + linting + syntax)
aztest

# Example 10: Run all tests with JUnit output for CI/CD
aztest -OutputFormat JUnit -OutputPath "./test-results.xml"

# Example 11: Run all tests with custom config and error handling
aztest -ConfigFile "./config.ci.psd1" -ThrowOnError -OutputFormat JSON -OutputPath "./test-report.json"

# Example 12: Full test suite for CI/CD
Test-AitherAll -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./junit.xml" -ThrowOnError

#endregion

#region Deployment One-Liners

# Example 13: Deploy to staging
azdeploy -Environment Staging -ConfigFile "./config.staging.psd1"

# Example 14: Deploy to production with variables
azdeploy -Environment Production -ConfigFile "./config.production.psd1" -Variables @{SkipTests=$false; Backup=$true}

# Example 15: Full deployment with error handling
Invoke-AitherDeploy -Environment Production -ConfigFile "./config.production.psd1" -ThrowOnError

#endregion

#region GitHub Actions Examples

<#
# .github/workflows/ci.yml

name: CI Pipeline
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup PowerShell
        uses: actions/setup-powershell@v1
      
      - name: Run Tests
        run: |
          Import-Module ./AitherZero.psd1
          aztest -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./test-results.xml" -ThrowOnError
      
      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
        with:
          files: ./test-results.xml
#>

#endregion

#region Azure Pipelines Examples

<#
# azure-pipelines.yml

trigger:
  - main
  - develop

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: PowerShell@2
    displayName: 'Run AitherZero Tests'
    inputs:
      targetType: 'inline'
      script: |
        Import-Module ./AitherZero.psd1
        aztest -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "$(Build.ArtifactStagingDirectory)/test-results.xml" -ThrowOnError
  
  - task: PublishTestResults@2
    displayName: 'Publish Test Results'
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '$(Build.ArtifactStagingDirectory)/test-results.xml'
    condition: always()
#>

#endregion

#region GitLab CI Examples

<#
# .gitlab-ci.yml

stages:
  - test
  - deploy

test:
  stage: test
  image: mcr.microsoft.com/powershell:latest
  script:
    - pwsh -Command "Import-Module ./AitherZero.psd1; aztest -ConfigFile './config.ci.psd1' -OutputFormat JUnit -OutputPath './test-results.xml' -ThrowOnError"
  artifacts:
    reports:
      junit: test-results.xml
    when: always

deploy_staging:
  stage: deploy
  only:
    - develop
  script:
    - pwsh -Command "Import-Module ./AitherZero.psd1; azdeploy -Environment Staging -ConfigFile './config.staging.psd1' -ThrowOnError"

deploy_production:
  stage: deploy
  only:
    - main
  when: manual
  script:
    - pwsh -Command "Import-Module ./AitherZero.psd1; azdeploy -Environment Production -ConfigFile './config.production.psd1' -ThrowOnError"
#>

#endregion

#region Jenkins Pipeline Examples

<#
// Jenkinsfile

pipeline {
    agent any
    
    stages {
        stage('Test') {
            steps {
                pwsh '''
                    Import-Module ./AitherZero.psd1
                    aztest -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./test-results.xml" -ThrowOnError
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                pwsh '''
                    Import-Module ./AitherZero.psd1
                    azdeploy -Environment Staging -ConfigFile "./config.staging.psd1" -ThrowOnError
                '''
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Production?'
                pwsh '''
                    Import-Module ./AitherZero.psd1
                    azdeploy -Environment Production -ConfigFile "./config.production.psd1" -ThrowOnError
                '''
            }
        }
    }
}
#>

#endregion

#region Advanced CI/CD Patterns

# Example 16: Matrix testing with different configs
$configs = @("config.windows.psd1", "config.linux.psd1", "config.macos.psd1")
foreach ($configFile in $configs) {
    aztest -ConfigFile $configFile -OutputFormat JSON -OutputPath "./results-$(Split-Path $configFile -LeafBase).json"
}

# Example 17: Conditional deployment based on test results
$testResult = aztest -ConfigFile "./config.ci.psd1" -PassThru
if ($testResult.ScriptsFailed -eq 0) {
    azdeploy -Environment Staging -ConfigFile "./config.staging.psd1"
}

# Example 18: Full CI/CD pipeline in one script
try {
    # Run tests
    Write-Host "Running tests..." -ForegroundColor Cyan
    aztest -ConfigFile "./config.ci.psd1" -OutputFormat JUnit -OutputPath "./test-results.xml" -ThrowOnError
    
    # Deploy on success
    Write-Host "Deploying to staging..." -ForegroundColor Cyan
    azdeploy -Environment Staging -ConfigFile "./config.staging.psd1" -ThrowOnError
    
    Write-Host "CI/CD pipeline completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "CI/CD pipeline failed: $_" -ForegroundColor Red
    exit 1
}

# Example 19: Parallel execution with custom configs
$jobs = @()
$jobs += Start-Job { azw -Playbook "test-unit" -ConfigFile "./config.ci.psd1" -Quiet }
$jobs += Start-Job { azw -Playbook "test-integration" -ConfigFile "./config.ci.psd1" -Quiet }
$jobs += Start-Job { azw -Script 0404 -ConfigFile "./config.ci.psd1" -Quiet }

$jobs | Wait-Job | Receive-Job

# Example 20: Environment-specific orchestration
$environment = $env:DEPLOY_ENVIRONMENT ?? "Development"
$configFile = "./config.$($environment.ToLower()).psd1"
azw -Playbook "deploy-$($environment.ToLower())" -ConfigFile $configFile -ThrowOnError

#endregion

#region Local Development Examples

# Example 21: Local development with overrides
# Create config.local.psd1 with your local settings (gitignored)
azw -Playbook "dev-setup"  # Uses config.psd1 < config.local.psd1 automatically

# Example 22: Test with local config
aztest  # Automatically merges config.local.psd1 if it exists

# Example 23: Quick script execution with local config
azw -Script 0402  # Uses merged config automatically

#endregion

Write-Host "`nExamples complete!" -ForegroundColor Green
Write-Host "For more information, see docs/CICD-GUIDE.md" -ForegroundColor Cyan
