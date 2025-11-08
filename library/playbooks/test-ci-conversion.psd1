@{
    Name = "test-ci-conversion"
    Description = "Test CI parameter type conversion"
    Version = "1.0.0"
    
    Sequence = @(
        @{
            Script = "/tmp/test-ci-param.ps1"
            Description = "Test CI parameter"
        }
    )
    
    Variables = @{
        CI = "true"
        TestValue = "from-playbook"
    }
}
