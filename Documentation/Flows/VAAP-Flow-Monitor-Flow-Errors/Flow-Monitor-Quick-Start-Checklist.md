# Flow Error Monitor - Quick Start Checklist

Use this checklist while building your flow monitoring solution. Check off each step as you complete it.

## Pre-Build Preparation

### Prerequisites Check
- [ ] I have Power Automate Premium license
- [ ] I have Environment Maker role or higher
- [ ] I can access the environment I want to monitor
- [ ] I've identified 2-3 flows to monitor for testing

### Gather Required Information

**Flow IDs to Monitor:**
```
Flow 1:
  Name: _____________________________
  ID: _________________________________
  Environment ID: _____________________

Flow 2:
  Name: _____________________________
  ID: _________________________________
  Environment ID: _____________________
```

**How to Get Flow ID:**
1. Open the flow in Power Automate
2. Copy from URL: `.../flows/[COPY-THIS-PART]/details`

**How to Get Environment ID:**
1. Go to Power Automate settings (gear icon)
2. Session details
3. Copy Environment ID

**Alert Configuration:**
```
Alert Email: _________________________
Alert Frequency: Every _____ minutes
Teams Channel (optional): ____________
```

---

## Build Steps (Phase 1: Basic Monitor)

### Step 1: Create Flow
- [ ] Go to https://make.powerautomate.com
- [ ] Click "+ Create" → "Automated cloud flow" → "Skip"
- [ ] Name: `Monitor Critical Flows - Production`

### Step 2: Add Recurrence Trigger
- [ ] Search for "Recurrence"
- [ ] Set interval: `15` minutes
- [ ] Set timezone: `_____________`

### Step 3: Initialize Variables

**Variable 1: FlowsToMonitor**
- [ ] Action: "Initialize variable"
- [ ] Name: `FlowsToMonitor`
- [ ] Type: `Array`
- [ ] Value:
```json
[
  {
    "flowId": "YOUR-FLOW-ID-HERE",
    "flowName": "Your Flow Name",
    "environment": "YOUR-ENVIRONMENT-ID"
  }
]
```

**Variable 2: AlertMessages**
- [ ] Action: "Initialize variable"
- [ ] Name: `AlertMessages`
- [ ] Type: `Array`
- [ ] Value: `[]` (empty)

**Variable 3: HasErrors**
- [ ] Action: "Initialize variable"
- [ ] Name: `HasErrors`
- [ ] Type: `Boolean`
- [ ] Value: `false`

### Step 4: Loop Through Flows
- [ ] Action: "Apply to each"
- [ ] Select: `FlowsToMonitor`

### Step 5: Get Flow Runs (Inside Loop)
- [ ] Action: "List flow runs as Admin" (Power Automate Management)
- [ ] Environment: Expression `item()?['environment']`
- [ ] Flow Name: Expression `item()?['flowId']`
- [ ] Top Count: `20`

### Step 6: Filter Failed Runs
- [ ] Action: "Filter array"
- [ ] From: `value` (from List flow runs)
- [ ] Condition: `Status` is equal to `Failed`

### Step 7: Check for Failures
- [ ] Action: "Condition"
- [ ] Advanced mode: `@greater(length(body('Filter_array')), 0)`

### Step 8: Process Failures (If Yes Branch)

**Add nested loop:**
- [ ] Action: "Apply to each"
- [ ] Select: Output from "Filter array"

**Get error details:**
- [ ] Action: "Get flow run as Admin"
- [ ] Environment: Expression `items('Apply_to_each')?['environment']`
- [ ] Flow Name: Expression `items('Apply_to_each')?['name']`
- [ ] Run Name: Expression `items('Apply_to_each_2')?['name']`

**Format error message:**
- [ ] Action: "Compose"
- [ ] Build error message template (see guide for template)

**Save to alert array:**
- [ ] Action: "Append to array variable"
- [ ] Name: `AlertMessages`
- [ ] Value: Output from Compose

**Set error flag:**
- [ ] Action: "Set variable"
- [ ] Name: `HasErrors`
- [ ] Value: `true`

### Step 9: Send Alerts (Outside All Loops)
- [ ] Action: "Condition"
- [ ] Check: `HasErrors` is equal to `true`

**If yes:**
- [ ] Action: "Send an email (V2)"
- [ ] To: Your email
- [ ] Subject: `🚨 Flow Monitoring Alert - Failures Detected`
- [ ] Body: Include joined AlertMessages (see guide)

### Step 10: Save and Test
- [ ] Click "Save"
- [ ] Click "Test" → "Manually" → "Run flow"
- [ ] Verify it completes successfully
- [ ] Check if you received email (if there were failures)

