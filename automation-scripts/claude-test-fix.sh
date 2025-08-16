#!/bin/bash
# Claude Test Fix Runner - Automated test fixing with Claude Code
# Uses orchestration with test-fix-workflow playbook for Claude integration

set -e

echo "🤖 Claude Test Fix Runner"
echo "========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TRACKER_FILE="./test-fix-tracker.json"
TEST_RESULTS_PATH="./tests/reports"
MAX_LOOPS="${1:-10}"  # Number of issues to fix
CREATE_ISSUES="${CREATE_ISSUES:-false}"

echo -e "${BLUE}Configuration:${NC}"
echo "  Tracker: $TRACKER_FILE"
echo "  Results: $TEST_RESULTS_PATH"
echo "  Issues to Fix: $MAX_LOOPS"
echo "  Create GitHub Issues: $CREATE_ISSUES"
echo ""

# Function to check if tests are needed
check_test_results() {
    local latest_result=$(ls -t $TEST_RESULTS_PATH/TestReport-*.json 2>/dev/null | head -1)
    if [ -z "$latest_result" ]; then
        echo -e "${YELLOW}No test results found. Running tests first...${NC}"
        return 1
    fi
    
    local age_minutes=$(( ($(date +%s) - $(stat -c %Y "$latest_result" 2>/dev/null || stat -f %m "$latest_result" 2>/dev/null)) / 60 ))
    if [ $age_minutes -gt 60 ]; then
        echo -e "${YELLOW}Test results are $age_minutes minutes old. Running fresh tests...${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Using recent test results: $(basename $latest_result)${NC}"
    return 0
}

# Function to run tests if needed
run_tests_if_needed() {
    if ! check_test_results; then
        echo -e "${BLUE}Running unit tests...${NC}"
        pwsh -Command "./automation-scripts/0402_Run-UnitTests.ps1 -Path './tests/unit' -OutputPath '$TEST_RESULTS_PATH' -NoCoverage" || true
        echo -e "${GREEN}Tests completed${NC}"
        echo ""
    fi
}

# Function to initialize tracker
init_tracker() {
    if [ ! -f "$TRACKER_FILE" ] || [ "$1" == "--reset" ]; then
        echo -e "${BLUE}Initializing tracker...${NC}"
        cat > "$TRACKER_FILE" << EOF
{
  "currentIssueIndex": 0,
  "createdAt": "$(date -Iseconds)",
  "lastProcessedResults": null,
  "issues": []
}
EOF
        echo -e "${GREEN}Tracker initialized${NC}"
        
        # Process test results into tracker
        echo -e "${BLUE}Processing test results...${NC}"
        pwsh -Command "./automation-scripts/0752_Process-TestResults.ps1 -TrackerPath '$TRACKER_FILE' -TestResultsPath '$TEST_RESULTS_PATH'" 2>&1 | grep -E "(Added|Found|Total)" || true
        echo ""
    fi
}

