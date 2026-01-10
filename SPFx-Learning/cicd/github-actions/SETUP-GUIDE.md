# GitHub Actions Setup Guide for SPFx

This guide walks you through setting up automated CI/CD for your SPFx project using GitHub Actions with **Federated Identity** (the modern, secure approach with no secrets to rotate!).

## Why Federated Identity?

**Traditional approach (bad):**
- Store client secret or certificate in GitHub Secrets
- Secrets expire and need rotation
- Security risk if secrets are leaked

**Federated Identity approach (good):**
- No secrets stored in GitHub
- GitHub talks directly to Microsoft 365 using OpenID Connect (OIDC)
- More secure, zero maintenance

## Prerequisites

- GitHub repository
- SharePoint Online tenant
- Admin access to Azure AD
- SPFx solution ready to deploy

---

## Setup Option 1: Federated Identity (Recommended)

### Step 1: Create Azure AD App Registration

```bash
# Install CLI for Microsoft 365 (if not already installed)
npm install -g @pnp/cli-microsoft365

# Login to your tenant
m365 login

# Create Azure AD app with required permissions
m365 aad app add \
  --name "GitHub SPFx Deployment" \
  --withSecret \
  --grantAdminConsent \
  --apisApplication "https://microsoft.sharepoint-df.com/Sites.FullControl.All"

# Save the Application (client) ID and Tenant ID from the output
```

### Step 2: Configure Federated Credentials

This is the key step that links GitHub Actions to your Azure AD app.

#### Option A: Via Azure Portal (Easier)

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Find your app "GitHub SPFx Deployment"
4. Go to **Certificates & secrets** > **Federated credentials**
5. Click **Add credential**
6. Select **GitHub Actions deploying Azure resources**
7. Fill in:
   - **Organization**: Your GitHub username/org (e.g., `octocat`)
   - **Repository**: Your repo name (e.g., `spfx-project`)
   - **Entity type**: Branch
   - **GitHub branch name**: `main`
   - **Name**: `github-main-branch`
8. Click **Add**
9. Repeat for `develop` branch if needed

#### Option B: Via CLI for Microsoft 365 (Advanced)

```bash
# Get your app's object ID
APP_ID="<your-app-id-from-step-1>"

# Add federated credential for 'main' branch
m365 aad app set --appId $APP_ID \
  --federatedIdentityCredentials '[{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }]'

# Add federated credential for 'develop' branch
m365 aad app set --appId $APP_ID \
  --federatedIdentityCredentials '[{
    "name": "github-develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }]'
```

**Important**: Replace `YOUR_ORG/YOUR_REPO` with your actual GitHub organization and repository name!

### Step 3: Configure GitHub Secrets

Even with federated identity, you still need to store some config (but no secrets!):

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Add these **Repository secrets**:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `M365_APP_ID` | Your App ID | Azure AD Application ID |
| `M365_TENANT_ID` | Your Tenant ID | Azure AD Tenant ID |
| `DEV_SITE_URL` | `https://tenant.sharepoint.com/sites/dev` | Dev site URL (optional) |
| `M365_APP_ID_PROD` | Production App ID | Separate app for production |
| `M365_TENANT_ID_PROD` | Production Tenant ID | Production tenant ID |
| `PROD_TENANT_URL` | `https://tenant.sharepoint.com` | Production SharePoint URL |

4. Add this **Repository variable**:

| Variable Name | Value |
|--------------|-------|
| `USE_FEDERATED_IDENTITY` | `true` |

### Step 4: Configure GitHub Environments

Environments provide deployment protection rules:

1. Go to **Settings** > **Environments**
2. Create **dev** environment:
   - No protection rules needed
3. Create **production** environment:
   - Enable **Required reviewers**
   - Add yourself and/or team members as reviewers
   - Optionally add **Wait timer** (e.g., 5 minutes before deployment)

### Step 5: Add Workflow to Repository

```bash
# Create .github/workflows directory
mkdir -p .github/workflows

# Copy the workflow file
cp cicd/github-actions/spfx-cicd.yml .github/workflows/

# Update the PACKAGE_NAME in the workflow file
# Edit .github/workflows/spfx-cicd.yml and change:
# PACKAGE_NAME: 'your-actual-package-name.sppkg'

# Commit and push
git add .github/workflows/spfx-cicd.yml
git commit -m "Add GitHub Actions workflow for SPFx"
git push
```

### Step 6: Test the Workflow

1. Make a change to your SPFx code
2. Commit and push to `develop` branch
3. Go to **Actions** tab in GitHub
4. Watch your workflow run!

---

## Setup Option 2: Certificate-based Authentication (Fallback)

If federated identity doesn't work for your organization, use certificate-based auth.

### Step 1: Generate Certificate

```bash
# Generate certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Convert to base64 (single line, no wrapping)
base64 -w 0 cert.pem > cert.base64.txt

# View the base64 string (copy this for GitHub Secrets)
cat cert.base64.txt
```

### Step 2: Create Azure AD App

```bash
m365 login

m365 aad app add \
  --name "GitHub SPFx Deployment" \
  --platform publicClient \
  --grantAdminConsent
```

