#!/bin/bash
set -e

echo "=== GitHub Actions Workflow Diagnostics ==="
echo ""

# 1. YAML Validation
echo "1. Validating YAML syntax..."
YAML_ERRORS=0
for file in .github/workflows/*.yml; do
  if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" >/dev/null 2>&1; then
    echo "  ❌ YAML ERROR: $file"
    python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | grep -E "(error|syntax)"
    YAML_ERRORS=$((YAML_ERRORS + 1))
  else
    echo "  ✓ $file"
  fi
done

if [ $YAML_ERRORS -gt 0 ]; then
  echo "  ⚠️  Found $YAML_ERRORS files with YAML errors - FIX THESE FIRST"
fi

# 2. Branch Triggers
echo ""
echo "2. Checking workflow triggers..."
for file in .github/workflows/*.yml; do
  echo "  File: $(basename $file)"
  grep -A5 "^on:" "$file" | grep -E "(branches:|pull_request:)" | head -5 | sed 's/^/    /' || echo "    No PR triggers found"
done

# 3. Common Issues
echo ""
echo "3. Checking for common issues..."

echo "  - Trailing spaces:"
TRAILING_COUNT=$(grep -n "[[:space:]]$" .github/workflows/*.yml 2>/dev/null | wc -l)
if [ $TRAILING_COUNT -eq 0 ]; then
  echo "    ✓ None found"
else
  echo "    ⚠️  Found $TRAILING_COUNT lines with trailing spaces"
  grep -n "[[:space:]]$" .github/workflows/*.yml | head -10
fi

echo "  - Long lines (>200 chars - potential YAML issues):"
LONG_LINES=$(grep -n "^.\{200\}" .github/workflows/*.yml 2>/dev/null | wc -l)
if [ $LONG_LINES -eq 0 ]; then
  echo "    ✓ None found"
else
  echo "    ⚠️  Found $LONG_LINES very long lines"
fi

echo "  - workflow_run triggers (potential loops):"
WORKFLOW_RUNS=$(grep -c "workflow_run:" .github/workflows/*.yml 2>/dev/null | grep -v ":0$" | wc -l)
if [ $WORKFLOW_RUNS -eq 0 ]; then
  echo "    ✓ None found"
else
  echo "    Found $WORKFLOW_RUNS workflows with workflow_run triggers:"
  grep -l "workflow_run:" .github/workflows/*.yml | sed 's/^/      /'
fi

# 4. Summary
echo ""
echo "=== Diagnostics Complete ==="

if [ $YAML_ERRORS -gt 0 ]; then
  echo "⚠️  ACTION REQUIRED: Fix YAML errors before proceeding"
  exit 1
else
  echo "✅ All workflow files are valid!"
  exit 0
fi
