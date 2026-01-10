# SharePoint Framework (SPFx) Learning Package

> **Complete learning materials for SPFx development and CI/CD (January 2026)**

This repository contains everything you need to learn modern SharePoint Framework (SPFx) development, including guides, sample code, and CI/CD pipeline configurations - all updated for SPFx 1.22+ released in December 2025.

## 📚 What's Included

### 1. **Complete Learning Guide** 📖
[`SPFX-COMPLETE-GUIDE.md`](./SPFX-COMPLETE-GUIDE.md) - Your comprehensive guide to SPFx 1.22+

- What is SPFx and why use it
- Major changes in SPFx 1.22 (Heft toolchain!)
- Step-by-step environment setup
- Building your first web part
- Modern React patterns with hooks
- Working with SharePoint data (PnPjs)
- CI/CD pipelines
- Deployment strategies
- Maintenance and troubleshooting

### 2. **Sample SPFx Project** 💻
[`sample-webpart/`](./sample-webpart/) - Production-ready web part demonstrating best practices

- **Modern React**: Functional components with hooks (no classes!)
- **PnPjs Integration**: Simplified SharePoint API calls
- **TypeScript 5.8**: Latest TypeScript features
- **Heft Build System**: SPFx 1.22's new toolchain
- **Proper Error Handling**: Loading states, errors, retry logic
- **Fully Commented**: Learn by reading the code

### 3. **CI/CD Pipelines** 🚀
[`cicd/`](./cicd/) - Automated deployment configurations

#### Azure DevOps
- [`azure-devops/azure-pipelines.yml`](./cicd/azure-devops/azure-pipelines.yml)
- [`azure-devops/SETUP-GUIDE.md`](./cicd/azure-devops/SETUP-GUIDE.md)
- Multi-stage pipeline (Build → Dev → Production)
- Certificate-based authentication
- Environment approvals

#### GitHub Actions
- [`github-actions/spfx-cicd.yml`](./cicd/github-actions/spfx-cicd.yml)
- [`github-actions/SETUP-GUIDE.md`](./cicd/github-actions/SETUP-GUIDE.md)
- **Federated Identity** (no secrets to rotate!)
- Parallel jobs for faster builds
- Environment protection rules

### 4. **Helper Scripts** 🛠️
[`scripts/`](./scripts/) - Automation scripts to speed up your workflow

- **`setup-dev-env.sh`**: One-command environment setup
- **`deploy.sh`**: Automated deployment to SharePoint
- **`quick-start.sh`**: Scaffold new projects quickly

---

## 🚀 Quick Start

### Prerequisites

- **Node.js v22 LTS** (critical for SPFx 1.22!)
- npm or yarn
- SharePoint Online tenant (for testing)

### Option 1: Set Up Your Development Environment

```bash
# Run the setup script (installs all tools)
cd scripts
./setup-dev-env.sh
```

This installs:
- Yeoman
- SPFx Yeoman generator
- Heft CLI
- CLI for Microsoft 365
- Development certificates

### Option 2: Try the Sample Project

```bash
# Navigate to the sample project
cd sample-webpart

# Install dependencies
npm install

# Start local dev server
npm run serve

# Open: https://localhost:4321/workbench.html
```

### Option 3: Create Your Own Project

```bash
# Use the quick-start script
cd scripts
./quick-start.sh my-awesome-webpart

# Or manually with Yeoman:
yo @microsoft/sharepoint
```

---

## 📖 Learning Path

### Week 1: Basics
1. Read the [Complete Guide](./SPFX-COMPLETE-GUIDE.md) sections 1-4
2. Set up your development environment
3. Run the sample web part locally
4. Deploy manually to SharePoint

**Goal**: Understand SPFx fundamentals and see a web part in action

### Week 2: React & TypeScript
1. Study the sample project's code
2. Convert class components to functional (see guide)
3. Practice with hooks: `useState`, `useEffect`, `useCallback`
4. Build a simple CRUD web part

**Goal**: Get comfortable with modern React patterns in SPFx

