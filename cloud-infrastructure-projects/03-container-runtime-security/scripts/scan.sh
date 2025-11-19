#!/bin/bash

################################################################################
# Container Runtime Security - Vulnerability Scanning Script
#
# Performs comprehensive security scanning using Trivy:
# - Container image vulnerability scanning
# - Dependency analysis
# - Configuration checking
# - SBoM (Software Bill of Materials) generation
#
# Usage: ./scripts/scan.sh [image] [options]
#
################################################################################

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${PROJECT_ROOT}/trivy/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
IMAGE="${1:-sample-app:latest}"
SEVERITY="${2:-HIGH,CRITICAL}"
FORMAT="${3:-table}"
SKIP_SBOM="${4:-false}"

# ============================================================
# Functions
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_trivy() {
    if ! command -v trivy &> /dev/null; then
        log_error "Trivy is not installed"
        log_info "Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
        exit 1
    fi

    log_success "Trivy found: $(trivy version)"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "Docker is running"
}

create_reports_dir() {
    mkdir -p "$REPORTS_DIR"
    log_info "Reports directory: $REPORTS_DIR"
}

scan_image() {
    local image=$1
    local severity=$2

    log_info "Scanning image: $image"
    log_info "Severity levels: $severity"

    # Create output files
    local report_json="${REPORTS_DIR}/scan_${TIMESTAMP}.json"
    local report_html="${REPORTS_DIR}/scan_${TIMESTAMP}.html"
    local report_sarif="${REPORTS_DIR}/scan_${TIMESTAMP}.sarif"

    # Run Trivy scan
    log_info "Running vulnerability scan..."

    trivy image \
        --severity "$severity" \
        --format json \
        --output "$report_json" \
        "$image"

    # Generate HTML report
    trivy image \
        --severity "$severity" \
        --format template \
        --template '@contrib/html.tpl' \
        --output "$report_html" \
        "$image" 2>/dev/null || log_warning "Could not generate HTML report"

    # Generate SARIF report (for SIEM/GitHub integration)
    trivy image \
        --severity "$severity" \
        --format sarif \
        --output "$report_sarif" \
        "$image" 2>/dev/null || log_warning "Could not generate SARIF report"

    # Display results
    log_success "Vulnerability scan completed"
    display_results "$report_json" "$severity"

    # Save reports
    log_info "Reports saved to:"
    [ -f "$report_json" ] && echo "  - JSON: $report_json"
    [ -f "$report_html" ] && echo "  - HTML: $report_html"
    [ -f "$report_sarif" ] && echo "  - SARIF: $report_sarif"

    return 0
}

display_results() {
    local report=$1
    local severity=$2

    if [ ! -f "$report" ]; then
        log_error "Report file not found: $report"
        return 1
    fi

    log_info "=== Vulnerability Summary ==="

    # Parse JSON and display summary
    python3 << 'PYTHON_SCRIPT'
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)

    # Count vulnerabilities by severity
    severity_counts = {}
    total = 0

    if 'Results' in data:
        for result in data['Results']:
            if 'Misconfigurations' in result:
                for misc in result['Misconfigurations']:
                    severity = misc.get('Severity', 'UNKNOWN')
                    severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    total += 1

            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    severity = vuln.get('Severity', 'UNKNOWN')
                    severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    total += 1

    print(f"\nTotal Vulnerabilities: {total}")
    print("\nBreakdown by Severity:")
    for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN']:
        count = severity_counts.get(severity, 0)
        if count > 0:
            print(f"  {severity}: {count}")

    # Show critical vulnerabilities
    print("\n=== Critical Issues ===")
    if 'Results' in data:
        for result in data['Results']:
            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    if vuln.get('Severity') == 'CRITICAL':
                        print(f"\n  ID: {vuln.get('VulnerabilityID', 'N/A')}")
                        print(f"  Title: {vuln.get('Title', 'N/A')}")
                        print(f"  Package: {vuln.get('PkgName', 'N/A')}")
                        print(f"  Installed: {vuln.get('InstalledVersion', 'N/A')}")
                        print(f"  Fixed: {vuln.get('FixedVersion', 'N/A')}")
                        print(f"  Score: {vuln.get('CVSS', {}).get('V3.1', {}).get('BaseScore', 'N/A')}")
except Exception as e:
    print(f"Error parsing report: {e}")
    sys.exit(1)
PYTHON_SCRIPT
    python3 -c "
import json
import sys
try:
    with open('$report', 'r') as f:
        data = json.load(f)

    severity_counts = {}
    total = 0

    if 'Results' in data:
        for result in data['Results']:
            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    severity = vuln.get('Severity', 'UNKNOWN')
                    severity_counts[severity] = severity_counts.get(severity, 0) + 1
                    total += 1

    print(f'Total: {total}')
    for sev in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'UNKNOWN']:
        count = severity_counts.get(sev, 0)
        if count > 0:
            print(f'{sev}: {count}')
except Exception as e:
    print(f'Error: {e}')
"
}

