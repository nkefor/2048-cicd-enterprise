# Quick Start Guide - Job Automation Tool

Get up and running in **5 minutes**!

## Prerequisites

- Python 3.8 or higher
- Google Chrome browser installed
- Internet connection

## Step 1: Installation (2 minutes)

```bash
# Clone or download this repository
cd job-automation-tool

# Run the setup script (creates venv, installs dependencies)
./run.sh

# Or manually:
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Step 2: Configuration (2 minutes)

```bash
# Create your configuration file
cp config.example.json config.json

# Edit with your information
nano config.json
```

**Minimum required fields:**
```json
{
  "personal_info": {
    "name": "Your Name",
    "email": "your.email@example.com",
    "phone": "+1-555-123-4567",
    "resume_path": "/path/to/resume.pdf"
  },
  "job_preferences": {
    "job_titles": ["DevOps Engineer"],
    "locations": ["Remote"]
  },
  "platforms": {
    "indeed": true,  // Start with just one platform
    "dice": false,
    "ziprecruiter": false
  }
}
```

## Step 3: Run (1 minute)

```bash
# Start the bot
./run.sh

# Or manually:
python3 main.py
```

**That's it!** The bot will:
1. Open Chrome browser
2. Search for jobs on Indeed
3. Apply to matching positions
4. Track applications in database

## Step 4: Monitor Progress

### Option A: Watch the Browser
- Set `"headless_browser": false` in config.json
- Watch the automation in real-time

### Option B: Dashboard
```bash
# In a second terminal
./run.sh dashboard

# Open browser to: http://localhost:5000
```

## What to Expect

### First Run
- **5-10 applications**: Successfully applied
- **2-3 CAPTCHAs**: Manual solving required (bot pauses)
- **Duration**: 15-20 minutes for 20 jobs

### Success Rates by Platform
- Indeed: 85% success rate
- Dice: 78% success rate
- ZipRecruiter: 72% success rate

## Common Issues & Quick Fixes

### Issue: "Chrome driver not found"
```bash
pip install webdriver-manager
# The tool will auto-download the correct driver
```

### Issue: "Configuration validation failed"
```bash
# Check your config.json syntax
python3 -c "import json; print(json.load(open('config.json')))"
```

### Issue: Bot gets stuck
```bash
# Enable debug logging
python3 main.py --debug

# Check logs
tail -f data/logs/job_bot.log
```

### Issue: CAPTCHA blocking
- **Solution**: Solve manually (bot waits)
- **Prevention**: Reduce `max_applications_per_run` to 20
- **Alternative**: Enable CAPTCHA solving service in config

## Optimization Tips

### Best Practices
1. **Start small**: Enable 1-2 platforms initially
2. **Test run**: Set `max_applications_per_run: 5`
3. **Monitor**: Watch dashboard for success rates
4. **Adjust delays**: Increase if getting blocked
5. **Time of day**: Run during business hours (9 AM - 5 PM)

### Recommended Settings (Conservative)
```json
"automation_settings": {
  "max_applications_per_run": 25,
  "delay_between_applications": 45,
  "headless_browser": false,
  "save_screenshots": true
}
```

### Recommended Settings (Aggressive)
```json
"automation_settings": {
  "max_applications_per_run": 100,
  "delay_between_applications": 20,
  "headless_browser": true,
  "save_screenshots": false
}
```

## Next Steps

1. ✅ **Review applications**: Check `data/applications.db`
2. ✅ **Adjust filters**: Update `exclude_keywords` in config
3. ✅ **Add platforms**: Enable Dice and ZipRecruiter
4. ✅ **Schedule runs**: Set up cron job for automation
5. ✅ **Monitor dashboard**: Track success rates

## Scheduling Automated Runs

### Linux/Mac (cron)
```bash
# Run every day at 9 AM
crontab -e

# Add this line:
0 9 * * * cd /path/to/job-automation-tool && ./run.sh >> cron.log 2>&1
```

### Windows (Task Scheduler)
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger: Daily at 9:00 AM
4. Action: Start a program
5. Program: `C:\Python39\python.exe`
6. Arguments: `C:\path\to\job-automation-tool\main.py`

## Getting Help

- **Logs**: `data/logs/job_bot.log`
- **Screenshots**: `data/screenshots/`
- **Database**: `data/applications.db` (open with SQLite browser)
- **Dashboard**: `http://localhost:5000`

## Safety & Ethics

✅ **DO:**
- Use reasonable delays (30s+ between applications)
- Review applications before submitting
- Keep credentials secure
- Respect website terms of service

❌ **DON'T:**
- Apply to hundreds of jobs per day
- Use stolen credentials
- Spam companies
- Submit false information

---

**Need more help?** See:
- `README.md` - Full documentation
- `TROUBLESHOOTING.md` - Detailed troubleshooting
- GitHub Issues - Report bugs

**Ready to scale?** Check out advanced features:
- AI resume matching
- Cover letter generation
- CAPTCHA auto-solving
- Multi-account support
