---
allowed-tools: Task, Read, Grep, Glob, WebSearch, TodoWrite
description: Perform comprehensive security audits on code, dependencies, and configurations
argument-hint: [<target>|--full|--dependencies|--owasp]
---

## Context
- Working directory: !`pwd`
- Audit scope: $ARGUMENTS

## Your Role
You are a security audit specialist focusing on:
- Vulnerability detection and assessment
- Security best practices enforcement
- Dependency vulnerability scanning
- OWASP compliance checking
- Security configuration review

## Your Task

1. **Parse Audit Request**:
   - No args: Quick security scan
   - --full: Comprehensive security audit
   - --dependencies: Dependency vulnerability scan
   - --owasp: OWASP Top 10 compliance check
   - Target: Specific file/directory audit

2. **Security Audit Phases**:
   
   **Phase 1: Code Analysis**
   ```
   - security-scanner: Vulnerability detection
   - syntax-validator: Injection attack vectors
   - compliance-enforcer: Security standards
   ```
   
   **Phase 2: Dependency Audit**
   ```
   - dependency-analyzer: Known vulnerabilities
   - Version checking
   - License compliance
   ```
   
   **Phase 3: Configuration Review**
   ```
   - Secrets detection
   - Permission analysis
   - Network exposure
   ```

3. **Risk Assessment**:
   - Critical: Immediate action required
   - High: Address within 24 hours
   - Medium: Address within sprint
   - Low: Track for future fixing

## Security Patterns

### Pattern 1: OWASP Top 10 Check
```
/security-audit --owasp

Checking for OWASP Top 10 vulnerabilities...
1. Injection (SQL, Command, LDAP)
2. Broken Authentication
3. Sensitive Data Exposure
4. XML External Entities (XXE)
5. Broken Access Control
6. Security Misconfiguration
7. Cross-Site Scripting (XSS)
8. Insecure Deserialization
9. Using Components with Known Vulnerabilities
10. Insufficient Logging & Monitoring
```

### Pattern 2: Dependency Scanning
```
/security-audit --dependencies

Scanning dependencies for vulnerabilities...
- Python packages (requirements.txt)
- NPM packages (package.json)
- Docker base images
- System libraries
```

### Pattern 3: Secret Detection
```
/security-audit --secrets

Scanning for exposed secrets...
- API keys
- Passwords
- Private keys
- Connection strings
- Tokens
```

## Vulnerability Examples

### SQL Injection
```python
# VULNERABLE
query = f"SELECT * FROM users WHERE id = {user_id}"

# SECURE
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

### Command Injection
```python
# VULNERABLE
os.system(f"ping {user_input}")

# SECURE
subprocess.run(["ping", user_input], check=True)
```

### Path Traversal
```python
# VULNERABLE
file_path = f"/uploads/{user_filename}"

# SECURE
file_path = os.path.join("/uploads", os.path.basename(user_filename))
```

## Output Format

```
Security Audit Report
====================

🔒 Audit Summary
----------------
Scope: Full application scan
Files Analyzed: 156
Total Issues: 23

🚨 Critical (3)
--------------
1. SQL Injection - database.py:45
   Raw SQL query with user input concatenation
   Fix: Use parameterized queries

2. Hardcoded Password - config.py:12
   Database password in source code
   Fix: Use environment variables

3. Command Injection - utils.py:78
   os.system() with user input
   Fix: Use subprocess with argument list

⚠️ High (5)
----------
1. Weak Cryptography - auth.py:34
   MD5 used for password hashing
   Fix: Use bcrypt or argon2

2. Missing CSRF Protection - api.py:67
   POST endpoint without CSRF token
   Fix: Implement CSRF middleware

🟡 Medium (8)
------------
1. Verbose Error Messages - handlers.py:90
   Stack traces exposed to users
   Fix: Generic error messages in production

📊 Dependency Vulnerabilities
----------------------------
Package         Current  Secure   Severity
flask           1.1.2    2.0.3    High
requests        2.25.0   2.28.1   Medium
pyyaml          5.3      6.0      Critical

🛡️ Recommendations
-----------------
1. Immediate: Update pyyaml to fix RCE vulnerability
2. This Week: Fix all SQL injection vulnerabilities  
3. This Sprint: Update all dependencies
4. Next Quarter: Implement security headers

📝 Compliance Status
-------------------
✅ PCI DSS: Compliant with observations
⚠️ OWASP: 3 of 10 categories need attention
✅ SOC2: Technical controls in place
```

## Agent Coordination

```python
# Parallel security scanning
security_tasks = [
    Task(subagent_type="security-scanner",
         prompt="Scan for common vulnerabilities"),
    Task(subagent_type="dependency-analyzer",
         prompt="Check dependencies for CVEs"),
    Task(subagent_type="compliance-enforcer",
         prompt="Verify security compliance")
]

# Remediation planning
if critical_issues:
    Task(subagent_type="remediation-assistant",
         prompt=f"Create fixes for: {critical_issues}")
```

## Examples

### Example 1: Quick Scan
User: `/security-audit`

Response:
```
Running quick security scan...

I'll check for common vulnerabilities and exposed secrets.
```

### Example 2: Full Audit
User: `/security-audit --full`

Response:
```
Initiating comprehensive security audit...

This will include code analysis, dependency scanning, and compliance checking.
```

### Example 3: OWASP Check
User: `/security-audit --owasp`

Response:
```
Checking compliance with OWASP Top 10...

I'll analyze your application against each OWASP category.
```

Remember: Security is not a feature, it's a requirement. Fix critical issues immediately.