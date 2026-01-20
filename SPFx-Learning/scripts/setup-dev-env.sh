#!/bin/bash

###############################################################################
# SPFx Development Environment Setup Script
#
# This script sets up your development environment for SPFx 1.22+
# including Node.js 22, global tools, and project dependencies.
#
# Usage:
#   ./setup-dev-env.sh
#
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     SPFx Development Environment Setup (v1.22)           ${BLUE}║${NC}"
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

check_node() {
    print_step "Checking Node.js installation"

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js $NODE_VERSION installed"

        # Check if version is 22.x
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$MAJOR_VERSION" != "22" ]; then
            print_warning "Current Node.js version is $NODE_VERSION"
            print_warning "SPFx 1.22 requires Node.js 22 LTS"
            echo ""
            print_info "You can switch versions using nvm:"
            echo "  nvm install 22"
            echo "  nvm use 22"
            echo ""
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "Node.js version is compatible with SPFx 1.22"
        fi
    else
        print_error "Node.js is not installed"
        echo ""
        print_info "Please install Node.js 22 LTS:"
        echo "  - Download from: https://nodejs.org/"
        echo "  - Or use nvm: nvm install 22"
        exit 1
    fi
}

check_npm() {
    print_step "Checking npm"

    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm $NPM_VERSION installed"
    else
        print_error "npm is not installed (should come with Node.js)"
        exit 1
    fi
}

install_global_tools() {
    print_step "Installing global tools"

    # Yeoman
    if command -v yo &> /dev/null; then
        print_success "Yeoman already installed ($(yo --version))"
    else
        print_info "Installing Yeoman"
        npm install -g yo
        print_success "Yeoman installed"
    fi

    # SPFx generator
    print_info "Installing/updating SPFx Yeoman generator"
    npm install -g @microsoft/generator-sharepoint@latest
    print_success "SPFx generator installed"

    # Heft CLI
    if command -v heft &> /dev/null; then
        print_success "Heft already installed"
    else
        print_info "Installing Heft CLI"
        npm install -g @rushstack/heft
        print_success "Heft CLI installed"
    fi

    # CLI for Microsoft 365 (optional but recommended)
    if command -v m365 &> /dev/null; then
        print_success "CLI for Microsoft 365 already installed"
    else
        print_info "Installing CLI for Microsoft 365"
        npm install -g @pnp/cli-microsoft365
        print_success "CLI for Microsoft 365 installed"
    fi

    # Gulp CLI (for legacy projects)
    if command -v gulp &> /dev/null; then
        print_success "Gulp CLI already installed"
    else
        print_info "Installing Gulp CLI (for legacy SPFx projects)"
        npm install -g gulp-cli
        print_success "Gulp CLI installed"
    fi
}

trust_dev_certificate() {
    print_step "Setting up development certificate"

    print_info "Trusting development certificate for HTTPS"
    npx @rushstack/heft trust-dev-cert || {
        print_warning "Failed to trust certificate. You may need to do this manually."
    }
    print_success "Development certificate trusted"
}

verify_installation() {
    print_step "Verifying installation"

    echo ""
    echo "Installed versions:"
    echo "─────────────────────────────────────────────────"
    echo "Node.js:         $(node --version)"
    echo "npm:             $(npm --version)"
    echo "Yeoman:          $(yo --version 2>/dev/null || echo 'Not installed')"
    echo "SPFx generator:  $(npm list -g @microsoft/generator-sharepoint --depth=0 2>/dev/null | grep @microsoft/generator-sharepoint | awk '{print $2}' || echo 'Not found')"
    echo "Heft:            $(heft --version 2>/dev/null || echo 'Not installed')"
    echo "M365 CLI:        $(m365 --version 2>/dev/null || echo 'Not installed')"
    echo "Gulp:            $(gulp --version 2>/dev/null | head -n1 || echo 'Not installed')"
    echo "─────────────────────────────────────────────────"
    echo ""
}

show_next_steps() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}            Setup completed successfully! 🎉               ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "1. Create a new SPFx project:"
    echo "   mkdir my-webpart && cd my-webpart"
    echo "   yo @microsoft/sharepoint"
    echo ""
    echo "2. Or use the sample project in this repository:"
    echo "   cd sample-webpart"
    echo "   npm install"
    echo "   npm run serve"
    echo ""
    echo "3. Read the complete guide:"
    echo "   SPFX-COMPLETE-GUIDE.md"
    echo ""
    print_info "Happy coding! 🚀"
    echo ""
}

# Main
main() {
    print_header

    check_node
    check_npm
    install_global_tools
    trust_dev_certificate
    verify_installation
    show_next_steps
}

main "$@"
