# SharePoint Framework (SPFx) Complete Learning Guide
## Updated for SPFx 1.22+ (January 2026)

> **Note**: This guide reflects the latest SPFx 1.22 released in December 2025, which introduced major changes to the build toolchain. If you're following older tutorials, they likely won't work due to these breaking changes.

---

## Table of Contents
1. [What is SPFx?](#what-is-spfx)
2. [Major Changes in SPFx 1.22](#major-changes-in-spfx-122)
3. [Environment Setup](#environment-setup)
4. [Your First Web Part](#your-first-web-part)
5. [Modern React Development](#modern-react-development)
6. [Working with SharePoint Data](#working-with-sharepoint-data)
7. [CI/CD Pipelines](#cicd-pipelines)
8. [Deployment Strategies](#deployment-strategies)
9. [Maintenance Best Practices](#maintenance-best-practices)
10. [Common Issues & Troubleshooting](#common-issues--troubleshooting)
11. [Resources & References](#resources--references)

---

## What is SPFx?

**SharePoint Framework (SPFx)** is Microsoft's official development framework for building client-side customizations for SharePoint Online, Microsoft Teams, and Microsoft Viva.

### Key Characteristics
- **Client-side**: Runs in the user's browser (JavaScript/TypeScript)
- **Modern**: Uses modern web technologies (React, TypeScript, Webpack)
- **Secure**: Uses OAuth tokens, no elevated permissions needed
- **Flexible**: Deploy to SharePoint, Teams, Viva, or Outlook
- **Responsive**: Works across devices (desktop, mobile, tablet)

### What You Can Build
- **Web Parts**: Visual components that users can add to pages
- **Extensions**: Customize SharePoint UI (headers, footers, commands)
- **Teams Tabs**: Personal or team tabs in Microsoft Teams
- **Viva Connections**: Dashboard cards and quick views

---

## Major Changes in SPFx 1.22

### 🔥 Critical: New Build System (Heft)

**Why This Matters**: Tutorials from 2023 and earlier use Gulp-based builds. SPFx 1.22 completely replaced this with Heft.

#### What Changed
| Old (SPFx ≤ 1.21) | New (SPFx ≥ 1.22) |
|-------------------|-------------------|
| Gulp-based toolchain | Heft-based toolchain (RushStack) |
| `gulp bundle`, `gulp package-solution` | `heft build`, `heft package` |
| Configured via `gulpfile.js` | Configured via `config/` files |
| TypeScript 4.x | TypeScript 5.8+ |
| Node.js 16-18 | Node.js 22 LTS |
| npm audit issues | Clean installs (no vulnerabilities) |

#### Key Benefits
- **Faster builds**: Heft is optimized for performance
- **Better caching**: Incremental builds are much faster
- **Modern tooling**: Uses latest TypeScript, ESLint, Jest
- **Cleaner projects**: No npm vulnerabilities in scaffolded projects

#### Migration Note
If you have an existing SPFx project on v1.21 or earlier:
- **Option 1**: Continue using Gulp (legacy support maintained)
- **Option 2**: Upgrade and migrate to Heft (recommended for new work)

---

## Environment Setup

### Prerequisites

#### 1. Install Node.js v22 LTS
```bash
# Download from https://nodejs.org/
# Or use Node Version Manager (NVM) - HIGHLY RECOMMENDED

# Linux/Mac with NVM:
nvm install 22
nvm use 22

# Windows with NVM-Windows:
nvm install 22.0.0
nvm use 22.0.0

# Verify installation:
node --version  # Should show v22.x.x
npm --version   # Should show v10.x.x or higher
```

**Why NVM?** Different SPFx versions require different Node versions. NVM lets you switch easily.

#### 2. Install Global Tools
```bash
# Install Yeoman (scaffolding tool)
npm install -g yo

# Install SPFx Yeoman generator
npm install -g @microsoft/generator-sharepoint

# Install Heft CLI (build tool)
npm install -g @rushstack/heft

# Verify installations:
yo --version
yo @microsoft/sharepoint --version
heft --version
```

#### 3. Recommended: Install Additional Tools
```bash
# CLI for Microsoft 365 (for deployment and management)
npm install -g @pnp/cli-microsoft365

# Gulp CLI (if working with legacy projects)
npm install -g gulp-cli
```

### Development Environment

#### Recommended IDE: Visual Studio Code
```bash
# Install VS Code extensions:
# - ESLint
# - SharePoint Framework Snippets
# - TypeScript Hero
# - GitLens
```

#### Optional: Set up a Dev Certificate (for local HTTPS)
```bash
# Trust the development certificate (needed for local testing)
npx @rushstack/heft trust-dev-cert
```

---

## Your First Web Part

### Step 1: Scaffold a New Project

```bash
# Create a new directory
mkdir my-first-webpart
cd my-first-webpart

# Run the Yeoman generator
yo @microsoft/sharepoint
```

#### Generator Prompts (SPFx 1.22)
```
? What is your solution name? my-first-webpart
? Which type of client-side component to create? WebPart
? What is your Web part name? HelloWorld
? Which template would you like to use? React
? Do you want to use a JavaScript framework? Yes, React
```

### Step 2: Understand the Project Structure

```
my-first-webpart/
├── .heft/                      # Heft configuration (new in 1.22)
├── .vscode/                    # VS Code settings
├── config/                     # Build configurations
│   ├── config.json            # General project config
│   ├── deploy-azure-storage.json
│   ├── package-solution.json  # App package config
│   ├── serve.json             # Dev server config
│   └── write-manifests.json
├── src/
│   └── webparts/
│       └── helloWorld/
│           ├── HelloWorldWebPart.manifest.json
│           ├── HelloWorldWebPart.ts        # Main web part class
│           ├── components/
│           │   ├── HelloWorld.tsx          # React component
│           │   ├── HelloWorld.module.scss  # Styles
│           │   └── IHelloWorldProps.ts     # TypeScript interface
│           └── loc/                        # Localization files
├── teams/                      # Teams manifest
├── .gitignore
├── .yo-rc.json                # Yeoman config
├── gulpfile.js                # Gulp compatibility layer
├── package.json               # Dependencies
├── README.md
└── tsconfig.json              # TypeScript config
```

### Step 3: Build and Test Locally

```bash
# Install dependencies
npm install

# Start the local development server
npm run serve
# Or: heft serve --debug

# This opens: https://localhost:5432/workbench.html
```

#### What Happens?
1. Heft compiles TypeScript → JavaScript
2. Bundles with Webpack
3. Starts local dev server on port 5432
4. Opens SharePoint Workbench (local testing environment)

### Step 4: Test in SharePoint Online

```bash
# Build for production
npm run build
# Or: heft build --production

# Package the solution
npm run package
# Or: heft package

# This creates: sharepoint/solution/my-first-webpart.sppkg
```

#### Deploy to SharePoint
1. Go to your SharePoint Admin Center
2. Navigate to **More features** > **Apps** > **Open**
3. Click **App Catalog** (if you don't have one, create it)
4. Upload `my-first-webpart.sppkg`
5. Click **Deploy**

#### Add to a Page
1. Go to any SharePoint site
2. Create or edit a modern page
3. Click **+ Add web part**
4. Find your "HelloWorld" web part
5. Add it to the page

---

## Modern React Development

### Why React with SPFx?

React is the recommended framework for SPFx development:
- **Component-based**: Reusable, modular code
- **Declarative**: Easy to understand and maintain
- **Large ecosystem**: Tons of libraries and tools
- **Microsoft recommended**: Best support and examples

### Class Components vs. Functional Components

#### ❌ Old Way (Class Components)
```typescript
import * as React from 'react';

export default class HelloWorld extends React.Component<IHelloWorldProps, {}> {
  public render(): React.ReactElement<IHelloWorldProps> {
    return (
      <div>
        <h1>Hello, {this.props.userName}!</h1>
      </div>
    );
  }
}
```

#### ✅ New Way (Functional Components + Hooks)
```typescript
import * as React from 'react';
import { useState, useEffect } from 'react';

const HelloWorld: React.FC<IHelloWorldProps> = (props) => {
  const [userName, setUserName] = useState('');

  useEffect(() => {
    setUserName(props.userName);
  }, [props.userName]);

  return (
    <div>
      <h1>Hello, {userName}!</h1>
    </div>
  );
};

export default HelloWorld;
```

### Essential React Hooks for SPFx

#### 1. useState - Managing Component State
```typescript
import { useState } from 'react';

const MyComponent: React.FC = () => {
  const [count, setCount] = useState(0);
  const [items, setItems] = useState<string[]>([]);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  );
};
```

#### 2. useEffect - Side Effects (API Calls, etc.)
```typescript
import { useEffect, useState } from 'react';

const MyComponent: React.FC = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // This runs when component mounts
    fetchData();
  }, []); // Empty array = run once

  useEffect(() => {
    // This runs when 'data' changes
    console.log('Data updated:', data);
  }, [data]); // Dependency array

  const fetchData = async () => {
    setLoading(true);
    const result = await fetch('/api/data');
    setData(await result.json());
    setLoading(false);
  };

  if (loading) return <div>Loading...</div>;
  return <div>{JSON.stringify(data)}</div>;
};
```

#### 3. useCallback - Optimizing Performance
```typescript
import { useCallback, useState } from 'react';

const MyComponent: React.FC = () => {
  const [count, setCount] = useState(0);

  // Memoized callback - won't recreate on every render
  const handleClick = useCallback(() => {
    setCount(prev => prev + 1);
  }, []); // Dependencies

  return <button onClick={handleClick}>Count: {count}</button>;
};
```

#### 4. useMemo - Expensive Calculations
```typescript
import { useMemo, useState } from 'react';

const MyComponent: React.FC<{ items: number[] }> = ({ items }) => {
  const [filter, setFilter] = useState('');

  // Only recalculate when 'items' or 'filter' change
  const filteredItems = useMemo(() => {
    return items.filter(item => item.toString().includes(filter));
  }, [items, filter]);

  return <div>{filteredItems.length} filtered items</div>;
};
```

---

## Working with SharePoint Data

### Option 1: SharePoint REST API (Native)

```typescript
import { SPHttpClient, SPHttpClientResponse } from '@microsoft/sp-http';

// In your web part class:
private async getListItems(): Promise<any[]> {
  try {
    const response: SPHttpClientResponse = await this.context.spHttpClient.get(
      `${this.context.pageContext.web.absoluteUrl}/_api/web/lists/getbytitle('MyList')/items`,
      SPHttpClient.configurations.v1
    );

    if (response.ok) {
      const data = await response.json();
      return data.value;
    }
  } catch (error) {
    console.error('Error fetching list items:', error);
    return [];
  }
}
```

### Option 2: PnPjs Library (Recommended)

PnPjs provides a cleaner, more intuitive API for SharePoint operations.

#### Install PnPjs
```bash
npm install @pnp/sp @pnp/graph @pnp/core
```

#### Setup (in your web part)
```typescript
import { spfi, SPFx } from '@pnp/sp';
import '@pnp/sp/webs';
import '@pnp/sp/lists';
import '@pnp/sp/items';

// In your web part's onInit():
protected async onInit(): Promise<void> {
  await super.onInit();

  // Initialize PnPjs with SPFx context
  this.sp = spfi().using(SPFx(this.context));
}

// Use in your component:
private async getListItems(): Promise<any[]> {
  try {
    const items = await this.sp.web.lists
      .getByTitle('MyList')
      .items
      .select('Title', 'Modified', 'Author/Title')
      .expand('Author')
      .top(100)();

    return items;
  } catch (error) {
    console.error('Error fetching items:', error);
    return [];
  }
}
```

#### Common PnPjs Operations

```typescript
// GET: Read items
const items = await sp.web.lists.getByTitle('MyList').items();

// POST: Create item
await sp.web.lists.getByTitle('MyList').items.add({
  Title: 'New Item',
  Description: 'Item description'
});

// PATCH: Update item
await sp.web.lists.getByTitle('MyList').items.getById(1).update({
  Title: 'Updated Title'
});

// DELETE: Delete item
await sp.web.lists.getByTitle('MyList').items.getById(1).delete();

// Search
const results = await sp.search({
  Querytext: 'keyword',
  RowLimit: 10,
  SelectProperties: ['Title', 'Path', 'Author']
});
```

### Passing Context to React Components

#### Method 1: Props (Simple)
```typescript
// In web part:
public render(): void {
  const element: React.ReactElement<IMyProps> = React.createElement(
    MyComponent,
    {
      context: this.context,
      sp: this.sp
    }
  );
  ReactDom.render(element, this.domElement);
}

// In component:
const MyComponent: React.FC<IMyProps> = ({ context, sp }) => {
  const [items, setItems] = useState([]);

  useEffect(() => {
    sp.web.lists.getByTitle('MyList').items().then(setItems);
  }, []);

  return <div>...</div>;
};
```

#### Method 2: React Context (Advanced)
```typescript
// Create context file:
import { createContext } from 'react';
import { WebPartContext } from '@microsoft/sp-webpart-base';

export const SPContext = createContext<WebPartContext | undefined>(undefined);

// In web part:
public render(): void {
  const element = (
    <SPContext.Provider value={this.context}>
      <MyComponent />
    </SPContext.Provider>
  );
  ReactDom.render(element, this.domElement);
}

// In any component:
import { useContext } from 'react';
import { SPContext } from './SPContext';

const MyComponent: React.FC = () => {
  const context = useContext(SPContext);

  // Use context.spHttpClient, context.pageContext, etc.
};
```

---

## CI/CD Pipelines

### Why CI/CD for SPFx?

- **Consistency**: Same build process every time
- **Automation**: Deploy with a click or on commit
- **Testing**: Run tests before deployment
- **Quality**: Enforce code standards (linting, formatting)
- **Tracking**: Know what's deployed where

### Pipeline Stages

Typical SPFx CI/CD pipeline:

```
1. Source Control (git push)
   ↓
2. Install Dependencies (npm install)
   ↓
3. Lint & Test (eslint, jest)
   ↓
4. Build (heft build)
   ↓
5. Package (heft package)
   ↓
6. Upload to App Catalog
   ↓
7. Deploy to Sites
```

### Option 1: Azure DevOps

See the detailed Azure DevOps pipeline configuration in this repository.

Key features:
- Multi-stage pipelines (Build → Deploy)
- Environment approvals
- Release gates
- Integration with Azure

### Option 2: GitHub Actions

See the detailed GitHub Actions workflow in this repository.

Key features:
- Simpler YAML syntax
- GitHub-native
- Free for public repos
- Federated identity support (no secrets!)

### Modern Authentication: Federated Identities

**Old Way**: Store username/password or certificates as secrets
- Secrets expire and need rotation
- Security risk if leaked

**New Way**: Use federated identities (OpenID Connect)
- No secrets stored
- GitHub/Azure talks directly to Microsoft 365
- More secure, less maintenance

#### Setup for GitHub Actions (2025 Recommended)

```bash
# Install CLI for Microsoft 365
npm install -g @pnp/cli-microsoft365

# Login to your tenant
m365 login

# Create Azure AD app with federated credentials
m365 aad app add --name "GitHub SPFx Deployment" \
  --withSecret \
  --grantAdminConsent \
  --apisDelegated "https://microsoft.sharepoint-df.com/AllSites.FullControl"

# Configure federated identity
m365 aad app set --appId <APP_ID> \
  --federatedIdentityCredentials \
  "[{
    \"name\": \"github-federation\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:your-org/your-repo:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }]"
```

---

## Deployment Strategies

### Manual Deployment

**When to Use**: Development, testing, one-off deployments

```bash
# 1. Build and package
npm run build
npm run package

# 2. Upload to App Catalog
# - Go to SharePoint Admin Center
# - Apps → App Catalog → Upload
# - Select .sppkg file

# 3. Deploy to site
# - Go to site
# - Settings → Add an app
# - Select your app
```

### Automated Deployment with CLI

**When to Use**: Regular deployments, multiple sites

```bash
# Install CLI for Microsoft 365
npm install -g @pnp/cli-microsoft365

# Login
m365 login --authType browser

# Upload to tenant app catalog
m365 spo app add --filePath ./sharepoint/solution/my-app.sppkg --appCatalogScope tenant --overwrite

# Deploy the app
m365 spo app deploy --name my-app.sppkg --appCatalogScope tenant

# Install to site
m365 spo app install --name my-app.sppkg --siteUrl https://tenant.sharepoint.com/sites/mysite
```

### Tenant-wide Deployment

**When to Use**: Apps used across entire organization

```json
// In config/package-solution.json
{
  "solution": {
    "skipFeatureDeployment": true  // Enable tenant-wide deployment
  }
}
```

Benefits:
- Users don't need to install the app
- Web parts immediately available on all sites
- Easier to manage at scale

---

## Maintenance Best Practices

### Version Management

#### Semantic Versioning (SemVer)
```
version: MAJOR.MINOR.PATCH
Example: 1.2.3

MAJOR: Breaking changes (1.x.x → 2.0.0)
MINOR: New features, backwards compatible (1.2.x → 1.3.0)
PATCH: Bug fixes (1.2.3 → 1.2.4)
```

#### Update version in package-solution.json
```json
{
  "solution": {
    "name": "my-app",
    "version": "1.2.3.0",  // SPFx uses 4-part versioning
    "includeClientSideAssets": true
  }
}
```

### Dependency Updates

```bash
# Check for outdated packages
npm outdated

# Update SPFx generator
npm update -g @microsoft/generator-sharepoint

# Update project dependencies (careful!)
npm update --save

# Audit for vulnerabilities
npm audit
npm audit fix
```

### Code Quality

#### ESLint Configuration
```json
// .eslintrc.js
module.exports = {
  extends: ['@microsoft/eslint-config-spfx/lib/profiles/react'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn',
    'no-console': 'warn'
  }
};
```

#### Pre-commit Hooks
```bash
# Install husky
npm install --save-dev husky

# Add to package.json
{
  "husky": {
    "hooks": {
      "pre-commit": "npm run lint && npm test"
    }
  }
}
```

### Monitoring & Logging

```typescript
import { Log } from '@microsoft/sp-core-library';

const LOG_SOURCE = 'MyWebPart';

// Info logging
Log.info(LOG_SOURCE, 'Component loaded successfully');

// Warning
Log.warn(LOG_SOURCE, 'API call took longer than expected', this.context.pageContext.legacyPageContext);

// Error
try {
  // risky operation
} catch (error) {
  Log.error(LOG_SOURCE, error as Error, this.context.pageContext.legacyPageContext);
}
```

### Performance Optimization

```typescript
// 1. Lazy loading
const MyHeavyComponent = React.lazy(() => import('./MyHeavyComponent'));

// 2. Code splitting
// Webpack will automatically split at dynamic imports
const loadModule = async () => {
  const module = await import('./HeavyModule');
  return module.default;
};

// 3. Memoization
const ExpensiveComponent = React.memo(({ data }) => {
  // Component logic
});

// 4. Minimize bundle size
// Check with: npm run build -- --analyze
```

---

## Common Issues & Troubleshooting

### Issue 1: "gulp: command not found"

**Cause**: SPFx 1.22 uses Heft, not Gulp
**Solution**: Use `heft` commands or `npm run` scripts
```bash
# Old: gulp bundle
# New: heft build

# Old: gulp package-solution
# New: heft package
```

### Issue 2: "Certificate not trusted" (localhost)

**Cause**: Development certificate not installed
**Solution**:
```bash
npx @rushstack/heft trust-dev-cert
```

### Issue 3: "Module not found" after npm install

**Cause**: Node modules cache issue
**Solution**:
```bash
rm -rf node_modules
rm package-lock.json
npm cache clean --force
npm install
```

### Issue 4: Build fails with TypeScript errors

**Cause**: Version mismatch or type definitions
**Solution**:
```bash
# Install/update type definitions
npm install --save-dev @types/react @types/react-dom

# Check TypeScript version matches SPFx requirements
npm list typescript
```

### Issue 5: Changes not reflected in SharePoint

**Cause**: Browser cache or CDN delay
**Solution**:
```bash
# 1. Hard refresh browser (Ctrl+Shift+R / Cmd+Shift+R)
# 2. Clear browser cache
# 3. Add version query string to test: ?version=1.2.3
# 4. Update solution version in package-solution.json
```

### Issue 6: Deployment fails - "App already exists"

**Solution**:
```bash
# Add --overwrite flag
m365 spo app add --filePath ./solution.sppkg --overwrite

# Or remove existing version first
m365 spo app remove --name my-app.sppkg
```

---

## Resources & References

### Official Microsoft Documentation
- [SPFx Documentation](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/sharepoint-framework-overview)
- [SPFx 1.22 Release Notes](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/release-1.22)
- [SPFx Roadmap](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/roadmap)
- [Heft Build System](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/toolchain/sharepoint-framework-toolchain-rushstack-heft)

### Community Resources
- [PnP Samples](https://pnp.github.io/sp-dev-fx-webparts/) - 500+ web part examples
- [PnP Weekly](https://pnpweekly.podbean.com/) - Weekly podcast
- [Voitanos Blog](https://www.voitanos.io/blog/) - Expert SPFx tutorials
- [M365Princess Blog](https://www.m365princess.com/) - Luise Freese's tutorials

### Tools & Libraries
- [PnPjs](https://pnp.github.io/pnpjs/) - Simplified SharePoint API
- [CLI for Microsoft 365](https://pnp.github.io/cli-microsoft365/) - Command-line management
- [SPFx Controls](https://pnp.github.io/sp-dev-fx-controls-react/) - Reusable React controls
- [Fluent UI](https://developer.microsoft.com/en-us/fluentui) - Microsoft's React UI library

### Stay Updated
- [Microsoft 365 Developer Blog](https://devblogs.microsoft.com/microsoft365dev/)
- [SPFx GitHub Repository](https://github.com/SharePoint/sp-dev-docs)
- Twitter: Follow #SPFx hashtag
- [Microsoft 365 & Power Platform Community](https://pnp.github.io/)

---

## Next Steps

1. **Set up your environment** using the instructions above
2. **Create your first web part** following the tutorial
3. **Explore the sample project** in this repository
4. **Set up a CI/CD pipeline** for automated deployments
5. **Join the community** - ask questions, share learnings

### Recommended Learning Path

**Week 1: Basics**
- Install tools and create Hello World web part
- Understand project structure
- Deploy to SharePoint manually

**Week 2: React & TypeScript**
- Convert class components to functional
- Practice with hooks (useState, useEffect)
- Build a simple CRUD web part

**Week 3: SharePoint Integration**
- Learn PnPjs library
- Work with lists and libraries
- Handle permissions and errors

**Week 4: CI/CD**
- Set up GitHub Actions or Azure DevOps
- Automate builds and deployments
- Practice version management

**Ongoing**
- Follow PnP samples for inspiration
- Contribute to community
- Stay updated with monthly releases

---

## Questions?

- Check the [Troubleshooting](#common-issues--troubleshooting) section
- Search [Stack Overflow](https://stackoverflow.com/questions/tagged/spfx) with `spfx` tag
- Ask in [Microsoft Tech Community](https://techcommunity.microsoft.com/t5/sharepoint-developer/bd-p/SharePointDev)
- Review sample code in this repository

---

**Last Updated**: January 2026
**SPFx Version**: 1.22.x
**Node Version**: 22.x LTS

Happy coding! 🚀
