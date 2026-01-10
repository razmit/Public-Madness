# Azure DevOps Pipeline Setup Guide for SPFx

This guide walks you through setting up automated CI/CD for your SPFx project using Azure DevOps.

## Prerequisites

- Azure DevOps organization and project
- SharePoint Online tenant
- Admin access to Azure AD (for app registration)
- SPFx solution ready to deploy

## Step 1: Create Azure AD App Registration

You need an Azure AD app with certificate authentication for secure, automated deployments.

### 1.1 Generate Certificate

```bash
# Install CLI for Microsoft 365 (if not already installed)
npm install -g @pnp/cli-microsoft365

# Generate a certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Convert to base64 for Azure DevOps
base64 -w 0 cert.pem > cert.base64.txt
```

### 1.2 Register Azure AD Application

```bash
# Login to your tenant
m365 login

# Create Azure AD app
m365 aad app add \
  --name "SPFx CI/CD Pipeline" \
  --platform publicClient \
  --grantAdminConsent

# Note the Application (client) ID from the output
```

### 1.3 Upload Certificate

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Find your app "SPFx CI/CD Pipeline"
4. Go to **Certificates & secrets** > **Certificates** > **Upload certificate**
5. Upload your `cert.pem` file

### 1.4 Grant API Permissions

The app needs permissions to manage SharePoint:

1. In the app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **SharePoint** > **Application permissions**
4. Add these permissions:
   - `Sites.FullControl.All`
5. Click **Grant admin consent**

## Step 2: Configure Azure DevOps

### 2.1 Create Variable Group

Store secrets securely in Azure DevOps:

1. Go to your Azure DevOps project
2. Navigate to **Pipelines** > **Library**
3. Click **+ Variable group**
4. Name it: `SPFx-Pipeline-Variables`
5. Add these variables:

| Variable Name | Value | Secure? | Description |
|--------------|-------|---------|-------------|
| `M365_APP_ID` | Your App ID | No | Azure AD App ID |
| `M365_TENANT_ID` | Your Tenant ID | No | Azure AD Tenant ID |
| `M365_CERTIFICATE` | Contents of `cert.base64.txt` | **Yes** | Base64-encoded certificate |
| `M365_CERTIFICATE_PASSWORD` | Your cert password (if set) | **Yes** | Certificate password |
| `DEV_SITE_URL` | `https://tenant.sharepoint.com/sites/dev` | No | Dev site URL (optional) |
| `M365_APP_ID_PROD` | Production App ID | No | Production Azure AD App ID |
| `M365_TENANT_ID_PROD` | Production Tenant ID | No | Production Tenant ID |
| `M365_CERTIFICATE_PROD` | Production cert | **Yes** | Production certificate |
| `M365_CERTIFICATE_PASSWORD_PROD` | Production cert password | **Yes** | Production password |

### 2.2 Link Variable Group to Pipeline

In your `azure-pipelines.yml`, add at the top:

```yaml
variables:
  - group: SPFx-Pipeline-Variables
```

### 2.3 Create Environments

Environments allow manual approvals for production deployments:

1. Go to **Pipelines** > **Environments**
2. Create two environments:
   - **dev**: No approvals needed
   - **production**: Add approval check
     - Click on environment > **Approvals and checks**
     - Add **Approvals**
     - Select approvers (e.g., team lead, manager)

## Step 3: Add Pipeline to Your Repository

### 3.1 Copy Pipeline File

Copy `azure-pipelines.yml` to the root of your SPFx project repository.

### 3.2 Update Variables

Edit the pipeline file and update these variables:

```yaml
variables:
  # Update this to match your .sppkg filename
  packageName: 'your-app-name.sppkg'
```

### 3.3 Commit and Push

```bash
git add azure-pipelines.yml
git commit -m "Add Azure DevOps pipeline for SPFx"
git push
```

## Step 4: Create the Pipeline in Azure DevOps

