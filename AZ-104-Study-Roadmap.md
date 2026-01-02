# AZ-104 Azure Administrator Study Roadmap
> 90-Day Certification Plan | Updated January 2026

## 🎯 Goal
Pass the Microsoft AZ-104 (Azure Administrator Associate) certification exam while building a practical Azure portfolio.

---

## 📊 Exam Overview

**Exam Details:**
- **Code:** AZ-104
- **Duration:** 120 minutes
- **Questions:** 40-60 (multiple choice, drag-drop, case studies)
- **Passing Score:** 700/1000 (~70%)
- **Cost:** $165 USD
- **Renewal:** Annual (free)

**Skills Measured:**

| Domain | Weight | Key Topics |
|--------|--------|------------|
| **Manage Azure Identities & Governance** | 15-20% | Azure AD, RBAC, Azure Policy, Subscriptions |
| **Implement & Manage Storage** | 15-20% | Storage Accounts, Blob, Files, Backup |
| **Deploy & Manage Compute** | 20-25% | VMs, Containers, App Service |
| **Configure & Manage Networking** | 20-25% | VNets, NSGs, Load Balancers, DNS |
| **Monitor & Maintain Resources** | 10-15% | Azure Monitor, Backup, Cost Management |

---

## 📅 12-Week Study Plan

### **Phase 1: Foundation (Weeks 1-4)**
**Goal:** Complete all Microsoft Learn modules + basic hands-on labs

#### Week 1: Prerequisites & Identity
**Study (10 hours):**
- [ ] Microsoft Learn: "Prerequisites for Azure administrators"
- [ ] Microsoft Learn: "Manage identities and governance in Azure"
- [ ] Learn Azure AD basics: users, groups, roles

**Hands-On Labs (5 hours):**
- [ ] Create Azure free account ($200 credit)
- [ ] Navigate Azure Portal - explore interface
- [ ] Create resource groups with tags
- [ ] Create Azure AD users and groups
- [ ] Assign RBAC roles (Reader, Contributor)

**Deliverable:** Resource group structure with proper RBAC

---

#### Week 2: Governance & Policy
**Study (10 hours):**
- [ ] Microsoft Learn: "Implement and manage storage in Azure"
- [ ] Azure Policy documentation
- [ ] Management groups and subscriptions
- [ ] Cost management basics

**Hands-On Labs (5 hours):**
- [ ] Create Azure Policy (require tags on resources)
- [ ] Apply policy to resource group
- [ ] Set up budget alerts
- [ ] Create management group hierarchy

**Deliverable:** Governance structure with policies enforced

---

#### Week 3: Storage Solutions
**Study (10 hours):**
- [ ] Microsoft Learn: Storage accounts deep dive
- [ ] Blob storage, Azure Files, access tiers
- [ ] Storage security and access control
- [ ] Backup and redundancy options

**Hands-On Labs (5 hours):**
- [ ] Create storage account (Standard, Premium)
- [ ] Upload blobs, configure access tiers
- [ ] Create Azure Files share
- [ ] Mount file share as network drive
- [ ] Configure soft delete and versioning

**Deliverable:** Multi-tier storage solution with file sharing

---

#### Week 4: Virtual Machines
**Study (10 hours):**
- [ ] Microsoft Learn: "Deploy and manage compute resources"
- [ ] VM sizing, availability sets
- [ ] Managed disks and snapshots
- [ ] VM extensions and custom script

**Hands-On Labs (5 hours):**
- [ ] Deploy Windows Server VM
- [ ] Deploy Linux VM
- [ ] Configure VM size/disk
- [ ] Create VM snapshot
- [ ] Install IIS via Custom Script Extension

**Deliverable:** Two VMs (Windows + Linux) with web server

**📝 Phase 1 Checkpoint:** Review all modules, take notes on weak areas

---

### **Phase 2: Advanced Topics (Weeks 5-8)**
**Goal:** Master networking, containers, and monitoring

#### Week 5: Virtual Networking
**Study (12 hours):**
- [ ] Microsoft Learn: "Configure and manage virtual networking"
- [ ] VNets, subnets, IP addressing
- [ ] Network Security Groups (NSGs)
- [ ] Service endpoints, private endpoints

**Hands-On Labs (6 hours):**
- [ ] Create VNet with multiple subnets
- [ ] Configure NSG rules (allow HTTP, block SSH)
- [ ] Peer two VNets
- [ ] Test connectivity between VMs
- [ ] Configure UDR (User Defined Routes)

**Deliverable:** Multi-subnet network with NSG rules

---

#### Week 6: Load Balancing & DNS
**Study (12 hours):**
- [ ] Azure Load Balancer vs Application Gateway
- [ ] Azure DNS, Traffic Manager
- [ ] VNet integration and hybrid connectivity