---

## Testing Checklist

### Test 1: Detect Failed Run
- [ ] Create a test flow that fails (e.g., divide by zero)
- [ ] Run the test flow manually
- [ ] Wait 15 minutes or trigger monitor manually
- [ ] Verify alert is received
- [ ] Verify error details are accurate

### Test 2: No False Positives
- [ ] Ensure all monitored flows are running successfully
- [ ] Wait for monitor to run multiple times
- [ ] Verify no alerts are sent
- [ ] Check monitor run history for errors

### Test 3: Multiple Failures
- [ ] Cause 2 different flows to fail
- [ ] Run monitor
- [ ] Verify single alert contains both failures
- [ ] Verify each has unique details

---

## Troubleshooting Quick Reference

### Common Issues

**Problem:** "Flow not found" error
- [ ] Verify Flow ID is correct
- [ ] Verify Environment ID is correct
- [ ] Check permissions

**Problem:** No alerts despite failures
- [ ] Check "Filter array" output (are failures found?)
- [ ] Check condition evaluation (is it entering Yes branch?)
- [ ] Verify email action has correct recipient

**Problem:** Expression errors
- [ ] Check action names match expressions
- [ ] Verify all `?` operators for safe navigation
- [ ] Review expression syntax

**Problem:** Empty run list
- [ ] Verify flow has run history
- [ ] Check if using correct connector (Admin vs non-Admin)
- [ ] Verify permissions

---

## Post-Implementation Checklist

### Week 1
- [ ] Monitor runs successfully every 15 minutes
- [ ] Caught at least one real failure
- [ ] No false positives
- [ ] Team knows how to respond to alerts

### Week 2-4
- [ ] Add 5-10 more flows to monitor
- [ ] Document all monitored flows
- [ ] Optimize alert frequency if needed
- [ ] Consider adding enhancements (Phase 2)

### Month 2
- [ ] Implement historical tracking (SharePoint)
- [ ] Add disabled flow detection
- [ ] Move flow list to SharePoint (dynamic)
- [ ] Start tracking metrics (MTTR, failure rate)

### Month 3
- [ ] Build Power App dashboard
- [ ] Create Power BI reports
- [ ] Expand to 20+ flows
- [ ] Consider cross-environment monitoring

---

## Key Expressions Reference Card

**Print this section and keep it nearby while building:**

```javascript
// Flow properties from outer loop
item()?['flowName']
item()?['flowId']
item()?['environment']

// Run properties
items('Apply_to_each_2')?['name']  // Run ID

// Error details
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']
body('Get_flow_run_as_Admin')?['properties']?['error']?['message']

// Status
body('Get_flow_run_as_Admin')?['properties']?['status']

// Time
body('Get_flow_run_as_Admin')?['properties']?['startTime']

// Array operations
length(variables('AlertMessages'))
join(variables('AlertMessages'), '<br><br>')
greater(length(body('Filter_array')), 0)

// Current time
utcNow()
formatDateTime(utcNow(), 'yyyy-MM-dd HH:mm:ss')
```

---

## Success Criteria

Mark these off as you achieve them:

- [ ] Monitor runs automatically every 15 minutes
- [ ] Detects failures within 15 minutes
- [ ] Alerts contain actionable information
- [ ] No false positives in last 48 hours
- [ ] Caught a production issue before users reported it
- [ ] Team relies on it instead of manual checks
- [ ] Monitor has run successfully for 1 week straight

---

## Next Steps After Phase 1

Once your basic monitor is stable:

**Phase 2 Enhancements (Choose 1-2):**
- [ ] Add disabled flow detection
- [ ] Track consecutive failures
- [ ] Store history in SharePoint
- [ ] Move flow list to SharePoint (dynamic)
- [ ] Teams integration
- [ ] Error categorization

**Phase 3 Advanced Features:**
- [ ] Build Power App dashboard
- [ ] Create Power BI analytics
- [ ] Auto-remediation for common errors
- [ ] Environment-wide monitoring

---

## Quick Links

- Full Implementation Guide: `Flow-Error-Monitor-Implementation-Guide.md`
- Power Automate: https://make.powerautomate.com
- Management Connector Docs: https://learn.microsoft.com/connectors/flowmanagement/
- Expression Reference: https://learn.microsoft.com/power-automate/use-expressions-in-conditions

---

## Notes Section

Use this space for your own notes, Flow IDs, or troubleshooting observations:

```
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
```

---

**Version:** 1.0
**Created:** 2026-01-18
**Status:** Phase 1 Implementation
