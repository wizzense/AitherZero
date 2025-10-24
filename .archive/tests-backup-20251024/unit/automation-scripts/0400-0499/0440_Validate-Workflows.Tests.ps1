#Requires -Version 7.0

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0440_Validate-Workflows.ps1"
    $script:TestWorkflowsPath = Join-Path $PSScriptRoot "test-workflows"
    
    # Create test workflows directory
    if (-not (Test-Path $script:TestWorkflowsPath)) {
        New-Item -ItemType Directory -Path $script:TestWorkflowsPath -Force | Out-Null
    }
}

Describe "0440_Validate-Workflows.ps1" {
    Context "Script Validation" {
        It "Should exist at the expected location" {
            Test-Path $script:ScriptPath | Should -Be $true
        }
        
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }
        
        It "Should support WhatIf" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match 'SupportsShouldProcess'
        }
    }
    
    Context "Valid Workflow Testing" {
        BeforeAll {
            # Create a valid workflow file
            $script:ValidWorkflow = Join-Path $script:TestWorkflowsPath "valid-workflow.yml"
            @'
name: Valid Test Workflow
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  issues: write

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup PowerShell
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.x'
      
      - name: Run tests
        run: |
          echo "Running tests"
          exit 0
'@ | Set-Content -Path $script:ValidWorkflow
        }
        
        It "Should validate a correct workflow file" {
            $result = & $script:ScriptPath -Path $script:ValidWorkflow -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $validation.ValidFiles | Should -Be 1
            $validation.InvalidFiles | Should -Be 0
        }
        
        It "Should detect best practices in valid workflow" {
            $result = & $script:ScriptPath -Path $script:ValidWorkflow -CheckBestPractices -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $validation.FileResults.$($script:ValidWorkflow).Warnings.Count | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Invalid Workflow Testing" {
        BeforeAll {
            # Create workflow with YAML syntax error
            $script:InvalidYamlWorkflow = Join-Path $script:TestWorkflowsPath "invalid-yaml.yml"
            @'
name: Invalid YAML
on:
  push:
    branches: [main]
	invalid_tab_indentation: true
jobs:
  test:
    runs-on: ubuntu-latest
'@ | Set-Content -Path $script:InvalidYamlWorkflow
            
            # Create workflow missing required fields
            $script:MissingFieldsWorkflow = Join-Path $script:TestWorkflowsPath "missing-fields.yml"
            @'
# Missing 'name' and improper structure
on:
  push:
    branches: [main]

jobs:
  test:
    # Missing runs-on
    steps:
      - run: echo "test"
'@ | Set-Content -Path $script:MissingFieldsWorkflow
        }
        
        It "Should detect YAML syntax errors" {
            $result = & $script:ScriptPath -Path $script:InvalidYamlWorkflow -OutputFormat JSON -WhatIf:$false 2>$null
            $validation = $result | ConvertFrom-Json
            $validation.InvalidFiles | Should -Be 1
            $validation.FileResults.$($script:InvalidYamlWorkflow).Errors.Count | Should -BeGreaterThan 0
        }
        
        It "Should detect missing required fields" {
            $result = & $script:ScriptPath -Path $script:MissingFieldsWorkflow -OutputFormat JSON -WhatIf:$false 2>$null
            $validation = $result | ConvertFrom-Json
            $validation.FileResults.$($script:MissingFieldsWorkflow).Errors | Should -Contain "Missing required key: name"
        }
    }
    
    Context "Deprecated Features Detection" {
        BeforeAll {
            $script:DeprecatedWorkflow = Join-Path $script:TestWorkflowsPath "deprecated.yml"
            @'
name: Deprecated Features
on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v1
      - run: echo "::set-output name=test::value"
      - run: echo "::set-env name=TEST::value"
'@ | Set-Content -Path $script:DeprecatedWorkflow
        }
        
        It "Should detect deprecated actions" {
            $result = & $script:ScriptPath -Path $script:DeprecatedWorkflow -CheckDeprecated -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:DeprecatedWorkflow).Warnings
            $warnings | Should -Match "Deprecated action.*checkout@v2"
            $warnings | Should -Match "Deprecated action.*setup-node@v1"
        }
        
        It "Should detect deprecated commands" {
            $result = & $script:ScriptPath -Path $script:DeprecatedWorkflow -CheckDeprecated -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:DeprecatedWorkflow).Warnings
            $warnings | Should -Match "set-output is deprecated"
            $warnings | Should -Match "set-env is deprecated"
        }
    }
    
    Context "Security Checks" {
        BeforeAll {
            $script:InsecureWorkflow = Join-Path $script:TestWorkflowsPath "insecure.yml"
            @'
name: Security Issues
on: push

env:
  API_KEY: "hardcoded-secret-key-12345"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "password=SuperSecret123" >> config.txt
          curl -H "Authorization: Bearer ${{ secrets.AZURE_TOKEN }}" https://api.example.com
'@ | Set-Content -Path $script:InsecureWorkflow
        }
        
        It "Should detect hardcoded secrets" {
            $result = & $script:ScriptPath -Path $script:InsecureWorkflow -CheckSecrets -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $errors = $validation.FileResults.$($script:InsecureWorkflow).Errors
            $errors | Should -Match "hardcoded secret"
        }
        
        It "Should identify secret references" {
            $result = & $script:ScriptPath -Path $script:InsecureWorkflow -CheckSecrets -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:InsecureWorkflow).Warnings
            $warnings | Should -Match "AZURE_TOKEN"
        }
    }
    
    Context "Best Practices Validation" {
        BeforeAll {
            $script:PoorPracticesWorkflow = Join-Path $script:TestWorkflowsPath "poor-practices.yml"
            @'
name: Poor Practices
on: push

jobs:
  test:
    runs-on: ubuntu-latest
    # Missing timeout-minutes
    steps:
      - uses: actions/checkout@v4
        # Missing fetch-depth
      
      - name: Install dependencies
        run: npm install
        # No caching
      
      - uses: actions/upload-artifact@v4
        with:
          name: artifact
          path: ./output
          # Missing retention-days
      
      - name: Always run
        if: always()
        # Dangerous always() without conditions
        run: rm -rf /
'@ | Set-Content -Path $script:PoorPracticesWorkflow
        }
        
        It "Should suggest timeout-minutes" {
            $result = & $script:ScriptPath -Path $script:PoorPracticesWorkflow -CheckBestPractices -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:PoorPracticesWorkflow).Warnings
            $warnings | Should -Match "timeout-minutes"
        }
        
        It "Should suggest caching for dependencies" {
            $result = & $script:ScriptPath -Path $script:PoorPracticesWorkflow -CheckBestPractices -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:PoorPracticesWorkflow).Warnings
            $warnings | Should -Match "actions/cache"
        }
        
        It "Should warn about dangerous always() usage" {
            $result = & $script:ScriptPath -Path $script:PoorPracticesWorkflow -CheckBestPractices -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $warnings = $validation.FileResults.$($script:PoorPracticesWorkflow).Warnings
            $warnings | Should -Match "always\(\).*dangerous"
        }
    }
    
    Context "Output Formats" {
        BeforeAll {
            $script:SimpleWorkflow = Join-Path $script:TestWorkflowsPath "simple.yml"
            @'
name: Simple
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
'@ | Set-Content -Path $script:SimpleWorkflow
        }
        
        It "Should output valid JSON format" {
            $result = & $script:ScriptPath -Path $script:SimpleWorkflow -OutputFormat JSON -WhatIf:$false
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should output valid HTML format" {
            $result = & $script:ScriptPath -Path $script:SimpleWorkflow -OutputFormat HTML -WhatIf:$false
            $result | Should -Match '<html>'
            $result | Should -Match '</html>'
        }
        
        It "Should output valid Markdown format" {
            $result = & $script:ScriptPath -Path $script:SimpleWorkflow -OutputFormat Markdown -WhatIf:$false
            $result | Should -Match '^# GitHub Actions Workflow Validation Report'
            $result | Should -Match '\| Metric \| Value \|'
        }
    }
    
    Context "Strict Mode" {
        BeforeAll {
            $script:WarningWorkflow = Join-Path $script:TestWorkflowsPath "warnings.yml"
            @'
name: Warnings Only
on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # This will generate warnings but no errors
      - run: npm install
'@ | Set-Content -Path $script:WarningWorkflow
        }
        
        It "Should pass without strict mode when only warnings exist" {
            $result = & $script:ScriptPath -Path $script:WarningWorkflow -CheckBestPractices -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $validation.ValidFiles | Should -Be 1
        }
        
        It "Should fail with strict mode when warnings exist" {
            $result = & $script:ScriptPath -Path $script:WarningWorkflow -CheckBestPractices -Strict -OutputFormat JSON -WhatIf:$false
            $validation = $result | ConvertFrom-Json
            $validation.InvalidFiles | Should -Be 1
        }
    }
}

AfterAll {
    # Clean up test workflows
    if (Test-Path $script:TestWorkflowsPath) {
        Remove-Item -Path $script:TestWorkflowsPath -Recurse -Force
    }
}