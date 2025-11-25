# Configuration Management System

A robust configuration management system that uses environment variables to generate configuration files with proper variable substitution.

## Overview

This system demonstrates best practices for managing configuration files that contain environment-specific or sensitive data:

- **Template-based configuration**: Use `config.template.json` with placeholders
- **Environment variable substitution**: Replace `${VARIABLE_NAME}` with actual values
- **Security-first**: Never commit sensitive data (`.env` and `config.json` are gitignored)
- **Automated generation**: Use scripts to generate configuration files
- **Validation**: Verify all required variables are set before generation

## Architecture

```
┌─────────────────────┐
│  .env.example       │  ← Template with example values
│  (committed)        │
└──────────┬──────────┘
           │ copy & edit
           ▼
┌─────────────────────┐
│  .env               │  ← Your actual values
│  (gitignored)       │
└──────────┬──────────┘
           │ source
           ▼
┌─────────────────────┐       ┌─────────────────────┐
│  Environment        │       │ config.template.json│
│  Variables          │───────│ (committed)         │
└─────────────────────┘       └──────────┬──────────┘
                                         │
                              generate-config.sh
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  config.json        │
                              │  (gitignored)       │
                              └─────────────────────┘
```

## Quick Start

### 1. Set Up Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit with your actual values
nano .env  # or use your preferred editor
```

### 2. Generate Configuration

```bash
# Generate config.json from template
./scripts/generate-config.sh

# Or validate variables without generating
./scripts/generate-config.sh --validate-only
```

### 3. Verify Configuration

```bash
# Check the generated file (sensitive data will be masked in output)
cat config.json

# Or use jq for pretty printing
jq . config.json
```

## File Structure

```
2048-cicd-enterprise/
├── .env.example                    # Template with example values (committed)
├── .env                            # Your actual values (gitignored)
├── config.template.json            # Configuration template (committed)
├── config.json                     # Generated configuration (gitignored)
├── .gitignore                      # Excludes sensitive files
└── scripts/
    ├── generate-config.sh          # Configuration generation script
    └── validate-env.sh             # Standalone validation script
```

## Required Environment Variables

The following variables must be set in your `.env` file or system environment:

### Personal Information
- `PERSONAL_NAME` - Your full name
- `PERSONAL_EMAIL` - Your email address
- `PERSONAL_PHONE` - Your phone number
- `LINKEDIN_EMAIL` - LinkedIn account email
- `LINKEDIN_PASSWORD` - LinkedIn password (keep secure!)
- `RESUME_PATH` - Path to resume file
- `COVER_LETTER_PATH` - Path to cover letter file

### Job Preferences
- `SALARY_MIN` - Minimum salary (numeric only)

### Automation Settings
- `MAX_APPLICATIONS_PER_RUN` - Maximum applications per run (numeric)
- `DELAY_BETWEEN_APPLICATIONS` - Delay in seconds (numeric)
- `HEADLESS_BROWSER` - Run browser headless (true/false)
- `SAVE_SCREENSHOTS` - Save screenshots (true/false)
- `SEND_EMAIL_NOTIFICATIONS` - Send notifications (true/false)

## Usage Examples

### Using with Shell Scripts

```bash
#!/bin/bash

# Load environment variables
source .env

# Generate config before running your application
./scripts/generate-config.sh

# Run your application
./your-application --config config.json
```

### Using with Docker

```dockerfile
# Dockerfile
FROM node:18

# Copy template and script
COPY config.template.json .
COPY scripts/generate-config.sh ./scripts/

# Generate config at runtime
RUN chmod +x scripts/generate-config.sh
CMD ["sh", "-c", "./scripts/generate-config.sh && node app.js"]
```

```bash
# Pass environment variables to container
docker run -e PERSONAL_NAME="John Doe" \
           -e PERSONAL_EMAIL="john@example.com" \
           --env-file .env \
           your-image