**Hands-On Labs (6 hours):**
- [ ] Create Load Balancer for two VMs
- [ ] Configure health probes
- [ ] Set up Azure DNS zone
- [ ] Create DNS records
- [ ] Test load balancing with web requests

**Deliverable:** Load-balanced web application

---

#### Week 7: Containers & App Services
**Study (10 hours):**
- [ ] Azure Container Instances (ACI)
- [ ] Azure App Service plans
- [ ] Deployment slots, scaling

**Hands-On Labs (6 hours):**
- [ ] Deploy container to ACI
- [ ] Create App Service (Web App)
- [ ] Configure deployment slots (staging/production)
- [ ] Enable auto-scaling
- [ ] Deploy sample app from GitHub

**Deliverable:** Containerized app + Web App with staging slot

---

#### Week 8: Monitoring & Backup
**Study (10 hours):**
- [ ] Microsoft Learn: "Monitor and maintain Azure resources"
- [ ] Azure Monitor, Log Analytics
- [ ] Alerts and action groups
- [ ] Azure Backup, Site Recovery

**Hands-On Labs (6 hours):**
- [ ] Create Log Analytics workspace
- [ ] Configure VM monitoring
- [ ] Set up alerts (CPU > 80%)
- [ ] Configure Azure Backup for VM
- [ ] Perform backup and restore test

**Deliverable:** Complete monitoring solution with backup

**📝 Phase 2 Checkpoint:** Can you deploy a full environment from scratch?

---

### **Phase 3: Practice & Portfolio (Weeks 9-12)**
**Goal:** Practice exams + build portfolio projects

#### Week 9: Practice Exams - Round 1
**Study (5 hours):**
- [ ] Review ALL modules quickly (speed review)
- [ ] Create flashcards for key concepts
- [ ] Review Azure CLI/PowerShell commands

**Practice (10 hours):**
- [ ] Microsoft Official Practice Assessment (FREE)
- [ ] Whizlabs Practice Test 1 (if purchased)
- [ ] Review ALL wrong answers
- [ ] Document weak areas

**Target Score:** 70%+ (if not, extend study 2 weeks)

---

#### Week 10: Hands-On Portfolio Project
**Project: End-to-End Azure Deployment**

Build a complete solution demonstrating all AZ-104 skills:

**Requirements:**
- [ ] Resource groups with tags and RBAC
- [ ] VNet with 3 subnets (web, app, data)
- [ ] 2 VMs behind Load Balancer (web tier)
- [ ] Storage account with blob/files
- [ ] Azure Backup configured
- [ ] NSG rules for security
- [ ] Azure Policy enforcement
- [ ] Monitoring and alerts

**Deliverable:**
- Infrastructure deployed in Azure
- Bicep/ARM template for deployment
- Documentation in Portfolio-Man/Azure/

**Time:** 15-20 hours

---

#### Week 11: Practice Exams - Round 2
**Study (5 hours):**
- [ ] Review weak areas from Week 9
- [ ] Deep dive into commonly tested topics
- [ ] Memorize: VM sizes, storage types, NSG rules

**Practice (10 hours):**
- [ ] Microsoft Practice Assessment (retake)
- [ ] Whizlabs Practice Test 2
- [ ] MeasureUp (if purchased)
- [ ] Review explanations thoroughly

**Target Score:** 80%+ (if not, delay exam 1 week)

---

#### Week 12: Final Review & Exam
**Monday-Thursday: Final Review**
- [ ] Speed review all Microsoft Learn modules (1 hour each)
- [ ] Practice case studies (exam format)
- [ ] Review Azure pricing calculator
- [ ] Memorize: RBAC roles, VM availability options

