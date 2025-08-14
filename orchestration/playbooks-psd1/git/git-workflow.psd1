#Requires -Version 7.0
<#
.SYNOPSIS
    git-workflow - Standard Git workflow automation
.DESCRIPTION
    Automates common Git workflows including branch creation, commits,
    pull requests, and merge operations following best practices.
.NOTES
    Version: 2.0.0
    Author: AitherZero DevOps Team
#>

@{
    # Metadata
    Name = 'git-workflow'
    Description = 'Standard Git workflow with branch, commit, and PR automation'
    Version = '2.0.0'
    Author = 'AitherZero DevOps Team'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('git', 'workflow', 'automation', 'devops', 'version-control')
    Category = 'Git'
    
    # Requirements
    Requirements = @{
        MinimumVersion = '7.0'
        EstimatedDuration = '2-5 minutes'
        Tools = @('git', 'gh')
    }
    
    # Default Variables
    Variables = @{
        BranchType = 'feature'
        CommitType = 'feat'
        RunTests = $true
        CreatePR = $false
        ConventionalCommits = $true
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Repository Check'
            Description = 'Verify Git repository status'
            Sequence = @('0700')  # Git status check
            ContinueOnError = $false
            Variables = @{
                CheckClean = $true
                FetchRemote = $true
            }
        }
        @{
            Name = 'Create Branch'
            Description = 'Create and checkout feature branch'
            Sequence = @('0701')
            ContinueOnError = $false
            Variables = @{
                Type = '{BranchType}'
                BaseBranch = 'main'
            }
            Conditional = @{
                When = 'Variables.CreateBranch -eq $true'
            }
        }
        @{
            Name = 'Run Tests'
            Description = 'Execute tests before commit'
            Sequence = @('0402')  # Quick tests
            ContinueOnError = $false
            Variables = @{
                NoCoverage = $true
            }
            Conditional = @{
                When = 'Variables.RunTests -eq $true'
            }
        }
        @{
            Name = 'Stage Changes'
            Description = 'Stage modified files for commit'
            Sequence = @('0702')
            ContinueOnError = $false
            Variables = @{
                StageAll = $false
                Interactive = $true
            }
        }
        @{
            Name = 'Create Commit'
            Description = 'Create commit with conventional message'
            Sequence = @('0702')
            ContinueOnError = $false
            Variables = @{
                Type = '{CommitType}'
                ConventionalCommit = '{ConventionalCommits}'
                SignCommit = $true
            }
        }
        @{
            Name = 'Push Changes'
            Description = 'Push changes to remote repository'
            Sequence = @('0703')
            ContinueOnError = $false
            Variables = @{
                SetUpstream = $true
                Force = $false
            }
        }
        @{
            Name = 'Create Pull Request'
            Description = 'Create PR for review'
            Sequence = @('0703')
            ContinueOnError = $true
            Variables = @{
                Draft = $false
                Reviewers = @()
                Labels = @('review-needed')
            }
            Conditional = @{
                When = 'Variables.CreatePR -eq $true'
            }
        }
    )
    
    # Workflow Templates
    Templates = @{
        Feature = @{
            Description = 'Feature development workflow'
            Variables = @{
                BranchType = 'feature'
                CommitType = 'feat'
                RunTests = $true
                CreatePR = $true
            }
        }
        Bugfix = @{
            Description = 'Bug fix workflow'
            Variables = @{
                BranchType = 'bugfix'
                CommitType = 'fix'
                RunTests = $true
                CreatePR = $true
            }
        }
        Hotfix = @{
            Description = 'Emergency hotfix workflow'
            Variables = @{
                BranchType = 'hotfix'
                CommitType = 'fix'
                RunTests = $false  # Skip for emergency
                CreatePR = $true
                FastTrack = $true
            }
        }
        Release = @{
            Description = 'Release preparation workflow'
            Variables = @{
                BranchType = 'release'
                CommitType = 'chore'
                RunTests = $true
                CreatePR = $true
                UpdateVersion = $true
            }
        }
    }
    
    # Commit Types (Conventional Commits)
    CommitTypes = @{
        feat = 'A new feature'
        fix = 'A bug fix'
        docs = 'Documentation only changes'
        style = 'Formatting, missing semi-colons, etc'
        refactor = 'Code change that neither fixes a bug nor adds a feature'
        perf = 'Code change that improves performance'
        test = 'Adding missing tests'
        chore = 'Changes to build process or auxiliary tools'
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ Git workflow completed successfully'
            Level = 'Success'
        }
        OnPRCreated = @{
            Message = '🔗 Pull request created: {PRUrl}'
            Level = 'Information'
        }
        OnConflict = @{
            Message = '⚠️ Merge conflicts detected - manual resolution required'
            Level = 'Warning'
        }
    }
    
    # Hooks
    Hooks = @{
        PreCommit = @{
            Enabled = $true
            Scripts = @('0404', '0407')  # Linting and syntax check
        }
        PostCommit = @{
            Enabled = $false
            Scripts = @()
        }
    }
}