```

### Using with GitHub Actions

```yaml
name: Deploy Application

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Generate configuration
        env:
          PERSONAL_NAME: ${{ secrets.PERSONAL_NAME }}
          PERSONAL_EMAIL: ${{ secrets.PERSONAL_EMAIL }}
          PERSONAL_PHONE: ${{ secrets.PERSONAL_PHONE }}
          LINKEDIN_EMAIL: ${{ secrets.LINKEDIN_EMAIL }}
          LINKEDIN_PASSWORD: ${{ secrets.LINKEDIN_PASSWORD }}
          RESUME_PATH: ${{ secrets.RESUME_PATH }}
          COVER_LETTER_PATH: ${{ secrets.COVER_LETTER_PATH }}
          SALARY_MIN: ${{ secrets.SALARY_MIN }}
          MAX_APPLICATIONS_PER_RUN: ${{ secrets.MAX_APPLICATIONS_PER_RUN }}
          DELAY_BETWEEN_APPLICATIONS: ${{ secrets.DELAY_BETWEEN_APPLICATIONS }}
          HEADLESS_BROWSER: ${{ secrets.HEADLESS_BROWSER }}
          SAVE_SCREENSHOTS: ${{ secrets.SAVE_SCREENSHOTS }}
          SEND_EMAIL_NOTIFICATIONS: ${{ secrets.SEND_EMAIL_NOTIFICATIONS }}
        run: |
          chmod +x scripts/generate-config.sh
          ./scripts/generate-config.sh

      - name: Deploy application
        run: ./deploy.sh
```

### Using with CI/CD Platforms

**GitLab CI:**
```yaml
variables:
  PERSONAL_NAME: ${CI_PERSONAL_NAME}
  PERSONAL_EMAIL: ${CI_PERSONAL_EMAIL}
  # ... other variables

generate-config:
  script:
    - ./scripts/generate-config.sh
```

**Jenkins:**
```groovy
environment {
    PERSONAL_NAME = credentials('personal-name')
    PERSONAL_EMAIL = credentials('personal-email')
    // ... other variables
}

stage('Generate Config') {
    steps {
        sh './scripts/generate-config.sh'
    }
}
```

## Script Reference

### generate-config.sh

**Purpose**: Generate `config.json` from `config.template.json` by substituting environment variables.

**Usage**:
```bash
./scripts/generate-config.sh [OPTIONS]

OPTIONS:
  --validate-only    Only validate variables without generating config
```

**Features**:
- ✅ Loads variables from `.env` file if present
- ✅ Validates all required variables are set
- ✅ Substitutes environment variables using `envsubst`
- ✅ Validates generated JSON syntax (if `jq` is installed)
- ✅ Displays masked preview of generated config
- ✅ Color-coded output for better readability

**Exit Codes**:
- `0` - Success
- `1` - Missing required variables or generation failed

### validate-env.sh

**Purpose**: Standalone script to validate environment variables without generating config.

**Usage**:
```bash
./scripts/validate-env.sh
```

## Best Practices

### Security

1. **Never commit sensitive files**:
   ```bash
   # These files are already in .gitignore
   .env
   config.json
   config.*.json
   ```

2. **Use strong passwords**:
   - Use a password manager
   - Enable 2FA where possible
   - Rotate credentials regularly

3. **Limit access**:
   ```bash
   # Make .env readable only by owner
   chmod 600 .env
   ```

4. **Use secrets management in production**:
   - AWS Secrets Manager
   - HashiCorp Vault
   - GitHub Secrets
   - Environment variables in CI/CD

### Configuration Management

1. **Keep templates versioned**:
   - Commit `config.template.json` and `.env.example`
   - Document required variables
   - Update templates when adding new variables

2. **Validate early**:
   ```bash
   # Validate before running application
   ./scripts/generate-config.sh --validate-only || exit 1
   ```

3. **Use defaults where appropriate**:
   ```bash
   # In scripts, provide sensible defaults
   MAX_APPLICATIONS=${MAX_APPLICATIONS_PER_RUN:-10}
   HEADLESS=${HEADLESS_BROWSER:-true}
   ```

4. **Document variable formats**:
   - Include format examples in `.env.example`
   - Add validation logic in scripts
   - Use consistent naming conventions

### Troubleshooting

**Problem**: `envsubst: command not found`

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install gettext-base

# macOS
brew install gettext

# Alpine Linux
apk add gettext
```