**Friday: Pre-Exam Prep**
- [ ] Light review only (don't cram!)
- [ ] Get good sleep (8 hours)
- [ ] Prepare testing environment (if online)

**Saturday/Sunday: EXAM DAY**
- [ ] Take AZ-104 exam
- [ ] Celebrate (you've earned it!)

---

## 📚 Required Resources

### **Free Resources (Core Study):**
- [Microsoft Learn - AZ-104 Learning Path](https://learn.microsoft.com/en-us/credentials/certifications/azure-administrator/) - PRIMARY
- [Azure Free Account](https://azure.microsoft.com/free/) - $200 credit
- [Microsoft Official Practice Assessment](https://learn.microsoft.com/en-us/credentials/certifications/azure-administrator/practice/assessment) - FREE
- [John Savill's AZ-104 Study Cram](https://www.youtube.com/watch?v=VOod_VNgdJk) - YouTube (5 hours)
- [Azure Documentation](https://learn.microsoft.com/en-us/azure/) - Reference

### **Paid Resources (Optional but Valuable):**
- **Whizlabs Practice Tests** (~$20-30) - Budget option
- **MeasureUp Practice Exams** (~$100) - Most realistic
- **Udemy - AZ-104 Course** (~$15 on sale) - Video learners

### **Tools:**
- **Azure CLI** - Install locally for practice
- **Azure PowerShell** - Alternative to CLI
- **Visual Studio Code** - For Bicep/ARM templates
- **Notion/OneNote** - Study notes and flashcards

---

## 🎯 Weekly Time Commitment

**Weeks 1-8 (Study Phase):**
- Weekdays: 1.5-2 hours/day (Mon-Fri = 7.5-10 hours)
- Weekends: 3-4 hours/day (Sat-Sun = 6-8 hours)
- **Total: ~15 hours/week**

**Weeks 9-12 (Practice Phase):**
- Weekdays: 1-2 hours/day (review + practice questions)
- Weekends: 4-6 hours/day (portfolio project + practice)
- **Total: ~15-20 hours/week**

**Grand Total: ~180-200 hours over 12 weeks**

---

## ✅ Success Checklist

### **Before Scheduling Exam:**
- [ ] Completed all Microsoft Learn modules
- [ ] Hands-on experience with ALL Azure services in exam
- [ ] Built at least ONE complete portfolio project
- [ ] Scored 80%+ on practice exams consistently
- [ ] Can explain: RBAC, NSGs, VNets, VM sizing, storage types
- [ ] Comfortable navigating Azure Portal blindfolded

### **Exam Day Strategies:**
- [ ] Read questions CAREFULLY ("most cost-effective" vs "fastest")
- [ ] Eliminate obviously wrong answers first
- [ ] Mark unclear questions for review (come back later)
- [ ] Manage time: ~2 minutes per question max
- [ ] Case studies: Read question FIRST, then scenario
- [ ] Don't overthink - usually straightforward answer is correct

---

## 💰 Budget Breakdown

| Item | Cost |
|------|------|
| Microsoft Learn | FREE |
| Azure Free Account | FREE ($200 credit included) |
| Practice Assessment | FREE |
| Optional: Whizlabs | $20-30 |
| Optional: MeasureUp | $100 |
| **AZ-104 Exam** | **$165** |
| **Total (minimum)** | **$165** |
| **Total (recommended)** | **$185-265** |

**Cost Saving Tips:**
- Delete Azure resources after labs (conserve free credits!)
- Use Azure cost calculator for estimation practice
- Look for Microsoft exam discounts (Cloud Skills Challenge, Microsoft Ignite)
- Check if employer reimburses certification costs

---

## 🚀 Post-Certification Plan

### **Immediately After Passing:**
1. [ ] Update LinkedIn with certification badge
2. [ ] Add to CV: "Microsoft Certified: Azure Administrator Associate"
3. [ ] Publish Azure portfolio projects to Portfolio-Man
4. [ ] Share accomplishment on LinkedIn (with portfolio link)

### **Portfolio Integration:**
Add these to Portfolio-Man/Azure/:
- [ ] `/Resource-Deployment/` - Bicep templates
- [ ] `/Governance/` - Azure Policy examples
- [ ] `/Networking/` - VNet configurations
- [ ] `/Monitoring/` - Alert and dashboard scripts
- [ ] `README.md` - Overview of Azure projects

### **CV Updates:**
```
CERTIFICATIONS
Microsoft Certified: Azure Administrator Associate (AZ-104) | Obtained [Month] 2026

CORE COMPETENCIES
Azure Administration
Azure Virtual Machines • Virtual Networks • Azure Storage • Azure AD • RBAC • Azure Monitor • Load Balancing

Infrastructure as Code
Bicep • ARM Templates • Azure CLI • PowerShell Az Module

PROJECTS
Azure Infrastructure Automation
Designed and deployed multi-tier Azure infrastructure using Bicep templates, including VNets, NSGs, Load Balancers, and VMs. Implemented governance with Azure Policy and RBAC. Configured monitoring and automated backup solutions.
```

---

## 📊 Progress Tracking Template

**Weekly Checklist:**

| Week | Study Hours | Lab Hours | Topics Covered | Practice Score | Status |
|------|-------------|-----------|----------------|----------------|---------|
| 1 | __ / 10 | __ / 5 | Identities, RBAC | N/A | ☐ |
| 2 | __ / 10 | __ / 5 | Governance, Policy | N/A | ☐ |
| 3 | __ / 10 | __ / 5 | Storage Solutions | N/A | ☐ |
| 4 | __ / 10 | __ / 5 | Virtual Machines | N/A | ☐ |
| 5 | __ / 12 | __ / 6 | Virtual Networking | N/A | ☐ |
| 6 | __ / 12 | __ / 6 | Load Balancing, DNS | N/A | ☐ |
| 7 | __ / 10 | __ / 6 | Containers, App Service | N/A | ☐ |
| 8 | __ / 10 | __ / 6 | Monitoring, Backup | N/A | ☐ |
| 9 | __ / 5 | __ / 10 | Practice Exam 1 | __% | ☐ |
| 10 | __ / 5 | __ / 15 | Portfolio Project | N/A | ☐ |
| 11 | __ / 5 | __ / 10 | Practice Exam 2 | __% | ☐ |
| 12 | __ / 5 | __ / 5 | Final Review | N/A | ☐ |

**Exam Date:** _______________
**Result:** ☐ PASS ☐ Need Retake

---

## 🎯 Key Concepts to Master

### **Identity & Governance:**
- Azure AD vs on-premises AD
- RBAC roles: Owner, Contributor, Reader (and when to use each)
- Azure Policy vs RBAC (policy = what can exist, RBAC = who can do what)
- Management groups hierarchy

### **Storage:**
- Blob tiers: Hot, Cool, Archive (costs + use cases)
- Redundancy: LRS, ZRS, GRS, RA-GRS
- Azure Files vs Blob storage (when to use each)
- Storage account types: Standard, Premium

### **Compute:**
- VM availability: Availability Sets vs Availability Zones
- VM sizes: General purpose, Compute optimized, Memory optimized
- Managed disks: Standard HDD, Standard SSD, Premium SSD, Ultra
- VM states and billing (running = charged, stopped/deallocated = not charged for compute)

### **Networking:**
- NSG rules: Priority (100-4096, lower = higher priority)
- VNet peering vs VPN Gateway
- Public IP vs Private IP
- Load Balancer vs Application Gateway vs Traffic Manager

### **Monitoring:**
- Azure Monitor = platform metrics
- Log Analytics = query logs
- Alerts = automated notifications
- Service Health vs Resource Health

---

## 💡 Pro Tips

**Study Tips:**
- ✅ **Hands-on beats reading** - Do EVERY lab, don't just read
- ✅ **Take notes in your own words** - Don't copy-paste
- ✅ **Use flashcards for memorization** - VM sizes, storage types, etc.
- ✅ **Teach concepts out loud** - If you can't explain it, you don't know it
- ✅ **Join study communities** - Reddit r/AzureCertification, Discord servers

**Lab Tips:**
- ✅ **Delete resources after labs!** - Conserve free credits
- ✅ **Use Azure Calculator** - Estimate costs before deploying
- ✅ **Document your labs** - Screenshots for portfolio
- ✅ **Break things intentionally** - Best way to learn troubleshooting
- ✅ **Practice with CLI AND Portal** - Exam tests both

**Exam Tips:**
- ✅ **Read full question before answering** - Keywords matter!
- ✅ **"Most cost-effective" ≠ "fastest"** - Understand what they're asking
- ✅ **Mark and review** - Don't waste time on hard questions initially
- ✅ **Case studies: question first** - Don't read the whole scenario first
- ✅ **Trust your first instinct** - Don't overthink (usually)

---

## 🎓 After AZ-104: What's Next?

**Immediate Next Steps (0-3 months):**
1. Build 2-3 more Azure projects for portfolio
2. Apply for Azure Administrator / Cloud Engineer roles
3. Update salary expectations (AZ-104 = +$5k-10k)

**Next Certification (3-6 months):**
- **AZ-204** (Azure Developer) - If you want development path
- **AZ-400** (DevOps Engineer) - If you want DevOps path
- **SC-300** (Identity & Access Admin) - If you want security/identity path
- **AZ-500** (Security Engineer) - If you want security path

**Recommended Path:** AZ-400 (DevOps Engineer)
- Builds on AZ-104
- Opens DevOps roles
- Aligns with your GitHub Actions experience
- High demand + good salaries

---

## 📞 Support & Community

**Official Resources:**
- Microsoft Learn Discord
- Microsoft Tech Community Forums
- Azure Friday YouTube channel

**Study Communities:**
- Reddit: r/AzureCertification
- Discord: Microsoft Certification Study Group
- LinkedIn: Azure Administrator Study Groups

**Questions?**
- Stack Overflow (azure tag)
- Microsoft Q&A
- Your study notes in Portfolio-Man!

---

**Good luck! You've got this! 🚀**

*Remember: Certification is not the destination - it's a checkpoint on your journey to cloud mastery.*
