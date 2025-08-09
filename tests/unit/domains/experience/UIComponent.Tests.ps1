#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ComponentPath = Join-Path $script:ProjectRoot "domains/experience/Core/UIComponent.psm1"
    $script:TestFramework = Join-Path $PSScriptRoot "UITestFramework.psm1"
    
    Import-Module $script:TestFramework -Force
    
    if (Test-Path $script:ComponentPath) {
        Import-Module $script:ComponentPath -Force
    }
}

Describe "UIComponent Base Class" {
    Context "Component Creation" {
        It "Should create a basic component with default properties" {
            $component = New-UIComponent -Name "TestComponent"
            
            $component | Should -Not -BeNullOrEmpty
            $component.Name | Should -Be "TestComponent"
            $component.Id | Should -Not -BeNullOrEmpty
            $component.IsVisible | Should -Be $true
            $component.IsEnabled | Should -Be $true
            $component.Parent | Should -BeNullOrEmpty
            $component.Children | Should -HaveCount 0
        }
        
        It "Should support custom properties" {
            $component = New-UIComponent -Name "Custom" -Properties @{
                BackgroundColor = "Blue"
                Text = "Hello"
                CustomProp = 42
            }
            
            $component.Properties.BackgroundColor | Should -Be "Blue"
            $component.Properties.Text | Should -Be "Hello"
            $component.Properties.CustomProp | Should -Be 42
        }
        
        It "Should have position and size properties" {
            $component = New-UIComponent -Name "Sized" -X 10 -Y 20 -Width 100 -Height 50
            
            $component.X | Should -Be 10
            $component.Y | Should -Be 20
            $component.Width | Should -Be 100
            $component.Height | Should -Be 50
        }
    }
    
    Context "Component Lifecycle" {
        It "Should initialize component" {
            $component = New-UIComponent -Name "Test"
            $context = New-UITestContext
            
            Initialize-UIComponent -Component $component -Context $context
            
            $component.State | Should -Be "Initialized"
            $context.Events | Should -Contain "Test:Initialize"
        }
        
        It "Should handle component mounting" {
            $component = New-UIComponent -Name "Test"
            $context = New-UITestContext
            
            Mount-UIComponent -Component $component -Context $context
            
            $component.State | Should -Be "Mounted"
            $component.Context | Should -Be $context
        }
        
        It "Should handle component unmounting" {
            $component = New-UIComponent -Name "Test"
            $context = New-UITestContext
            
            Mount-UIComponent -Component $component -Context $context
            Unmount-UIComponent -Component $component
            
            $component.State | Should -Be "Unmounted"
            $component.Context | Should -BeNullOrEmpty
        }
        
        It "Should trigger lifecycle events" {
            $component = New-UIComponent -Name "Test"
            $context = New-UITestContext
            $events = @()
            
            # Register lifecycle handlers
            $component.OnInitialize = { $events += "init" }
            $component.OnMount = { $events += "mount" }
            $component.OnRender = { $events += "render" }
            $component.OnUnmount = { $events += "unmount" }
            
            Initialize-UIComponent -Component $component -Context $context
            Mount-UIComponent -Component $component -Context $context
            Invoke-UIComponentRender -Component $component
            Unmount-UIComponent -Component $component
            
            $events | Should -Be @("init", "mount", "render", "unmount")
        }
    }
    
    Context "Component Hierarchy" {
        It "Should add child components" {
            $parent = New-UIComponent -Name "Parent"
            $child1 = New-UIComponent -Name "Child1"
            $child2 = New-UIComponent -Name "Child2"
            
            Add-UIComponentChild -Parent $parent -Child $child1
            Add-UIComponentChild -Parent $parent -Child $child2
            
            $parent.Children | Should -HaveCount 2
            $parent.Children[0].Name | Should -Be "Child1"
            $parent.Children[1].Name | Should -Be "Child2"
            
            $child1.Parent | Should -Be $parent
            $child2.Parent | Should -Be $parent
        }
        
        It "Should remove child components" {
            $parent = New-UIComponent -Name "Parent"
            $child = New-UIComponent -Name "Child"
            
            Add-UIComponentChild -Parent $parent -Child $child
            Remove-UIComponentChild -Parent $parent -Child $child
            
            $parent.Children | Should -HaveCount 0
            $child.Parent | Should -BeNullOrEmpty
        }
        
        It "Should find components by ID" {
            $root = New-UIComponent -Name "Root"
            $child1 = New-UIComponent -Name "Child1" -Id "child1"
            $child2 = New-UIComponent -Name "Child2" -Id "child2"
            $grandchild = New-UIComponent -Name "GrandChild" -Id "grandchild"
            
            Add-UIComponentChild -Parent $root -Child $child1
            Add-UIComponentChild -Parent $root -Child $child2
            Add-UIComponentChild -Parent $child1 -Child $grandchild
            
            $found = Find-UIComponent -Root $root -Id "grandchild"
            $found | Should -Not -BeNullOrEmpty
            $found.Name | Should -Be "GrandChild"
        }
        
        It "Should traverse component tree" {
            $root = New-UIComponent -Name "Root"
            $child1 = New-UIComponent -Name "Child1"
            $child2 = New-UIComponent -Name "Child2"
            $grandchild = New-UIComponent -Name "GrandChild"
            
            Add-UIComponentChild -Parent $root -Child $child1
            Add-UIComponentChild -Parent $root -Child $child2
            Add-UIComponentChild -Parent $child1 -Child $grandchild
            
            $names = @()
            Invoke-UIComponentTraversal -Root $root -Action {
                param($component)
                $names += $component.Name
            }
            
            $names | Should -Be @("Root", "Child1", "GrandChild", "Child2")
        }
    }
    
    Context "Component Rendering" {
        It "Should render component to terminal" {
            $component = New-UIComponent -Name "Text" -Properties @{ Text = "Hello World" }
            $component.X = 5
            $component.Y = 2
            
            $context = New-UITestContext
            Mount-UIComponent -Component $component -Context $context
            Invoke-UIComponentRender -Component $component
            
            $line = Get-MockTerminalLine -Terminal $context.Terminal -Line 2
            $line | Should -Match "Hello World"
        }
        
        It "Should respect visibility flag" {
            $component = New-UIComponent -Name "Hidden"
            $component.IsVisible = $false
            
            $context = New-UITestContext
            Mount-UIComponent -Component $component -Context $context
            Invoke-UIComponentRender -Component $component
            
            # Component should not render anything when not visible
            $context.Events | Should -Not -Contain "Hidden:Render"
        }
        
        It "Should render child components" {
            $parent = New-UIComponent -Name "Container" -X 0 -Y 0
            $child = New-UIComponent -Name "Child" -X 5 -Y 5 -Properties @{ Text = "Child" }
            
            Add-UIComponentChild -Parent $parent -Child $child
            
            $context = New-UITestContext
            Mount-UIComponent -Component $parent -Context $context
            Invoke-UIComponentRender -Component $parent -RenderChildren
            
            $line = Get-MockTerminalLine -Terminal $context.Terminal -Line 5
            $line | Should -Match "Child"
        }
        
        It "Should clear component area before rendering" {
            $component = New-UIComponent -Name "Text" -X 0 -Y 0 -Width 20 -Height 1
            $component.Properties.Text = "New Text"
            
            $context = New-UITestContext
            Write-MockTerminal -Terminal $context.Terminal -Text "Old Text Here" -X 0 -Y 0
            
            Mount-UIComponent -Component $component -Context $context
            Invoke-UIComponentRender -Component $component -Clear
            
            $line = Get-MockTerminalLine -Terminal $context.Terminal -Line 0
            $line.Substring(0, 20).Trim() | Should -Be "New Text"
        }
    }
    
    Context "Component Events" {
        It "Should handle focus events" {
            $component = New-UIComponent -Name "Focusable"
            $context = New-UITestContext
            
            Set-UIComponentFocus -Component $component -Context $context
            $component.HasFocus | Should -Be $true
            $context.Events | Should -Contain "Focusable:Focus"
            
            Remove-UIComponentFocus -Component $component -Context $context
            $component.HasFocus | Should -Be $false
            $context.Events | Should -Contain "Focusable:Blur"
        }
        
        It "Should handle input events" {
            $component = New-UIComponent -Name "Input"
            $context = New-UITestContext
            $handled = $false
            
            $component.OnKeyPress = {
                param($key)
                if ($key.Key -eq "Enter") {
                    $handled = $true
                }
            }
            
            Add-MockKeyPress -Keyboard $context.Keyboard -Key "Enter"
            Invoke-UIComponentInput -Component $component -Context $context
            
            $handled | Should -Be $true
        }
        
        It "Should bubble events to parent" {
            $parent = New-UIComponent -Name "Parent"
            $child = New-UIComponent -Name "Child"
            $context = New-UITestContext
            
            Add-UIComponentChild -Parent $parent -Child $child
            
            $parentReceived = $false
            $parent.OnChildEvent = {
                param($child, $event)
                $parentReceived = $true
            }
            
            Invoke-UIComponentEvent -Component $child -EventName "Click" -Bubble
            
            $parentReceived | Should -Be $true
        }
        
        It "Should support custom event handlers" {
            $component = New-UIComponent -Name "Custom"
            $eventData = $null
            
            Register-UIComponentHandler -Component $component -EventName "CustomEvent" -Handler {
                param($sender, $args)
                $eventData = $args
            }
            
            Invoke-UIComponentEvent -Component $component -EventName "CustomEvent" -Data @{ Value = 42 }
            
            $eventData.Value | Should -Be 42
        }
    }
    
    Context "Component State Management" {
        It "Should manage component state" {
            $component = New-UIComponent -Name "Stateful"
            
            Set-UIComponentState -Component $component -State @{
                Counter = 0
                Text = "Initial"
            }
            
            $component.ComponentState.Counter | Should -Be 0
            $component.ComponentState.Text | Should -Be "Initial"
        }
        
        It "Should trigger re-render on state change" {
            $component = New-UIComponent -Name "Stateful"
            $context = New-UITestContext
            $renderCount = 0
            
            $component.OnRender = { $renderCount++ }
            
            Mount-UIComponent -Component $component -Context $context
            Set-UIComponentState -Component $component -State @{ Counter = 1 }
            Set-UIComponentState -Component $component -State @{ Counter = 2 }
            
            $renderCount | Should -Be 2
        }
        
        It "Should batch state updates" {
            $component = New-UIComponent -Name "Batched"
            $context = New-UITestContext
            $renderCount = 0
            
            $component.OnRender = { $renderCount++ }
            Mount-UIComponent -Component $component -Context $context
            
            Start-UIComponentBatch -Component $component
            Set-UIComponentState -Component $component -State @{ A = 1 }
            Set-UIComponentState -Component $component -State @{ B = 2 }
            Set-UIComponentState -Component $component -State @{ C = 3 }
            Complete-UIComponentBatch -Component $component
            
            # Should only render once after batch completes
            $renderCount | Should -Be 1
        }
    }
    
    Context "Component Styling" {
        It "Should apply component styles" {
            $component = New-UIComponent -Name "Styled"
            
            Set-UIComponentStyle -Component $component -Style @{
                ForegroundColor = "Red"
                BackgroundColor = "Blue"
                Border = "Double"
            }
            
            $component.Style.ForegroundColor | Should -Be "Red"
            $component.Style.BackgroundColor | Should -Be "Blue"
            $component.Style.Border | Should -Be "Double"
        }
        
        It "Should inherit parent styles" {
            $parent = New-UIComponent -Name "Parent"
            $child = New-UIComponent -Name "Child"
            
            Set-UIComponentStyle -Component $parent -Style @{
                ForegroundColor = "Green"
                FontSize = 14
            }
            
            Add-UIComponentChild -Parent $parent -Child $child
            $childStyle = Get-UIComponentComputedStyle -Component $child
            
            $childStyle.ForegroundColor | Should -Be "Green"
            $childStyle.FontSize | Should -Be 14
        }
        
        It "Should override inherited styles" {
            $parent = New-UIComponent -Name "Parent"
            $child = New-UIComponent -Name "Child"
            
            Set-UIComponentStyle -Component $parent -Style @{ ForegroundColor = "Green" }
            Set-UIComponentStyle -Component $child -Style @{ ForegroundColor = "Red" }
            
            Add-UIComponentChild -Parent $parent -Child $child
            $childStyle = Get-UIComponentComputedStyle -Component $child
            
            $childStyle.ForegroundColor | Should -Be "Red"
        }
    }
}