### Step 3: Upload Certificate

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Find your app
4. Go to **Certificates & secrets** > **Certificates** > **Upload certificate**
5. Upload your `cert.pem` file

### Step 4: Grant API Permissions

1. In the app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **SharePoint** > **Application permissions**
4. Add: `Sites.FullControl.All`
5. Click **Grant admin consent**

### Step 5: Configure GitHub Secrets

Add these secrets:

| Secret Name | Value |
|------------|-------|
| `M365_APP_ID` | Your App ID |
| `M365_TENANT_ID` | Your Tenant ID |
| `M365_CERTIFICATE` | Contents of `cert.base64.txt` |
| `M365_CERTIFICATE_PASSWORD` | Certificate password (if set) |

Set variable `USE_FEDERATED_IDENTITY` to `false`.

---

## Workflow Behavior

### On Push to `develop` branch:
```
1. Build ✓
2. Deploy to Dev ✓
```

### On Push to `main` branch:
```
1. Build ✓
2. Deploy to Production (requires approval) ⏸️
```

### On Pull Request:
```
1. Build ✓
2. Comment on PR ✓
(No deployment)
```

### Manual Trigger:
```
1. Go to Actions tab
2. Select "SPFx CI/CD" workflow
3. Click "Run workflow"
4. Choose environment (dev/production)
```

---

## Customization

### Change Package Name

Edit `.github/workflows/spfx-cicd.yml`:

```yaml
env:
  PACKAGE_NAME: 'your-app-name.sppkg'
```

### Deploy to Multiple Sites

Add a step to loop through sites:

```yaml
- name: Install on multiple sites
  run: |
    for site in ${{ secrets.SITE_URLS }}; do
      echo "Installing on $site"
      m365 spo app install --name ${{ env.PACKAGE_NAME }} --siteUrl $site
    done
```

Add `SITE_URLS` secret with space-separated URLs.

### Add Notifications

#### Slack Notification

```yaml
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "SPFx deployment failed!"
      }
```

#### Teams Notification

```yaml
- name: Notify Teams
  if: failure()
  run: |
    curl -H 'Content-Type: application/json' \
      -d '{"text": "SPFx deployment failed!"}' \
      ${{ secrets.TEAMS_WEBHOOK }}
```

### Run on Specific Paths Only

Already configured, but you can adjust:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'src/**'           # Only trigger on source changes
      - 'config/**'        # or config changes
      - 'package.json'
```

---

## Troubleshooting

### Issue: "Federated credential validation failed"

**Cause**: Subject claim mismatch
**Solution**: Verify the subject in Azure AD matches your GitHub org/repo:
```
repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/BRANCH_NAME
```

### Issue: "Insufficient privileges"

**Cause**: API permissions not granted
**Solution**: Grant admin consent in Azure AD for `Sites.FullControl.All`

### Issue: Workflow doesn't trigger

**Cause**: Path filters or branch mismatch
**Solution**: Check that your changes match the `paths` filter in the workflow

### Issue: "m365: command not found"

**Cause**: CLI for Microsoft 365 not installed
**Solution**: Should not happen as workflow installs it. Check logs.

### Issue: Certificate expires

**Solution**: Generate new certificate and update in Azure AD and GitHub Secrets

---

## Security Best Practices

1. **Use federated identity** (no secrets to rotate)
2. **Separate dev and prod apps** (different Azure AD apps for each environment)
3. **Require approvals for production** (configure in GitHub Environments)
4. **Use branch protection rules** (require PR reviews before merging)
5. **Limit who can approve deployments** (only senior team members)
6. **Audit logs** (review Actions logs regularly)
7. **Rotate certificates** before expiry (set calendar reminder)
8. **Never commit secrets** to the repository

---

## Advanced: Multi-Tenant Deployment

If you deploy to multiple customer tenants:

```yaml
deploy-customer:
  strategy:
    matrix:
      customer: [customer1, customer2, customer3]
  steps:
    - name: Deploy to ${{ matrix.customer }}
      run: |
        m365 login --authType certificate \
          --certificateBase64Encoded "${{ secrets[format('M365_CERT_{0}', matrix.customer)] }}" \
          --appId ${{ secrets[format('M365_APP_ID_{0}', matrix.customer)] }} \
          --tenant ${{ secrets[format('M365_TENANT_{0}', matrix.customer)] }}
        m365 spo app add --filePath ./solution/${{ env.PACKAGE_NAME }} --overwrite
        m365 spo app deploy --name ${{ env.PACKAGE_NAME }}
```

Store secrets like:
- `M365_CERT_CUSTOMER1`
- `M365_APP_ID_CUSTOMER1`
- etc.

---

## Status Badge

Add to your README.md:

```markdown
![SPFx CI/CD](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/spfx-cicd.yml/badge.svg)
```

---

## Resources

- [GitHub Actions docs](https://docs.github.com/en/actions)
- [Federated identity in Azure AD](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [CLI for Microsoft 365](https://pnp.github.io/cli-microsoft365/)
- [Voitanos: SPFx CI/CD with GitHub Federated Identity](https://www.voitanos.io/blog/sharepoint-framework-cicd-github-federated-identity/)

---

**Last Updated**: January 2026

Enjoy your automated deployments! 🚀