# Function to show tracker status
show_status() {
    if [ -f "$TRACKER_FILE" ]; then
        echo -e "${CYAN}📊 Test Fix Tracker Status:${NC}"
        echo "=========================="
        
        local total=$(jq '.issues | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
        local open=$(jq '[.issues[] | select(.status == "open")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
        local resolved=$(jq '[.issues[] | select(.status == "resolved")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
        local failed=$(jq '[.issues[] | select(.status == "failed")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
        
        echo "  Total Issues: $total"
        echo -e "  ${GREEN}✅ Resolved: $resolved${NC}"
        echo -e "  ${YELLOW}⚠️  Open: $open${NC}"
        echo -e "  ${RED}❌ Failed: $failed${NC}"
        
        if [ "$open" -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Open Issues:${NC}"
            jq -r '.issues[] | select(.status == "open") | "  - [\(.id)] \(.testName)"' "$TRACKER_FILE" 2>/dev/null || true
        fi
        echo ""
    fi
}

# Parse arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --status       Show current tracker status only"
    echo "  --reset        Reset the tracker and start fresh"
    echo "  --issues       Create GitHub issues for failures"
    echo "  --loops <n>    Number of issues to fix (default: 10)"
    echo "  --run-tests    Force running fresh tests first"
    echo ""
    echo "Examples:"
    echo "  $0                 # Fix up to 10 issues"
    echo "  $0 --loops 5       # Fix up to 5 issues"
    echo "  $0 --reset         # Reset and start fresh"
    echo "  $0 --status        # Show current status"
    echo "  $0 --issues        # Create GitHub issues"
    exit 0
fi

# Check for --status flag
if [[ "$*" == *"--status"* ]]; then
    show_status
    exit 0
fi

# Check for --reset flag
if [[ "$*" == *"--reset"* ]]; then
    RESET="--reset"
fi

# Check for --issues flag
if [[ "$*" == *"--issues"* ]]; then
    CREATE_ISSUES="true"
fi

# Parse --loops parameter
if [[ "$*" =~ --loops[[:space:]]+([0-9]+) ]]; then
    MAX_LOOPS="${BASH_REMATCH[1]}"
fi

# Check for --run-tests flag
if [[ "$*" == *"--run-tests"* ]]; then
    rm -f $TEST_RESULTS_PATH/TestReport-*.json 2>/dev/null || true
fi

echo -e "${MAGENTA}🚀 Starting AitherZero Test Fix Workflow${NC}"
echo "========================================"
echo ""

# Step 1: Ensure we have test results
echo -e "${BLUE}Step 1: Test Discovery${NC}"
run_tests_if_needed

# Step 2: Initialize tracker
echo -e "${BLUE}Step 2: Initialize Tracker${NC}"
init_tracker $RESET

# Step 3: Show initial status
show_status

# Step 4: Run fix workflow for each issue
echo -e "${BLUE}Step 3: Running Test Fix Workflow${NC}"
echo "=================================="

FIXED_COUNT=0
LOOP_COUNT=0

while [ $LOOP_COUNT -lt $MAX_LOOPS ]; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    
    # Check if there are open issues
    OPEN_COUNT=$(jq '[.issues[] | select(.status == "open")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
    
    if [ "$OPEN_COUNT" -eq "0" ]; then
        echo -e "${GREEN}No more open issues to fix!${NC}"
        break
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Iteration $LOOP_COUNT of $MAX_LOOPS (Open issues: $OPEN_COUNT)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Run the test-fix-workflow playbook (processes one issue)
    echo -e "${YELLOW}🔧 Processing next issue...${NC}"
    
    # Run the orchestration playbook
    pwsh -Command "
        # Import AitherZero module
        Import-Module ./AitherZero.psd1 -Force
        
        # Run the test-fix-workflow playbook
        \$params = @{
            Mode = 'Orchestrate'
            Playbook = 'test-fix-workflow'
            NonInteractive = \$true
            Variables = @{
                TrackerFile = '$TRACKER_FILE'
                TestResultsPath = '$TEST_RESULTS_PATH'
                CreateGitHubIssues = \$$CREATE_ISSUES
                UseTaskAgent = \$true
            }
        }
        
        ./Start-AitherZero.ps1 @params
    " 2>&1 | tee /tmp/test-fix-$LOOP_COUNT.log | grep -E "(Fixed|Resolved|Failed|Validating|Committing|✅|⚠️|❌|📊)" || true
    
    # Check if a fix was made
    NEW_RESOLVED=$(jq '[.issues[] | select(.status == "resolved")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
    if [ "$NEW_RESOLVED" -gt "$FIXED_COUNT" ]; then
        FIXED_COUNT=$NEW_RESOLVED
        echo -e "${GREEN}✅ Issue fixed successfully!${NC}"
    else
        echo -e "${YELLOW}⚠️ Issue not fixed in this iteration${NC}"
    fi
    
    # Brief pause between iterations
    if [ $LOOP_COUNT -lt $MAX_LOOPS ]; then
        sleep 2
    fi
done

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 FINAL SUMMARY${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Show final status
show_status

# Provide next steps
if [ -f "$TRACKER_FILE" ]; then
    FINAL_OPEN=$(jq '[.issues[] | select(.status == "open")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
    FINAL_RESOLVED=$(jq '[.issues[] | select(.status == "resolved")] | length' "$TRACKER_FILE" 2>/dev/null || echo "0")
    
    if [ "$FINAL_RESOLVED" -gt "0" ]; then
        echo -e "${GREEN}🎉 Successfully fixed $FINAL_RESOLVED test failure(s)!${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "  1. Review changes: git diff"
        echo "  2. Run validation: ./Start-AitherZero.ps1 -Mode Test"
        echo "  3. Create PR: ./automation-scripts/0757_Create-FixPR.ps1"
    fi
    
    if [ "$FINAL_OPEN" -gt "0" ]; then
        echo ""
        echo -e "${YELLOW}⚠️ $FINAL_OPEN issue(s) still need attention${NC}"
        echo ""
        echo -e "${BLUE}Options:${NC}"
        echo "  1. Run again: $0 --loops $FINAL_OPEN"
        echo "  2. Create GitHub issues: $0 --issues"
        echo "  3. Fix manually"
    fi
    
    if [ "$FINAL_OPEN" -eq "0" ] && [ "$FINAL_RESOLVED" -gt "0" ]; then
        echo ""
        echo -e "${GREEN}🏆 All test issues have been resolved!${NC}"
    fi
fi

echo ""
echo -e "${MAGENTA}Test fix workflow complete!${NC}"