### Week 3: SharePoint Integration
1. Learn PnPjs library
2. Practice reading from SharePoint lists
3. Implement create, update, delete operations
4. Handle permissions and errors gracefully

**Goal**: Master SharePoint data operations

### Week 4: CI/CD
1. Choose your platform (GitHub Actions or Azure DevOps)
2. Follow the setup guide
3. Configure automated deployments
4. Practice version management

**Goal**: Automate your deployment workflow

---

## 🎯 Key Features of This Learning Package

### ✅ Up-to-Date (January 2026)
- Reflects SPFx 1.22 changes (Heft toolchain)
- Node.js 22 LTS
- TypeScript 5.8
- Modern React patterns (hooks, not classes)

### ✅ Beginner-Friendly
- Step-by-step instructions
- Clear explanations of "why", not just "how"
- Common issues and solutions
- No assumptions about prior SPFx knowledge

### ✅ Production-Ready
- Industry best practices
- Security considerations
- Performance optimizations
- Proper error handling

### ✅ Complete CI/CD
- Two platform options (Azure DevOps & GitHub Actions)
- Detailed setup guides
- Modern authentication (federated identity)
- Multi-environment support (dev, prod)

---

## 🛠️ Project Structure

```
SPFx-Learning/
├── SPFX-COMPLETE-GUIDE.md       # 📖 Your main learning resource
├── README.md                     # 📄 This file
│
├── sample-webpart/               # 💻 Working SPFx project
│   ├── src/
│   │   └── webparts/
│   │       └── helloWorld/
│   │           ├── HelloWorldWebPart.ts      # Main web part class
│   │           └── components/
│   │               ├── HelloWorld.tsx        # React component (MODERN!)
│   │               ├── HelloWorld.module.scss
│   │               └── IHelloWorldProps.ts
│   ├── config/                   # SPFx configuration
│   ├── package.json             # Dependencies (Node 22, React 18)
│   └── README.md                # Sample project docs
│
├── cicd/                         # 🚀 CI/CD configurations
│   ├── azure-devops/
│   │   ├── azure-pipelines.yml
│   │   └── SETUP-GUIDE.md
│   └── github-actions/
│       ├── spfx-cicd.yml
│       └── SETUP-GUIDE.md
│
└── scripts/                      # 🛠️ Helper scripts
    ├── setup-dev-env.sh         # Environment setup
    ├── deploy.sh                # Deployment automation
    └── quick-start.sh           # Project scaffolding
```

---

## 🎓 What You'll Learn

### SPFx Fundamentals
- What SPFx is and why it's the official SharePoint development framework
- Project structure and configuration
- Build and packaging process
- Deployment models (tenant-wide vs. per-site)

### Modern Development
- **React Hooks**: `useState`, `useEffect`, `useCallback`, `useMemo`
- **TypeScript**: Strong typing, interfaces, generics
- **Modern Tooling**: Heft (not Gulp!), Webpack 5, ESLint
- **Code Quality**: Linting, formatting, testing

### SharePoint Integration
- Reading data with PnPjs
- CRUD operations on lists
- Search API
- User context and permissions
- Working with files and folders

### CI/CD & DevOps
- Automated builds
- Multi-environment deployments
- Authentication strategies (federated identity!)
- Version management
- Release approvals

---

## 🤔 Why This Matters

### The Problem
Most SPFx tutorials are outdated. They use:
- ❌ Old Node versions (16, 18)
- ❌ Gulp-based builds
- ❌ Class components (pre-hooks React)
- ❌ Manual deployments
- ❌ Expired authentication methods

### The Solution
This learning package uses:
- ✅ Node 22 LTS
- ✅ Heft build system (SPFx 1.22)
- ✅ Functional components with hooks
- ✅ Automated CI/CD pipelines
- ✅ Federated identity (no secrets!)

**Result**: You learn the *current* way to build SPFx apps, not the 2022 way.

---

## 📊 Comparison: Old vs. New

