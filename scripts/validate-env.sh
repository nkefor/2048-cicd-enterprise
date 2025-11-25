#!/bin/bash

# Environment Variables Validation Script
# This script validates that all required environment variables are set
# Usage: ./scripts/validate-env.sh

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
        print_info "Validating system environment variables only"
        print_info "To create .env file: cp .env.example .env"
    fi
}

# Function to validate variable format
validate_format() {
    local var_name=$1
    local var_value="${!var_name}"

    case $var_name in
        "PERSONAL_EMAIL"|"LINKEDIN_EMAIL")
            if [[ ! "$var_value" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$ ]]; then
                print_warning "$var_name: Email format may be invalid"
                return 1
            fi
            ;;
        "SALARY_MIN"|"MAX_APPLICATIONS_PER_RUN"|"DELAY_BETWEEN_APPLICATIONS")
            if ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
                print_error "$var_name: Must be a numeric value (found: '$var_value')"
                return 1
            fi
            ;;
        "HEADLESS_BROWSER"|"SAVE_SCREENSHOTS"|"SEND_EMAIL_NOTIFICATIONS")
            if [[ "$var_value" != "true" && "$var_value" != "false" ]]; then
                print_error "$var_name: Must be 'true' or 'false' (found: '$var_value')"
                return 1
            fi
            ;;
        "RESUME_PATH"|"COVER_LETTER_PATH")
            # Just check if path is not empty
            if [ -z "$var_value" ]; then
                print_error "$var_name: Path cannot be empty"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to validate all required variables
validate_variables() {
    local missing_vars=()
    local invalid_vars=()
    local valid_count=0

    print_info "Validating required environment variables..."
    echo ""

    for var in "${REQUIRED_VARS[@]}"; do
        if check_variable "$var"; then
            if validate_format "$var"; then
                print_success "$var is set and valid"
                ((valid_count++))
            else
                invalid_vars+=("$var")
            fi
        else
            print_error "$var is NOT set"
            missing_vars+=("$var")
        fi
    done

    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Validation Summary"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Total variables:   ${#REQUIRED_VARS[@]}"
    echo "  ✓ Valid:           $valid_count"
    echo "  ✗ Missing:         ${#missing_vars[@]}"
    echo "  ⚠ Invalid format:  ${#invalid_vars[@]}"
    echo ""

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "Missing variables:"
        for var in "${missing_vars[@]}"; do
            echo "  • $var"
        done
        echo ""
    fi

    if [ ${#invalid_vars[@]} -gt 0 ]; then
        echo "Variables with format issues:"
        for var in "${invalid_vars[@]}"; do
            echo "  • $var"
        done
        echo ""
    fi

    echo "════════════════════════════════════════════════════════════"
    echo ""

    if [ ${#missing_vars[@]} -gt 0 ] || [ ${#invalid_vars[@]} -gt 0 ]; then
        print_error "Validation failed!"
        echo ""
        print_info "Next steps:"
        echo "  1. Copy .env.example to .env: cp .env.example .env"
        echo "  2. Edit .env and fill in your values"
        echo "  3. Run this validation script again"
        echo "  4. Generate config: ./scripts/generate-config.sh"
        echo ""
        return 1
    fi

    print_success "All required variables are set and valid!"
    echo ""
    print_info "Ready to generate configuration:"
    echo "  ./scripts/generate-config.sh"
    echo ""
    return 0
}

# Function to display variable information
display_var_info() {
    echo ""
    print_info "Required Variable Information:"
    echo ""
    echo "Personal Information:"
    echo "  • PERSONAL_NAME          - Your full name"
    echo "  • PERSONAL_EMAIL         - Your email address (format: user@example.com)"
    echo "  • PERSONAL_PHONE         - Your phone number"
    echo "  • LINKEDIN_EMAIL         - LinkedIn account email"
    echo "  • LINKEDIN_PASSWORD      - LinkedIn password"
    echo "  • RESUME_PATH            - Path to resume file"
    echo "  • COVER_LETTER_PATH      - Path to cover letter"
    echo ""
    echo "Job Preferences:"
    echo "  • SALARY_MIN             - Minimum salary (numeric only)"
    echo ""
    echo "Automation Settings:"
    echo "  • MAX_APPLICATIONS_PER_RUN      - Max applications (numeric)"
    echo "  • DELAY_BETWEEN_APPLICATIONS    - Delay in seconds (numeric)"
    echo "  • HEADLESS_BROWSER              - true or false"
    echo "  • SAVE_SCREENSHOTS              - true or false"
    echo "  • SEND_EMAIL_NOTIFICATIONS      - true or false"
    echo ""
}

# Main script
main() {
    echo ""
    print_info "=== Environment Variables Validation ==="
    echo ""

    # Check if --help flag is provided
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        display_var_info
        exit 0
    fi

    # Load .env file if exists
    load_env_file
    echo ""

    # Validate variables
    if validate_variables; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