**Problem**: Variables not being substituted

**Solution**:
```bash
# Check if .env exists and has correct values
cat .env

# Verify environment variables are loaded
env | grep PERSONAL_NAME

# Manually source .env and test
source .env
echo $PERSONAL_NAME
```

**Problem**: Invalid JSON in generated config

**Solution**:
```bash
# Check for special characters that need escaping
# Ensure boolean values are lowercase (true/false) without quotes
# Ensure numeric values don't have quotes

# Install jq to validate JSON
sudo apt-get install jq  # or brew install jq
jq . config.json
```

**Problem**: Permission denied when running scripts

**Solution**:
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Or run with bash explicitly
bash scripts/generate-config.sh
```

## GitHub Actions Integration

### Setting Up Secrets

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each required variable:
   - Name: `PERSONAL_NAME`
   - Value: `John Doe`
   - Click "Add secret"
5. Repeat for all required variables

### Using Secrets in Workflows

```yaml
env:
  # Method 1: Set individual environment variables
  PERSONAL_NAME: ${{ secrets.PERSONAL_NAME }}
  PERSONAL_EMAIL: ${{ secrets.PERSONAL_EMAIL }}

steps:
  - name: Generate config
    # Method 2: Pass all secrets at step level
    env:
      PERSONAL_NAME: ${{ secrets.PERSONAL_NAME }}
      PERSONAL_EMAIL: ${{ secrets.PERSONAL_EMAIL }}
    run: ./scripts/generate-config.sh
```

## Advanced Usage

### Multiple Environments

Create environment-specific templates:

```bash
# Development
./scripts/generate-config.sh
mv config.json config.dev.json

# Staging
export PERSONAL_NAME="Staging User"
./scripts/generate-config.sh
mv config.json config.staging.json

# Production
export PERSONAL_NAME="Production User"
./scripts/generate-config.sh
mv config.json config.prod.json
```

### Custom Template Locations

```bash
# Modify script to use custom template
TEMPLATE_FILE=./configs/custom.template.json \
OUTPUT_FILE=./configs/custom.json \
./scripts/generate-config.sh
```

### Integration with Configuration Management Tools

**Ansible:**
```yaml
- name: Generate application config
  shell: ./scripts/generate-config.sh
  environment:
    PERSONAL_NAME: "{{ personal_name }}"
    PERSONAL_EMAIL: "{{ personal_email }}"
```

**Terraform:**
```hcl
resource "null_resource" "generate_config" {
  provisioner "local-exec" {
    command = "./scripts/generate-config.sh"
    environment = {
      PERSONAL_NAME  = var.personal_name
      PERSONAL_EMAIL = var.personal_email
    }
  }
}
```

## Migration from Hardcoded Values

If you have existing configuration with hardcoded values:

1. **Identify sensitive/environment-specific values**:
   ```bash
   grep -r "password\|api_key\|secret" config.json
   ```

2. **Replace with variables**:
   ```json
   {
     "api_key": "hardcoded-key"  // Before
     "api_key": "${API_KEY}"     // After
   }
   ```

3. **Update .env.example**:
   ```bash
   echo "API_KEY=your_api_key_here" >> .env.example
   ```

4. **Regenerate configuration**:
   ```bash
   ./scripts/generate-config.sh
   ```

## Support

For issues or questions about the configuration management system:

1. Check [Troubleshooting](#troubleshooting) section
2. Review script output for detailed error messages
3. Verify all required variables are set: `./scripts/generate-config.sh --validate-only`
4. Check file permissions: `ls -la .env config.template.json`

## Related Documentation

- [README.md](README.md) - Main project documentation
- [ENTERPRISE-VALUE.md](ENTERPRISE-VALUE.md) - Business value and ROI analysis
- [.env.example](.env.example) - Environment variable template

---

**Last Updated**: 2025-11-25

**Version**: 1.0.0
