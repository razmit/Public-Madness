#!/bin/bash

###############################################################################
# SPFx Deployment Script
#
# This script automates the deployment of SPFx solutions to SharePoint Online
# using the CLI for Microsoft 365.
#
# Usage:
#   ./deploy.sh [environment] [options]
#
# Examples:
#   ./deploy.sh dev                    # Deploy to dev environment
#   ./deploy.sh prod --skip-build      # Deploy to prod without rebuilding
#   ./deploy.sh dev --site-url https://tenant.sharepoint.com/sites/mysite
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PACKAGE_NAME="spfx-sample-webpart.sppkg"
PACKAGE_PATH="sharepoint/solution/${PACKAGE_NAME}"

# Functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          SPFx Deployment Script for SharePoint          ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}▶${NC} $1"
}

show_usage() {
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environments:"
    echo "  dev         Deploy to development environment"
    echo "  prod        Deploy to production environment"
    echo ""
    echo "Options:"
    echo "  --skip-build           Skip the build and package steps"
    echo "  --site-url URL         Install the app on specific site"
    echo "  --skip-feature-deploy  Deploy tenant-wide (skip feature deployment)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --skip-build"
    echo "  $0 dev --site-url https://tenant.sharepoint.com/sites/mysite"
    exit 1
}

check_prerequisites() {
    print_step "Checking prerequisites"

    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 22 LTS."
        exit 1
    fi
    print_success "Node.js $(node --version) installed"

    # Check Node version (should be v22)
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 22 ]; then
        print_warning "Node.js version is $NODE_VERSION. SPFx 1.22 requires Node.js 22 LTS."
        echo "Please upgrade: nvm install 22 && nvm use 22"
    fi

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed."
        exit 1
    fi
    print_success "npm $(npm --version) installed"

    # Check if m365 CLI is installed
    if ! command -v m365 &> /dev/null; then
        print_error "CLI for Microsoft 365 is not installed."
        echo "Install it with: npm install -g @pnp/cli-microsoft365"
        exit 1
    fi
    print_success "CLI for Microsoft 365 installed"
}

build_solution() {
    print_step "Building SPFx solution"

    # Clean previous builds
    print_info "Cleaning previous builds"
    npm run clean || true

    # Install dependencies
    print_info "Installing dependencies"
    npm install

    # Build
    print_info "Building solution (this may take a minute)"
    npm run build

    # Package
    print_info "Packaging solution"
    npm run package

    if [ -f "$PACKAGE_PATH" ]; then
        print_success "Package created: $PACKAGE_PATH"
    else
        print_error "Package not found at $PACKAGE_PATH"
        exit 1
    fi
}

login_m365() {
    print_step "Logging in to Microsoft 365"

    # Check if already logged in
    if m365 status &> /dev/null; then
        print_info "Already logged in to Microsoft 365"
    else
        print_info "Please login to Microsoft 365"
        m365 login --authType browser
        print_success "Logged in successfully"
    fi
}

deploy_to_appcatalog() {
    local skip_feature_deploy=$1

    print_step "Deploying to App Catalog"

    # Upload to tenant app catalog
    print_info "Uploading package to tenant app catalog"
    m365 spo app add \
        --filePath "$PACKAGE_PATH" \
        --appCatalogScope tenant \
        --overwrite

    print_success "Package uploaded"

    # Deploy the app
    print_info "Deploying the app"
    if [ "$skip_feature_deploy" = true ]; then
        m365 spo app deploy \
            --name "$PACKAGE_NAME" \
            --appCatalogScope tenant \
            --skipFeatureDeployment
        print_success "App deployed tenant-wide"
    else
        m365 spo app deploy \
            --name "$PACKAGE_NAME" \
            --appCatalogScope tenant
        print_success "App deployed"
    fi
}

install_on_site() {
    local site_url=$1

    print_step "Installing app on site"

    print_info "Installing on: $site_url"
    m365 spo app install \
        --name "$PACKAGE_NAME" \
        --siteUrl "$site_url"

    print_success "App installed on site"
}

# Main script
main() {
    print_header

    # Parse arguments
    ENVIRONMENT=""
    SKIP_BUILD=false
    SITE_URL=""
    SKIP_FEATURE_DEPLOY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|prod)
                ENVIRONMENT=$1
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --site-url)
                SITE_URL=$2
                shift 2
                ;;
            --skip-feature-deploy)
                SKIP_FEATURE_DEPLOY=true
                shift
                ;;
            --help)
                show_usage
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done

    # Validate environment
    if [ -z "$ENVIRONMENT" ]; then
        print_error "Environment not specified"
        show_usage
    fi

    print_info "Deploying to: $ENVIRONMENT"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Build solution (unless skipped)
    if [ "$SKIP_BUILD" = false ]; then
        build_solution
    else
        print_warning "Skipping build (using existing package)"
        if [ ! -f "$PACKAGE_PATH" ]; then
            print_error "Package not found at $PACKAGE_PATH. Cannot skip build."
            exit 1
        fi
    fi

    # Login to M365
    login_m365

    # Deploy to app catalog
    deploy_to_appcatalog $SKIP_FEATURE_DEPLOY

    # Install on site if URL provided
    if [ -n "$SITE_URL" ]; then
        install_on_site "$SITE_URL"
    fi

    # Success!
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}           Deployment completed successfully! 🚀            ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Package: $PACKAGE_NAME"
    print_info "Environment: $ENVIRONMENT"
    if [ -n "$SITE_URL" ]; then
        print_info "Installed on: $SITE_URL"
    fi
    echo ""
}

# Run main function
main "$@"
