# Troubleshooting Guide - Job Automation Tool

Comprehensive solutions for common issues.

## Table of Contents
1. [Installation Issues](#installation-issues)
2. [Configuration Errors](#configuration-errors)
3. [Browser & WebDriver Problems](#browser--webdriver-problems)
4. [Platform-Specific Issues](#platform-specific-issues)
5. [Performance & Timeout Issues](#performance--timeout-issues)
6. [Bot Detection & CAPTCHAs](#bot-detection--captchas)
7. [Database & Logging](#database--logging)
8. [Dashboard Issues](#dashboard-issues)

---

## Installation Issues

### Python Version Mismatch

**Symptom**: `SyntaxError` or `ModuleNotFoundError`

**Solution**:
```bash
# Check Python version (need 3.8+)
python3 --version

# Install Python 3.11 (recommended)
# Ubuntu/Debian
sudo apt update
sudo apt install python3.11

# macOS
brew install python@3.11

# Windows
# Download from python.org
```

### Dependency Installation Fails

**Symptom**: `pip install -r requirements.txt` fails

**Solution**:
```bash
# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install dependencies one by one to find the issue
pip install selenium
pip install Flask
# ... etc

# For specific errors:
# If SSL error on macOS:
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt

# If compile error (missing gcc):
# Ubuntu/Debian
sudo apt install build-essential python3-dev

# macOS
xcode-select --install
```

---

## Configuration Errors

### "Configuration validation failed"

**Symptom**: Errors like "Invalid email format" or "Missing required field"

**Solution**:
```bash
# Validate JSON syntax
python3 -c "import json; json.load(open('config.json'))"

# Common fixes:
1. Check for trailing commas:
   WRONG: "email": "test@example.com",}
   RIGHT: "email": "test@example.com"}

2. Use forward slashes in paths:
   WRONG: "C:\Users\name\resume.pdf"
   RIGHT: "C:/Users/name/resume.pdf"
   OR: "C:\\Users\\name\\resume.pdf"

3. Ensure required fields are filled:
   - personal_info.name
   - personal_info.email
   - personal_info.phone
   - personal_info.resume_path
```

### Resume File Not Found

**Symptom**: `FileNotFoundError: Resume not found`

**Solution**:
```bash
# Use absolute path, not relative
WRONG: resume_path: "resume.pdf"
RIGHT: resume_path: "/home/user/Documents/resume.pdf"

# Verify file exists
ls -l /path/to/resume.pdf

# Check file permissions
chmod 644 /path/to/resume.pdf
```

---

## Browser & WebDriver Problems

### Chrome Driver Version Mismatch

**Symptom**: `SessionNotCreatedException: Chrome version mismatch`

**Solution**:
```python
# Automatic (recommended):
# In requirements.txt, ensure:
webdriver-manager==4.0.1

# The tool auto-downloads correct driver
# Or force reinstall:
pip uninstall selenium webdriver-manager
pip install selenium==4.16.0 webdriver-manager==4.0.1
```

### Chrome Not Found

**Symptom**: `WebDriverException: chrome not reachable`

**Solution**:
```bash
# Install Chrome
# Ubuntu/Debian
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb

# macOS
brew install --cask google-chrome

# Windows
# Download from google.com/chrome

# Verify installation
google-chrome --version  # Linux/Mac
# Windows: Check Program Files
```

### "DevToolsActivePort file doesn't exist"

**Symptom**: Chrome fails to start in headless mode

**Solution**:
```json
// In config.json, add browser settings:
"browser_settings": {
  "window_size": "1920,1080",
  "disable_dev_shm_usage": true,
  "no_sandbox": true  // Only if running in Docker
}
```

Or run in non-headless mode:
```json
"automation_settings": {
  "headless_browser": false
}
```

---

## Platform-Specific Issues

### Indeed: Bot Detection

**Symptom**: "We've detected unusual activity from your computer"

**Solutions**:
1. **Increase delays**:
   ```json
   "automation_settings": {
     "delay_between_applications": 60
   }
   ```

2. **Disable headless mode**:
   ```json
   "headless_browser": false
   ```

3. **Use residential IP** (not VPN/datacenter)

4. **Limit applications per run**:
   ```json
   "max_applications_per_run": 20
   ```

### LinkedIn: Login Issues

**Symptom**: "Incorrect username or password" (but credentials are correct)

**Solutions**:
1. **Enable 2FA in config** (future feature)
2. **Use LinkedIn session cookies**:
   ```bash
   # Export cookies from browser
   # Save to cookies/linkedin_cookies.pkl
   ```

3. **Verify credentials**:
   - Try logging in manually first
   - LinkedIn may require phone verification

### Dice: Application Submission Fails

**Symptom**: Applications marked as "submitted" but never actually go through

**Solutions**:
1. **Check resume format**:
   - Dice prefers .docx over .pdf
   - Ensure resume is under 5MB

2. **Enable screenshots**:
   ```json
   "save_screenshots": true
   ```
   Review screenshots to see what's happening

3. **Check required fields**:
   - Dice requires phone number
   - Some jobs require salary expectations

---

## Performance & Timeout Issues

### Bot Hangs / Freezes

**Symptom**: Bot stops responding, no progress for 5+ minutes

**Solutions**:
1. **Check current URL in debug mode**:
   ```bash
   python3 main.py --debug
   ```

2. **Review screenshots**:
   ```bash
   ls -lt data/screenshots/ | head -5
   ```

3. **Reduce timeout**:
   ```json
   "automation_settings": {
     "timeout_per_application": 120,  // Reduce from 180
     "timeout_per_platform": 300  // Reduce from 600
   }
   ```

4. **Check for CAPTCHA**:
   - Bot may be waiting for manual CAPTCHA solve
   - Look for browser window showing CAPTCHA

### Slow Performance

**Symptom**: Takes 30+ minutes to apply to 10 jobs

**Solutions**:
1. **Disable screenshots** (for non-errors):
   ```json
   "screenshot_on_error_only": true
   ```

2. **Reduce delays** (cautiously):
   ```json
   "delay_between_applications": 20  // From 30
   ```

3. **Enable headless mode**:
   ```json
   "headless_browser": true
   ```

4. **Disable image loading**:
   ```json
   "browser_settings": {
     "disable_images": true
   }
   ```

### Memory Leaks

**Symptom**: RAM usage grows over time, system becomes sluggish

**Solutions**:
1. **Restart browser between platforms**:
   - Already implemented in `browser_manager.py`

2. **Limit applications per run**:
   ```json
   "max_applications_per_run": 50
   ```

3. **Clear cookies periodically**:
   ```json
   "browser_settings": {
     "clear_cookies_on_start": true
   }
   ```

---

## Bot Detection & CAPTCHAs

### Frequent CAPTCHA Challenges

**Symptom**: CAPTCHA on every 3-5 applications

**Solutions**:
1. **Slow down**:
   ```json
   "delay_between_applications": 60
   ```

2. **Use better user agent**:
   ```json
   "browser_settings": {
     "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
   }
   ```

3. **Randomize behavior more**:
   - Already implemented in `browser_manager.py` with random delays

4. **Use CAPTCHA solving service**:
   ```json
   "captcha_settings": {
     "enabled": true,
     "service": "anticaptcha",
     "api_key": "your_key_here"
   }
   ```

### "Access Denied" / IP Banned

**Symptom**: Websites show 403 Forbidden or Access Denied

**Solutions**:
1. **Wait 24 hours** (temporary ban)

2. **Change IP address**:
   - Restart router
   - Use mobile hotspot
   - Use residential proxy

3. **Clear all cookies and cache**:
   ```bash
   rm -rf cookies/
   ```

4. **Don't use VPN/datacenter IPs**

---

## Database & Logging

### Database Locked

**Symptom**: `sqlite3.OperationalError: database is locked`

**Solutions**:
```bash
# Close all connections
pkill -f "python3 main.py"

# Check if database is open
lsof data/applications.db

# Reset database (WARNING: Deletes all data)
rm data/applications.db
# Tool will recreate on next run
```

### Logs Not Saving

**Symptom**: No log files in `data/logs/`

**Solutions**:
```bash
# Create directory manually
mkdir -p data/logs

# Check permissions
chmod 755 data/logs

# Verify log level
# In config.json:
"logging": {
  "level": "INFO",  // Not "NONE" or empty
  "file_level": "DEBUG"
}
```

---

## Dashboard Issues

### Dashboard Won't Start

**Symptom**: `python3 dashboard/app.py` fails

**Solutions**:
```bash
# Check if port 5000 is in use
lsof -i :5000

# Kill existing process
kill -9 <PID>

# Or use different port
DASHBOARD_PORT=5001 python3 dashboard/app.py
```

### Dashboard Shows No Data

**Symptom**: Dashboard loads but shows 0 applications

**Solutions**:
1. **Run bot first**:
   ```bash
   python3 main.py
   # Then start dashboard
   ```

2. **Check data files**:
   ```bash
   ls -lh data/*.json
   cat data/applications.json  # Should have data
   ```

3. **Clear browser cache**:
   - Hard refresh: Ctrl+Shift+R (Chrome)

---

## Advanced Debugging

### Enable Maximum Logging

```bash
# Run with debug flags
python3 main.py --debug --verbose

# Set environment variable
export LOG_LEVEL=DEBUG
python3 main.py

# Check all logs
tail -f data/logs/job_bot.log
```

### Capture Network Traffic

```bash
# Use browser DevTools
# In browser_manager.py, add:
options.add_argument('--auto-open-devtools-for-tabs')
```

### Inspect Database

```bash
# Install SQLite browser
sudo apt install sqlitebrowser

# Open database
sqlitebrowser data/applications.db

# Or command line:
sqlite3 data/applications.db
sqlite> SELECT * FROM applications LIMIT 10;
```

---

## Getting More Help

If issue persists:

1. **Check logs**:
   ```bash
   grep ERROR data/logs/job_bot.log
   ```

2. **Review screenshots**:
   ```bash
   ls -lt data/screenshots/error_*.png
   ```

3. **Create GitHub issue** with:
   - Error message
   - Log excerpt
   - Screenshot (if applicable)
   - Platform name
   - OS and Python version

4. **Community support**:
   - GitHub Discussions
   - Discord server (link in README)

---

## Preventive Measures

**Best practices to avoid issues**:

1. ✅ Start with conservative settings
2. ✅ Test with one platform first
3. ✅ Enable screenshots for debugging
4. ✅ Monitor dashboard regularly
5. ✅ Keep tools updated (`pip install --upgrade`)
6. ✅ Review logs after each run
7. ✅ Don't run 24/7 (schedule specific times)
8. ✅ Respect platform rate limits