1. Go to **Pipelines** > **Pipelines** in Azure DevOps
2. Click **New pipeline**
3. Select your repository source (Azure Repos, GitHub, etc.)
4. Select **Existing Azure Pipelines YAML file**
5. Choose `/azure-pipelines.yml`
6. Click **Run**

## Pipeline Workflow

The pipeline has three stages:

```
┌─────────────┐
│   BUILD     │  Always runs on every commit
│             │  - Install dependencies
│             │  - Run linting
│             │  - Run tests
│             │  - Build with Heft
│             │  - Package solution
│             │  - Publish artifacts
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  DEPLOY DEV │  Runs automatically after build
│             │  - Download artifacts
│             │  - Login to M365
│             │  - Upload to App Catalog
│             │  - Deploy app
│             │  - Install on dev site
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ DEPLOY PROD │  Runs only on 'main' branch
│             │  **Requires manual approval**
│             │  - Download artifacts
│             │  - Login to M365 (prod)
│             │  - Upload to App Catalog
│             │  - Deploy tenant-wide
└─────────────┘
```

## Authentication Methods

### Option 1: Certificate-based (Recommended)

Already configured in the pipeline. Most secure, no password rotation needed.

### Option 2: Username/Password (Not Recommended)

Less secure, requires password rotation.

```yaml
- script: |
    m365 login --authType password \
      --userName $(M365_USERNAME) \
      --password $(M365_PASSWORD)
  displayName: 'Login to M365'
```

Add variables:
- `M365_USERNAME`: Service account email
- `M365_PASSWORD`: Service account password (marked as secret)

### Option 3: Managed Identity (Azure-hosted only)

If your Azure DevOps agent runs in Azure, you can use managed identities.

## Customization Options

### Run Tests

Uncomment the test step in the pipeline:

```yaml
- script: |
    npm test -- --ci --coverage
  displayName: 'Run Tests'
```

### Deploy to Multiple Sites

Add a loop to install on multiple sites:

```yaml
- script: |
    for site in $(SITE_URLS); do
      m365 spo app install --name $(packageName) --siteUrl $site
    done
  displayName: 'Install on Multiple Sites'
```

Add variable `SITE_URLS` with space-separated URLs.

### Notifications

Add notifications for pipeline failures:

1. Go to pipeline > **Edit** > **Triggers** > **More actions** (...)
2. Select **Status badge**
3. Add to your README.md

Or integrate with:
- Microsoft Teams
- Slack
- Email

## Troubleshooting

### Issue: "Certificate authentication failed"

**Solution**: Verify certificate is correctly uploaded and base64-encoded without line breaks:
```bash
base64 -w 0 cert.pem > cert.base64.txt
```

### Issue: "Insufficient privileges to complete the operation"

**Solution**: Grant admin consent for API permissions in Azure AD.

### Issue: "App already exists"

**Solution**: The pipeline uses `--overwrite` flag, but if it still fails, manually remove the old version first.

### Issue: Pipeline runs on every commit (too often)

**Solution**: Adjust triggers in `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
      - main  # Only run on main branch
```

### Issue: Node version error

**Solution**: Ensure Node 22 is specified:
```yaml
variables:
  nodeVersion: '22.x'
```

## Best Practices

1. **Use separate tenants/subscriptions for dev and prod**
2. **Require approvals for production deployments**
3. **Test in dev environment first**
4. **Version your packages properly** (semantic versioning)
5. **Keep certificates secure** (use Azure Key Vault for enterprise)
6. **Rotate certificates before expiry** (set calendar reminder)
7. **Monitor pipeline runs** (set up alerts for failures)
8. **Use branch policies** (require PR reviews before merging to main)

## Resources

- [Azure Pipelines YAML schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [CLI for Microsoft 365 docs](https://pnp.github.io/cli-microsoft365/)
- [SPFx deployment docs](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/toolchain/implement-ci-cd-with-azure-devops)

## Next Steps

1. Test the pipeline with a sample commit
2. Configure production approvals
3. Add pipeline status badge to README
4. Set up notifications
5. Document the process for your team

---

**Last Updated**: January 2026
