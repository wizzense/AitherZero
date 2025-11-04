#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:EntryScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
}

Describe "Start-AitherZero PlaybookProfile Parameter" -Tag 'Unit', 'Orchestration' {

    Context "PlaybookProfile Parameter Validation" {
        
        It "Should accept 'ci' as PlaybookProfile value" {
            # This validates the fix for the workflow issue
            # The -PlaybookProfile parameter should accept any string including 'ci'
            $cmd = Get-Command $script:EntryScript
            $param = $cmd.Parameters['PlaybookProfile']
            
            # Verify parameter exists
            $param | Should -Not -BeNullOrEmpty
            
            # Verify it's a string type (no ValidateSet restriction)
            $param.ParameterType.Name | Should -Be 'String'
            
            # Verify no ValidateSet attribute
            $validateSetAttr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validateSetAttr | Should -BeNullOrEmpty
        }
        
        It "Should accept standard playbook profiles: quick, standard, full, ci" {
            $cmd = Get-Command $script:EntryScript
            $param = $cmd.Parameters['PlaybookProfile']
            
            # Should be a string parameter
            $param.ParameterType.Name | Should -Be 'String'
            
            # Should not have ValidateSet (accepts any string)
            $validateSetAttr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validateSetAttr | Should -BeNullOrEmpty
        }
        
        It "ProfileName parameter should only accept system profiles" {
            $cmd = Get-Command $script:EntryScript
            $param = $cmd.Parameters['ProfileName']
            
            # Should have ValidateSet attribute
            $validateSetAttr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validateSetAttr | Should -Not -BeNullOrEmpty
            
            # Should contain: Minimal, Standard, Developer, Full
            $validValues = $validateSetAttr.ValidValues
            $validValues | Should -Contain 'Minimal'
            $validValues | Should -Contain 'Standard'
            $validValues | Should -Contain 'Developer'
            $validValues | Should -Contain 'Full'
            
            # Should NOT contain 'ci'
            $validValues | Should -Not -Contain 'ci'
        }
        
        It "Should differentiate between ProfileName and PlaybookProfile" {
            $cmd = Get-Command $script:EntryScript
            
            # Both parameters should exist
            $cmd.Parameters.ContainsKey('ProfileName') | Should -Be $true
            $cmd.Parameters.ContainsKey('PlaybookProfile') | Should -Be $true
            
            # ProfileName should have ValidateSet
            $profileNameParam = $cmd.Parameters['ProfileName']
            $profileNameValidateSet = $profileNameParam.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $profileNameValidateSet | Should -Not -BeNullOrEmpty
            
            # PlaybookProfile should NOT have ValidateSet
            $playbookProfileParam = $cmd.Parameters['PlaybookProfile']
            $playbookProfileValidateSet = $playbookProfileParam.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $playbookProfileValidateSet | Should -BeNullOrEmpty
        }
    }
    
    Context "Help Documentation" {
        
        It "Should document ProfileName parameter (not Profile)" {
            $helpContent = Get-Help $script:EntryScript -Full
            $profileNameParam = $helpContent.parameters.parameter | Where-Object { $_.name -eq 'ProfileName' }
            
            $profileNameParam | Should -Not -BeNullOrEmpty
            $profileNameParam.description | Should -Not -BeNullOrEmpty
        }
        
        It "Should document PlaybookProfile parameter" {
            $helpContent = Get-Help $script:EntryScript -Full
            $playbookProfileParam = $helpContent.parameters.parameter | Where-Object { $_.name -eq 'PlaybookProfile' }
            
            $playbookProfileParam | Should -Not -BeNullOrEmpty
            $playbookProfileParam.description.Text | Should -Match "playbook"
        }
    }
}
