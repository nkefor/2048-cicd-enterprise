#!/bin/bash

# Configuration Generation Script
# This script generates config.json from config.template.json by substituting environment variables
# Usage: ./scripts/generate-config.sh [--validate-only]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/config.template.json"
OUTPUT_FILE="$PROJECT_ROOT/config.json"
ENV_FILE="$PROJECT_ROOT/.env"

# Required environment variables
REQUIRED_VARS=(
    "PERSONAL_NAME"
    "PERSONAL_EMAIL"
    "PERSONAL_PHONE"
    "LINKEDIN_EMAIL"
    "LINKEDIN_PASSWORD"
    "RESUME_PATH"
    "COVER_LETTER_PATH"
    "SALARY_MIN"
    "MAX_APPLICATIONS_PER_RUN"
    "DELAY_BETWEEN_APPLICATIONS"
    "HEADLESS_BROWSER"
    "SAVE_SCREENSHOTS"
    "SEND_EMAIL_NOTIFICATIONS"
)

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if a variable is set
check_variable() {
    local var_name=$1
    if [ -z "${!var_name}" ]; then
        return 1
    fi
    return 0
}

# Function to validate all required variables
validate_variables() {
    local missing_vars=()

    print_info "Validating required environment variables..."

    for var in "${REQUIRED_VARS[@]}"; do
        if check_variable "$var"; then
            print_success "$var is set"
        else
            print_error "$var is NOT set"
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "\nMissing ${#missing_vars[@]} required environment variable(s):"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        print_info "Please set these variables in your environment or .env file"
        return 1
    fi

    print_success "\nAll required variables are set!"
    return 0
}

# Function to load .env file if it exists
load_env_file() {
    if [ -f "$ENV_FILE" ]; then
        print_info "Loading environment variables from .env file..."
        # Export variables from .env file
        set -a
        source "$ENV_FILE"
        set +a
        print_success ".env file loaded"
    else
        print_warning ".env file not found at: $ENV_FILE"
        print_info "Using system environment variables only"
    fi
}

# Function to generate config file
generate_config() {
    print_info "Generating config.json from template..."

    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi

    # Use envsubst to replace variables
    if ! command -v envsubst &> /dev/null; then
        print_error "envsubst command not found. Please install gettext package."
        print_info "Ubuntu/Debian: apt-get install gettext-base"
        print_info "macOS: brew install gettext"
        exit 1
    fi

    # Generate config file
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

    # Validate JSON syntax
    if command -v jq &> /dev/null; then
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            print_success "Generated valid JSON config file: $OUTPUT_FILE"
        else
            print_error "Generated config file has invalid JSON syntax!"
            rm "$OUTPUT_FILE"
            exit 1
        fi
    else
        print_success "Config file generated: $OUTPUT_FILE"
        print_warning "jq not installed - skipping JSON validation"
    fi
}

# Function to display config file (with sensitive data masked)
display_config() {
    print_info "\nGenerated configuration preview:"
    echo "----------------------------------------"
    if command -v jq &> /dev/null; then
        jq '
            .personal_info.email = (.personal_info.email | sub(".*"; "***@***.com")) |
            .personal_info.phone = "***-***-****" |
            .personal_info.linkedin_email = "***@***.com" |
            .personal_info.linkedin_password = "********" |
            .personal_info.name = "********"
        ' "$OUTPUT_FILE"
    else
        cat "$OUTPUT_FILE"
    fi
    echo "----------------------------------------"
}

# Main script
main() {
    echo ""
    print_info "=== Configuration Generation Script ==="
    echo ""

    # Load .env file if exists
    load_env_file
    echo ""

    # Validate variables
    if ! validate_variables; then
        exit 1
    fi

    # Check if only validation was requested
    if [ "$1" == "--validate-only" ]; then
        print_success "\nValidation complete - all required variables are set"
        exit 0
    fi

    echo ""

    # Generate config
    generate_config

    # Display preview
    display_config

    echo ""
    print_success "Configuration generation complete!"
    print_warning "Note: config.json contains sensitive data - keep it secure and never commit it to git"
    echo ""
}

# Run main function
main "$@"
