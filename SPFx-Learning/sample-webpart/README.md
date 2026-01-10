# SPFx Sample Web Part - Modern React with Hooks

This is a sample SharePoint Framework (SPFx) web part built with modern React patterns, demonstrating best practices for SPFx development in 2025/2026.

## Features

- **Modern React**: Uses functional components with hooks instead of class components
- **PnPjs Integration**: Simplified SharePoint API calls
- **TypeScript 5.8**: Latest TypeScript features
- **Heft Build System**: New SPFx 1.22 build toolchain
- **Proper Error Handling**: Loading states, error states, and retry logic
- **Responsive Design**: Works on desktop and mobile

## Prerequisites

- Node.js v22 LTS
- SharePoint Online tenant
- Global tools:
  ```bash
  npm install -g yo @microsoft/generator-sharepoint @rushstack/heft
  ```

## Building and Testing

### Install Dependencies
```bash
npm install
```

### Run Locally
```bash
npm run serve
```
This will start the local development server at `https://localhost:4321/workbench.html`

### Build for Production
```bash
npm run build
```

### Package for Deployment
```bash
npm run package
```
This creates `solution/spfx-sample-webpart.sppkg` ready for upload to SharePoint.

## Project Structure

```
sample-webpart/
├── config/                         # Configuration files
│   ├── package-solution.json      # App package configuration
│   └── serve.json                 # Dev server configuration
├── src/
│   └── webparts/
│       └── helloWorld/
│           ├── HelloWorldWebPart.ts          # Main web part class
│           ├── components/
│           │   ├── HelloWorld.tsx            # React component (FUNCTIONAL!)
│           │   ├── HelloWorld.module.scss    # Styles
│           │   └── IHelloWorldProps.ts       # Props interface
│           └── loc/                          # Localization
├── package.json                   # Dependencies
└── tsconfig.json                  # TypeScript config
```

## Key Learning Points

### 1. Modern React Patterns

The main component (`HelloWorld.tsx`) demonstrates:
- **Functional components** instead of classes
- **useState** for state management
- **useEffect** for lifecycle events
- **useCallback** for performance optimization

### 2. PnPjs for SharePoint API

Instead of complex SPHttpClient calls, we use PnPjs:
```typescript
const items = await sp.web.lists
  .getByTitle('MyList')
  .items
  .select('Id', 'Title')
  .top(10)();
```

### 3. Proper Error Handling

The component handles three states:
- Loading: Shows spinner while fetching
- Error: Shows error message with retry button
- Success: Shows data

### 4. TypeScript Best Practices

- Strong typing with interfaces
- Type-safe props and state
- No `any` types

## Configuration

After adding the web part to a page, configure it via the property pane:
- **Description**: Custom text to display
- **List Name**: SharePoint list to read from

## Deployment

See the main CI/CD documentation for automated deployment options:
- Azure DevOps Pipeline
- GitHub Actions

Or deploy manually:
1. Build: `npm run build`
2. Package: `npm run package`
3. Upload `solution/*.sppkg` to SharePoint App Catalog
4. Deploy and install on your site

## Learn More

- [Complete SPFx Guide](../SPFX-COMPLETE-GUIDE.md)
- [SPFx Documentation](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/sharepoint-framework-overview)
- [PnPjs Docs](https://pnp.github.io/pnpjs/)

## License

MIT