| Aspect | Old Way (≤2023) | New Way (2025/2026) |
|--------|-----------------|---------------------|
| **Node.js** | v16-18 | v22 LTS |
| **Build Tool** | Gulp | Heft (RushStack) |
| **React** | Class components | Functional + Hooks |
| **TypeScript** | 4.x | 5.8 |
| **Auth (CI/CD)** | Client secrets | Federated identity |
| **npm audit** | Tons of warnings | Clean installs |

---

## 🚀 Deployment Options

### Manual Deployment
```bash
cd sample-webpart
npm run build
npm run package
# Upload sharepoint/solution/*.sppkg to App Catalog
```

### Automated with Script
```bash
cd scripts
./deploy.sh dev
./deploy.sh prod --site-url https://tenant.sharepoint.com/sites/mysite
```

### Automated with CI/CD
- **Push to `develop`** → Auto-deploy to Dev
- **Push to `main`** → Manual approval → Deploy to Production

---

## 🔧 Customization

### Update Package Name
In `sample-webpart/config/package-solution.json`:
```json
{
  "solution": {
    "name": "your-app-name",
    "id": "generate-new-guid-here"
  }
}
```

### Add More Web Parts
```bash
cd sample-webpart
yo @microsoft/sharepoint
# Choose "WebPart" and follow prompts
```

### Change SharePoint Site
In CI/CD configs, update site URLs in secrets/variables.

---

## 📚 Additional Resources

### Official Documentation
- [Microsoft SPFx Docs](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/sharepoint-framework-overview)
- [SPFx 1.22 Release Notes](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/release-1.22)
- [Heft Documentation](https://heft.rushstack.io/)

### Community
- [PnP SPFx Samples](https://pnp.github.io/sp-dev-fx-webparts/) - 500+ examples
- [PnP Community](https://pnp.github.io/) - Weekly calls, blog posts
- [Stack Overflow](https://stackoverflow.com/questions/tagged/spfx) - Use `spfx` tag

### Tools
- [PnPjs](https://pnp.github.io/pnpjs/) - Simplified SharePoint API
- [CLI for Microsoft 365](https://pnp.github.io/cli-microsoft365/) - Command-line management
- [Fluent UI](https://developer.microsoft.com/en-us/fluentui) - Microsoft's React components

---

## 🐛 Troubleshooting

### "Certificate not trusted"
```bash
npx @rushstack/heft trust-dev-cert
```

### "Module not found"
```bash
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### "Wrong Node version"
```bash
nvm install 22
nvm use 22
```

### More Issues?
Check the [Troubleshooting section](./SPFX-COMPLETE-GUIDE.md#common-issues--troubleshooting) in the Complete Guide.

---

## 💡 Tips for Success

1. **Start small**: Run the sample project first before creating your own
2. **Read the guide**: Don't skip the fundamentals
3. **Practice daily**: Build something every day, even if small
4. **Join the community**: Ask questions in PnP forums
5. **Use version control**: Commit often, push daily
6. **Set up CI/CD early**: Automate deployments from day one
7. **Keep learning**: SPFx updates every month, stay current

---

## 🤝 Contributing

Found an issue? Have a suggestion? Want to add more examples?

1. Fork this repository
2. Make your changes
3. Submit a pull request

Or open an issue to discuss.

---

## 📝 License

MIT License - Feel free to use this for learning, teaching, or commercial projects.

---

## 🎉 Final Words

SPFx development in 2025/2026 is different from 2-3 years ago. The tooling has evolved significantly (Heft, Node 22, federated identity). This learning package gives you the **modern** approach so you don't have to unlearn old patterns later.

**You've got this!** Work through the guide, experiment with the sample code, and you'll be building production SPFx apps in no time.

Questions? Check the [Complete Guide](./SPFX-COMPLETE-GUIDE.md) or reach out to the PnP community.

Happy coding! 🚀

---

**Last Updated**: January 2026
**SPFx Version**: 1.22.x
**Node Version**: 22.x LTS

**Maintained by**: [Your Name]
**Repository**: [GitHub URL]
