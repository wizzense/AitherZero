# AitherZero Quick Start - Simple One-Liners

## 🚀 **Ultra-Simple Installation Commands**

### **Recommended: Bootstrap Script**
```powershell
iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1).Content
```
- ✅ **Simplest approach** - Clean, readable, maintainable
- ✅ **PowerShell 5.1+ compatible** - Works on any Windows system
- ✅ **Auto-setup** - Downloads, extracts, and runs setup automatically
- ✅ **Error handling** - Clear error messages and fallback instructions

### **Alternative: Get Script**
```powershell
iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1).Content
```
- ✅ **Compact version** - Slightly more minimal
- ✅ **Same reliability** - PowerShell 5.1+ compatible with error handling

### **For Air-Gapped/Offline Systems**
```powershell
# Download latest release manually, then extract and run:
Expand-Archive "AitherZero-*.zip" -Force
cd AitherZero*
.\quick-setup-simple.ps1 -Auto
```

## 🎯 **Use Cases**

### **Headless/Automated Deployment**
```powershell
# Silent installation without user prompts
iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1).Content
```

### **Development/Testing**
```powershell
# Install to specific directory
$installPath = "C:\Tools"; iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1).Content
```

### **Manual Download + Setup**
```powershell
# If you prefer to download the release yourself
iwr "https://github.com/wizzense/AitherZero/releases/latest/download/AitherZero-windows-standard.zip" -OutFile "az.zip"
Expand-Archive "az.zip" -Force
cd AitherZero*
.\Start-AitherZero.ps1 -Auto
```

## 🔧 **Why These Are Better**

### **Before (Complex):**
```powershell
# 😵 Unreadable monster:
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$url=(irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest").assets|?{$_.name-like"*-windows-*.zip"}|select -f 1|%{$_.browser_download_url};iwr $url -OutFile "AZ.zip";Expand-Archive "AZ.zip" -Force;$f=(gci -Directory|?{$_.Name-like"AitherZero*"})[0].Name;cd $f;if(Test-Path "quick-setup-simple.ps1"){.\quick-setup-simple.ps1 -Auto}elseif(Test-Path "Start-AitherZero.ps1"){.\Start-AitherZero.ps1 -Auto}else{.\aither.ps1 init --auto}
```

### **After (Simple):**
```powershell
# 😊 Clean and readable:
iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1).Content
```

## 📋 **Benefits of Simple Approach**

- ✅ **Readable** - Anyone can understand what it does
- ✅ **Maintainable** - Updates go in the script, not the command
- ✅ **Debuggable** - Easy to troubleshoot issues
- ✅ **Flexible** - Script can handle edge cases and improvements
- ✅ **Reliable** - Proper error handling and user feedback
- ✅ **Compatible** - Works on PowerShell 5.1+ without issues

## 🛠️ **Troubleshooting**

If the one-liner fails:
1. **Check PowerShell version**: `$PSVersionTable.PSVersion`
2. **Check internet access**: Can you reach GitHub?
3. **Manual download**: Visit https://github.com/wizzense/AitherZero/releases
4. **Run locally**: Download `bootstrap.ps1` and run it directly

## 🎉 **Result**

After running any of these commands, you'll have:
- ✅ AitherZero downloaded and extracted
- ✅ Initial setup completed automatically  
- ✅ Ready to use: `.\aither.ps1 help` or `.\Start-AitherZero.ps1`

**Perfect for:** Server deployment, lab setup, automated provisioning, or just getting started quickly!