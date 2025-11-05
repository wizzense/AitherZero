#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Tests for BreadcrumbNavigation component
#>

BeforeAll {
    # Navigate up from tests/unit/domains/experience to project root, then to module
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $projectRoot "domains/experience/Components/BreadcrumbNavigation.psm1"
    
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module not found at: $script:ModulePath"
    }
    
    Import-Module $script:ModulePath -Force
}

Describe "BreadcrumbNavigation" -Tag 'Unit', 'Experience' {
    Context "Stack Creation" {
        It "Should create a new breadcrumb stack" {
            $stack = New-BreadcrumbStack
            
            $stack | Should -Not -BeNullOrEmpty
            $stack.PSObject.Properties['Items'] | Should -Not -BeNullOrEmpty
            $stack.Current | Should -BeNullOrEmpty
            $stack.Items.Count | Should -Be 0
        }
    }
    
    Context "Push and Pop" {
        BeforeEach {
            $script:stack = New-BreadcrumbStack
        }
        
        It "Should push a breadcrumb" {
            $result = Push-Breadcrumb -Stack $script:stack -Name "Main"
            
            $script:stack.Items.Count | Should -Be 1
            $script:stack.Current | Should -Not -BeNullOrEmpty
            $script:stack.Current.Name | Should -Be "Main"
        }
        
        It "Should push multiple breadcrumbs in order" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            Push-Breadcrumb -Stack $script:stack -Name "Unit Tests"
            
            $script:stack.Items.Count | Should -Be 3
            $script:stack.Current.Name | Should -Be "Unit Tests"
        }
        
        It "Should pop a breadcrumb" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            
            Pop-Breadcrumb -Stack $script:stack
            
            $script:stack.Items.Count | Should -Be 1
            $script:stack.Current.Name | Should -Be "Main"
        }
        
        It "Should handle popping from empty stack" {
            { Pop-Breadcrumb -Stack $script:stack } | Should -Not -Throw
            
            $script:stack.Items.Count | Should -Be 0
            $script:stack.Current | Should -BeNullOrEmpty
        }
        
        It "Should store context with breadcrumb" {
            $context = @{ Mode = 'Run'; Target = '0402' }
            Push-Breadcrumb -Stack $script:stack -Name "Run" -Context $context
            
            $script:stack.Current.Context.Mode | Should -Be 'Run'
            $script:stack.Current.Context.Target | Should -Be '0402'
        }
    }
    
    Context "Path Generation" {
        BeforeEach {
            $script:stack = New-BreadcrumbStack
        }
        
        It "Should generate path without root" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            Push-Breadcrumb -Stack $script:stack -Name "Unit Tests"
            
            $path = Get-BreadcrumbPath -Stack $script:stack
            
            $path | Should -Be "Main > Testing > Unit Tests"
        }
        
        It "Should generate path with root" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            
            $path = Get-BreadcrumbPath -Stack $script:stack -IncludeRoot
            
            $path | Should -Be "AitherZero > Main > Testing"
        }
        
        It "Should use custom separator" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            
            $path = Get-BreadcrumbPath -Stack $script:stack -Separator " / "
            
            $path | Should -Be "Main / Testing"
        }
        
        It "Should handle empty stack" {
            $path = Get-BreadcrumbPath -Stack $script:stack
            
            $path | Should -Be ""
        }
        
        It "Should handle empty stack with root" {
            $path = Get-BreadcrumbPath -Stack $script:stack -IncludeRoot
            
            $path | Should -Be "AitherZero"
        }
    }
    
    Context "Depth and Clear" {
        BeforeEach {
            $script:stack = New-BreadcrumbStack
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            Push-Breadcrumb -Stack $script:stack -Name "Unit Tests"
        }
        
        It "Should get correct depth" {
            $depth = Get-BreadcrumbDepth -Stack $script:stack
            
            $depth | Should -Be 3
        }
        
        It "Should clear all breadcrumbs" {
            Clear-BreadcrumbStack -Stack $script:stack
            
            $script:stack.Items.Count | Should -Be 0
            $script:stack.Current | Should -BeNullOrEmpty
            
            $depth = Get-BreadcrumbDepth -Stack $script:stack
            $depth | Should -Be 0
        }
    }
    
    Context "Current Breadcrumb" {
        BeforeEach {
            $script:stack = New-BreadcrumbStack
        }
        
        It "Should return null for empty stack" {
            $current = Get-CurrentBreadcrumb -Stack $script:stack
            
            $current | Should -BeNullOrEmpty
        }
        
        It "Should return current breadcrumb" {
            Push-Breadcrumb -Stack $script:stack -Name "Main"
            Push-Breadcrumb -Stack $script:stack -Name "Testing"
            
            $current = Get-CurrentBreadcrumb -Stack $script:stack
            
            $current.Name | Should -Be "Testing"
        }
    }
}