scan_dependencies() {
    local image=$1

    log_info "Scanning dependencies..."

    trivy image \
        --list-all-pkgs \
        --format json \
        "$image" > "${REPORTS_DIR}/dependencies_${TIMESTAMP}.json" 2>/dev/null

    log_success "Dependency scan completed"
    log_info "Dependencies report: ${REPORTS_DIR}/dependencies_${TIMESTAMP}.json"
}

generate_sbom() {
    local image=$1

    log_info "Generating Software Bill of Materials (SBOM)..."

    # CycloneDX format
    trivy image \
        --format cyclonedx \
        --output "${REPORTS_DIR}/sbom_${TIMESTAMP}.xml" \
        "$image" 2>/dev/null || log_warning "Could not generate CycloneDX SBOM"

    # SPDX format
    trivy image \
        --format spdx-json \
        --output "${REPORTS_DIR}/sbom_${TIMESTAMP}.spdx.json" \
        "$image" 2>/dev/null || log_warning "Could not generate SPDX SBOM"

    log_success "SBOM generation completed"
    log_info "SBOM files saved to $REPORTS_DIR"
}

compare_with_baseline() {
    local current_report=$1

    if [ ! -f "${REPORTS_DIR}/baseline_scan.json" ]; then
        log_info "No baseline report found - skipping comparison"
        return 0
    fi

    log_info "Comparing with baseline..."

    python3 << 'PYTHON_END'
import json
import sys

try:
    with open(sys.argv[1], 'r') as f:
        current = json.load(f)
    with open(sys.argv[2], 'r') as f:
        baseline = json.load(f)

    # Simple comparison
    current_count = sum(
        len(r.get('Vulnerabilities', []))
        for r in current.get('Results', [])
    )
    baseline_count = sum(
        len(r.get('Vulnerabilities', []))
        for r in baseline.get('Results', [])
    )

    change = current_count - baseline_count
    if change > 0:
        print(f"⚠️  Vulnerabilities increased by {change}")
    elif change < 0:
        print(f"✓ Vulnerabilities decreased by {abs(change)}")
    else:
        print("- No change in vulnerability count")

except Exception as e:
    print(f"Error: {e}")
PYTHON_END
    python3 -c "
import json
current_file = '$current_report'
baseline_file = '${REPORTS_DIR}/baseline_scan.json'

try:
    with open(current_file, 'r') as f:
        current = json.load(f)
    with open(baseline_file, 'r') as f:
        baseline = json.load(f)

    curr_count = sum(len(r.get('Vulnerabilities', [])) for r in current.get('Results', []))
    base_count = sum(len(r.get('Vulnerabilities', [])) for r in baseline.get('Results', []))

    change = curr_count - base_count
    if change > 0:
        print(f'Vulnerabilities increased: {change}')
    elif change < 0:
        print(f'Vulnerabilities decreased: {abs(change)}')
except:
    pass
" 2>/dev/null || true
}

scan_registry() {
    local registry=$1
    local severity=$2

    log_info "Scanning registry: $registry"

    trivy image \
        --severity "$severity" \
        --format json \
        --output "${REPORTS_DIR}/registry_scan_${TIMESTAMP}.json" \
        "$registry" || log_warning "Registry scan failed"
}

show_usage() {
    cat << EOF
Container Security - Vulnerability Scanning

Usage: $0 [image] [severity] [format] [options]

Arguments:
    image       Docker image to scan (default: sample-app:latest)
    severity    Vulnerability severity (default: HIGH,CRITICAL)
    format      Report format: table, json, html (default: table)

Options:
    --sbom              Generate Software Bill of Materials
    --compare           Compare with baseline
    --registry          Scan Docker registry
    --all               Run all scans

Examples:
    $0                                  # Scan default image
    $0 myapp:latest CRITICAL            # Scan with CRITICAL only
    $0 myapp:latest HIGH,CRITICAL json  # JSON output
    $0 sample-app:latest "" table --sbom  # Include SBOM

EOF
}

# ============================================================
# Main
# ============================================================

main() {
    log_info "Container Security - Vulnerability Scanner"
    log_info "=========================================="

    check_docker
    check_trivy
    create_reports_dir

    # Parse additional options
    local do_sbom=false
    local do_compare=false
    local do_all=false

    for arg in "$@"; do
        case "$arg" in
            --sbom)
                do_sbom=true
                ;;
            --compare)
                do_compare=true
                ;;
            --all)
                do_all=true
                do_sbom=true
                do_compare=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
        esac
    done

    # Run main scan
    local report_file="${REPORTS_DIR}/scan_${TIMESTAMP}.json"
    scan_image "$IMAGE" "$SEVERITY"

    # Optional: Generate SBOM
    if [ "$do_sbom" = true ]; then
        generate_sbom "$IMAGE"
    fi

    # Optional: Scan dependencies
    scan_dependencies "$IMAGE"

    # Optional: Compare with baseline
    if [ "$do_compare" = true ]; then
        compare_with_baseline "$report_file"
    fi

    log_success "Scanning completed!"
    log_info "Reports directory: $REPORTS_DIR"
}

# Run if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
