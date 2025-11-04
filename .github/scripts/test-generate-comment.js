// Simple test for generate-test-comment.js logic
// This tests that we correctly detect test failures from step outcomes

const testModule = require('./generate-test-comment.js');

// Mock GitHub API response with steps data
const mockJobs = {
  data: {
    jobs: [
      {
        name: '🧪 Unit Tests [0000-0099]',
        conclusion: 'success', // Job conclusion is success due to continue-on-error
        status: 'completed',
        html_url: 'https://github.com/test/run/1',
        started_at: '2025-01-01T00:00:00Z',
        completed_at: '2025-01-01T00:01:00Z',
        steps: [
          {
            name: 'Run Unit Tests [0000-0099]',
            outcome: 'failure', // But the test step actually failed
            conclusion: 'failure'
          }
        ]
      },
      {
        name: '🧪 Unit Tests [0100-0199]',
        conclusion: 'success',
        status: 'completed',
        html_url: 'https://github.com/test/run/2',
        started_at: '2025-01-01T00:00:00Z',
        completed_at: '2025-01-01T00:01:00Z',
        steps: [
          {
            name: 'Run Unit Tests [0100-0199]',
            outcome: 'success', // This one actually passed
            conclusion: 'success'
          }
        ]
      },
      {
        name: '🏗️ Domain Tests [configuration]',
        conclusion: 'success',
        status: 'completed',
        html_url: 'https://github.com/test/run/3',
        started_at: '2025-01-01T00:00:00Z',
        completed_at: '2025-01-01T00:01:00Z',
        steps: [
          {
            name: 'Run Domain Tests [configuration]',
            outcome: 'failure', // Failed test
            conclusion: 'failure'
          }
        ]
      }
    ]
  }
};

// Mock context and core
const mockContext = {
  repo: { owner: 'test', repo: 'test' },
  runId: 123456,
  issue: { number: 1 },
  serverUrl: 'https://github.com'
};

const mockCore = {
  getInput: (name) => {
    const inputs = {
      'passed': '100',
      'failed': '50',
      'skipped': '5'
    };
    return inputs[name] || '';
  }
};

let commentBody = null;
const mockGithub = {
  rest: {
    actions: {
      listJobsForWorkflowRun: async () => mockJobs
    },
    issues: {
      createComment: async ({body}) => {
        commentBody = body;
        console.log('✅ Comment would be created');
      }
    }
  }
};

// Run the test
(async () => {
  console.log('🧪 Testing generate-test-comment logic...\n');
  
  try {
    await testModule({
      github: mockGithub,
      context: mockContext,
      core: mockCore
    });
    
    console.log('\n📊 Test Results:');
    console.log('================');
    
    // Check that the comment was generated
    if (!commentBody) {
      console.error('❌ FAIL: No comment body generated');
      process.exit(1);
    }
    
    // Check for failure indicators in the comment
    const hasFailureIcon = commentBody.includes('❌');
    const hasFailedStatus = commentBody.includes('**FAILED**');
    const hasWarning = commentBody.includes('⚠️ **ATTENTION: This PR has test failures');
    
    console.log(`✅ Comment generated: ${commentBody.length} characters`);
    console.log(`${hasFailureIcon ? '✅' : '❌'} Contains failure icon (❌)`);
    console.log(`${hasFailedStatus ? '✅' : '❌'} Contains FAILED status`);
    console.log(`${hasWarning ? '✅' : '❌'} Contains warning section`);
    
    // Check that we correctly identified the failed jobs by parsing comment structure
    // More robust than regex - checks actual table rows with FAILED status
    const failedJobLines = commentBody.split('\n').filter(line => 
      line.includes('**FAILED**') && line.includes('|')
    );
    const failedJobCount = failedJobLines.length;
    
    console.log(`\n📈 Failed job count in comment: ${failedJobCount}`);
    console.log(`   Expected: 2 (Unit Tests [0000-0099] and Domain Tests [configuration])`);
    
    if (failedJobCount !== 2) {
      console.error(`❌ FAIL: Expected 2 failed jobs, found ${failedJobCount}`);
      process.exit(1);
    }
    
    // Check that successful job shows as PASSED by parsing table rows
    const passedJobLines = commentBody.split('\n').filter(line =>
      line.includes('PASSED') && line.includes('|') && !line.includes('Status')
    );
    const passedJobCount = passedJobLines.length;
    
    console.log(`\n✅ Passed job count in comment: ${passedJobCount}`);
    console.log(`   Expected: At least 1 (Unit Tests [0100-0199])`);
    
    if (passedJobCount < 1) {
      console.error(`❌ FAIL: Expected at least 1 passed job, found ${passedJobCount}`);
      process.exit(1);
    }
    
    console.log('\n✅ All tests passed!');
    console.log('\n📝 Sample of generated comment:');
    console.log('================================');
    console.log(commentBody.substring(0, 500) + '...\n');
    
  } catch (error) {
    console.error('❌ Test failed with error:', error);
    process.exit(1);
  }
})();
