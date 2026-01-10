#!/bin/bash

###############################################################################
# SPFx Quick Start Script
#
# This script helps you quickly scaffold and run a new SPFx project
#
# Usage:
#   ./quick-start.sh [project-name]
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
    echo -e "${BLUE}║${NC}              SPFx Quick Start Generator                   ${BLUE}║${NC}"
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

print_step() {
    echo -e "\n${BLUE}▶${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites"

    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi

    if ! command -v yo &> /dev/null; then
        print_error "Yeoman is not installed"
        echo "Install with: npm install -g yo @microsoft/generator-sharepoint"
        exit 1
    fi

    print_success "All prerequisites met"
}

# Get project details
get_project_details() {
    print_step "Project configuration"

    if [ -z "$1" ]; then
        read -p "Project name (e.g., my-awesome-webpart): " PROJECT_NAME
    else
        PROJECT_NAME=$1
    fi

    if [ -d "$PROJECT_NAME" ]; then
        print_error "Directory $PROJECT_NAME already exists"
        exit 1
    fi

    echo ""
    echo "Select web part template:"
    echo "  1) React (recommended)"
    echo "  2) No framework (Vanilla JS/TS)"
    echo "  3) Minimal"
    read -p "Choice [1]: " TEMPLATE_CHOICE
    TEMPLATE_CHOICE=${TEMPLATE_CHOICE:-1}

    case $TEMPLATE_CHOICE in
        1) TEMPLATE="react";;
        2) TEMPLATE="none";;
        3) TEMPLATE="minimal";;
        *) TEMPLATE="react";;
    esac

    read -p "Web part name [HelloWorld]: " WEBPART_NAME
    WEBPART_NAME=${WEBPART_NAME:-HelloWorld}

    read -p "Web part description [A sample web part]: " WEBPART_DESC
    WEBPART_DESC=${WEBPART_DESC:-"A sample web part"}

    print_info "Project will be created with:"
    echo "  - Name: $PROJECT_NAME"
    echo "  - Template: $TEMPLATE"
    echo "  - Web part: $WEBPART_NAME"
    echo ""
}

# Create project
create_project() {
    print_step "Creating project"

    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"

    # Run Yeoman generator with answers
    cat > .yo-answers.json <<EOF
{
  "@microsoft/generator-sharepoint": {
    "solutionName": "$PROJECT_NAME",
    "componentType": "webpart",
    "componentName": "$WEBPART_NAME",
    "componentDescription": "$WEBPART_DESC",
    "template": "$TEMPLATE",
    "isCreatingSolution": true
  }
}
EOF

    print_info "Running Yeoman generator (this may take a minute)"
    yo @microsoft/sharepoint --skip-install

    rm .yo-answers.json

    print_success "Project scaffolded"
}

# Install dependencies
install_dependencies() {
    print_step "Installing dependencies"

    print_info "Running npm install (this may take a few minutes)"
    npm install

    print_success "Dependencies installed"
}

# Add PnPjs (optional)
add_pnpjs() {
    print_step "Adding PnPjs"

    read -p "Install PnPjs for easier SharePoint API calls? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        npm install @pnp/sp @pnp/core
        print_success "PnPjs installed"

        print_info "Don't forget to initialize PnPjs in your web part's onInit() method"
        echo "See the sample-webpart for an example"
    else
        print_info "Skipping PnPjs installation"
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}            Project created successfully! 🎉               ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "1. Navigate to your project:"
    echo "   cd $PROJECT_NAME"
    echo ""
    echo "2. Start the local development server:"
    echo "   npm run serve"
    echo ""
    echo "3. Open the workbench:"
    echo "   https://localhost:4321/workbench.html"
    echo ""
    echo "4. Build for production:"
    echo "   npm run build"
    echo ""
    echo "5. Package for deployment:"
    echo "   npm run package"
    echo ""
    print_info "The .sppkg file will be in: sharepoint/solution/"
    echo ""
    print_info "Learn more: Read SPFX-COMPLETE-GUIDE.md"
    echo ""
}

# Main
main() {
    print_header

    check_prerequisites
    get_project_details "$1"
    create_project
    install_dependencies
    add_pnpjs
    show_next_steps
}

main "$@"
