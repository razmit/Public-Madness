# Flow Error Monitor - Complete Implementation Guide

## Overview
This guide will help you build a Power Automate flow that monitors other flows for failures and errors. You'll learn to detect authentication issues, connection failures, and other errors before they impact users.

**What You'll Build:**
- Scheduled monitoring flow (runs every 15 minutes)
- Detects failed flow runs
- Retrieves detailed error messages
- Identifies stopped/disabled flows
- Sends alerts via email or Teams

**Prerequisites:**
- Power Automate Premium license (for Management connector)
- Environment Maker role (minimum)
- Access to the environment you want to monitor
- 2-3 flow IDs to monitor (we'll show you how to get these)

---

## Phase 1: Basic Flow Monitoring (Start Here)

### Step 1: Get Flow IDs to Monitor

Before building the monitor, you need the Flow IDs you want to track.

**How to Find Flow IDs:**

1. Open Power Automate (https://make.powerautomate.com)
2. Select your environment (e.g., "Production")
3. Go to "My flows" or "Solutions"
4. Click on the flow you want to monitor
5. Look at the URL in your browser:
   ```
   https://make.powerautomate.com/environments/[environment-id]/flows/[FLOW-ID]/details
   ```
6. Copy the FLOW-ID portion

**Alternative Method - Using Your Existing Script:**
You already have `Find-PowerPlatformResource.ps1` that can locate flows! You can run:
```powershell
# This will help you find flows and get their IDs
.\Find-PowerPlatformResource.ps1
```

**Document Your Flows:**
Create a list like this:
```
Flow Name: Invoice Processing Flow
Flow ID: 1234abcd-5678-efgh-9012-ijklmnop3456
Environment: Production

Flow Name: Employee Onboarding
Flow ID: 9876zyxw-5432-vuts-1098-rqponmlk7654
Environment: Production
```

---

### Step 2: Create the Monitoring Flow

#### 2.1 Create New Cloud Flow

1. Go to https://make.powerautomate.com
2. Click **"+ Create"** → **"Automated cloud flow"** → **"Skip"**
3. Name it: `Monitor Critical Flows - Production`

#### 2.2 Add Recurrence Trigger

1. Click **"+ New step"**
2. Search for **"Recurrence"**
3. Select the **Recurrence** trigger
4. Configure:
   - **Interval:** 15
   - **Frequency:** Minute
   - **Time zone:** (Your local timezone)

**Why 15 minutes?**
- Balances early detection with API rate limits
- You can adjust later (5 min for critical, 1 hour for less critical)

---

### Step 3: Initialize Variables

We'll use variables to store the flows we want to monitor and track any issues found.

#### 3.1 Initialize Array - Flows to Monitor

1. Click **"+ New step"**
2. Search for **"Initialize variable"**
3. Configure:
   - **Name:** `FlowsToMonitor`
   - **Type:** Array
   - **Value:**
   ```json
   [
     {
       "flowId": "YOUR-FIRST-FLOW-ID-HERE",
       "flowName": "Invoice Processing Flow",
       "environment": "YOUR-ENVIRONMENT-ID"
     },
     {
       "flowId": "YOUR-SECOND-FLOW-ID-HERE",
       "flowName": "Employee Onboarding Flow",
       "environment": "YOUR-ENVIRONMENT-ID"
     }
   ]
   ```

**How to Get Environment ID:**
- Go to Power Automate → Settings (gear icon) → Session details
- Or look at the URL: `https://make.powerautomate.com/environments/[ENVIRONMENT-ID]`

**Pro Tip:** Start with just 1-2 flows for testing!

#### 3.2 Initialize Array - Alert Messages

1. Click **"+ New step"**
2. Search for **"Initialize variable"**
3. Configure:
   - **Name:** `AlertMessages`
   - **Type:** Array
   - **Value:** Leave empty `[]`

This will collect all alerts to send in a single notification.

#### 3.3 Initialize Variable - Has Errors

1. Click **"+ New step"**
2. Search for **"Initialize variable"**
3. Configure:
   - **Name:** `HasErrors`
   - **Type:** Boolean
   - **Value:** `false`

---

### Step 4: Loop Through Flows and Check for Failures

#### 4.1 Add Apply to Each

1. Click **"+ New step"**
2. Search for **"Apply to each"**
3. In **"Select an output from previous steps"**, choose: `FlowsToMonitor`

#### 4.2 Get Flow Run History

Inside the "Apply to each" loop:

1. Click **"Add an action"**
2. Search for **"Power Automate Management"**
3. Select **"List flow runs as Admin"** (or "List flow runs" if not admin)
4. Configure:
   - **Environment Name:** `item()?['environment']`
     - Click the field → Expression tab → Paste: `item()?['environment']`
   - **Flow Name:** `item()?['flowId']`
     - Expression: `item()?['flowId']`
   - **Top Count:** `20` (checks last 20 runs)

**What This Does:**
Gets the last 20 execution records for each flow you're monitoring.

---

### Step 5: Filter for Failed Runs

#### 5.1 Add Filter Array Action

Still inside the "Apply to each":

1. Click **"Add an action"**
2. Search for **"Filter array"**
3. Configure:
   - **From:** Select the output from "List flow runs" → `value`
   - **Filter condition:**
     - Field: `Status` (from dynamic content)
     - Condition: `is equal to`
     - Value: `Failed`

**What This Does:**
Filters the run history to only include failed executions.

---

### Step 6: Check If Any Failures Exist

#### 6.1 Add Condition

Still inside "Apply to each":

1. Click **"Add an action"**
2. Search for **"Condition"**
3. Configure:
   - Click **"Edit in advanced mode"**
   - Paste this expression:
   ```
   @greater(length(body('Filter_array')), 0)
   ```

**What This Does:**
Checks if the filtered array has any failed runs (length > 0).

---

### Step 7: Process Failed Runs (If Yes Branch)

In the **"If yes"** branch of the condition:

#### 7.1 Apply to Each Failed Run

1. Click **"Add an action"** (in the Yes branch)
2. Search for **"Apply to each"**
3. Select output from **"Filter array"** action

#### 7.2 Get Detailed Error Information

Inside this nested "Apply to each":

1. Click **"Add an action"**
2. Search for **"Get flow run as Admin"** (Power Automate Management)
3. Configure:
   - **Environment Name:** Expression: `item()?['environment']` (from outer loop)
   - **Flow Name:** Expression: `items('Apply_to_each')?['name']` (flow ID from outer loop)
   - **Run Name:** Expression: `items('Apply_to_each_2')?['name']` (run ID from inner loop)

**Note:** The action names might differ (Apply_to_each, Apply_to_each_2, etc.). Use the actual names in your flow.

**What This Does:**
Gets the full details of each failed run, including error codes and messages.

---

### Step 8: Format Error Details

#### 8.1 Compose Error Message

Still in the nested "Apply to each":

1. Click **"Add an action"**
2. Search for **"Compose"**
3. In the **Inputs** field, paste this (then add dynamic content):

```
===========================================
FLOW FAILURE DETECTED
===========================================

Flow Name: [FlowName from outer loop]
Flow ID: [FlowId from outer loop]

Run ID: [Run name from Get flow run]
Start Time: [startTime from Get flow run]
Status: [status from Get flow run]

ERROR DETAILS:
Error Code: [error code from Get flow run]
Error Message: [error message from Get flow run]

View Run: https://make.powerautomate.com/environments/[environment]/flows/[flowId]/runs/[runId]

===========================================
```

**How to Build This:**
1. Type the template text
2. Click in the brackets and select dynamic content:
   - `FlowName`: From outer "Apply to each" → `item()?['flowName']` (expression)
   - `FlowId`: From outer "Apply to each" → `item()?['flowId']` (expression)
   - `startTime`: From "Get flow run" → `properties.startTime`
   - `status`: From "Get flow run" → `properties.status`
   - `error code`: Expression: `body('Get_flow_run_as_Admin')?['properties']?['error']?['code']`
   - `error message`: Expression: `body('Get_flow_run_as_Admin')?['properties']?['error']?['message']`

#### 8.2 Append to Alert Array

1. Click **"Add an action"**
2. Search for **"Append to array variable"**
3. Configure:
   - **Name:** `AlertMessages`
   - **Value:** Select output from **Compose** action

#### 8.3 Set Has Errors Flag

1. Click **"Add an action"**
2. Search for **"Set variable"**
3. Configure:
   - **Name:** `HasErrors`
   - **Value:** `true`

---

### Step 9: Send Alert (Outside All Loops)

After the "Apply to each" loop is complete, add a final condition to send alerts if any errors were found.

#### 9.1 Add Final Condition

1. Click **"+ New step"** (OUTSIDE the first Apply to each loop)
2. Search for **"Condition"**
3. Configure:
   - **Condition:** `HasErrors` is equal to `true`

#### 9.2 Send Email Alert (If Yes Branch)

In the **"If yes"** branch:

1. Click **"Add an action"**
2. Search for **"Send an email (V2)"** (Office 365 Outlook)
3. Configure:
   - **To:** Your email or team email
   - **Subject:** `🚨 Flow Monitoring Alert - Failures Detected`
   - **Body:**
   ```
   Flow monitoring has detected failures in your production environment.

   Timestamp: [utcNow() expression]
   Environment: Production

   DETAILS:
   [Join AlertMessages with line break]

   This is an automated alert from Flow Error Monitor.
   Please investigate the failed flows immediately.
   ```

**How to Add utcNow():**
- Click in the field → Expression tab → Type: `utcNow()`

**How to Join Array:**
- Expression: `join(variables('AlertMessages'), '<br><br>')`

---

### Step 10: Test Your Monitor

#### 10.1 Save and Test

1. Click **"Save"** at the top
2. Click **"Test"** → **"Manually"** → **"Test"**
3. Click **"Run flow"**

#### 10.2 Verify Results

Check the run history:
- Did it successfully loop through your flows?
- Did it detect any failures?
- Did you receive an email if there were failures?

#### 10.3 Trigger a Test Failure

To test your monitor actually works:

1. Go to one of your monitored flows
2. Add a step that will fail (e.g., divide by zero, invalid API call)
3. Run the flow manually
4. Wait 15 minutes (or manually run your monitor)
5. Verify you receive an alert!

---

## JSON Parsing Expression Reference

Here are all the expressions you'll need for parsing flow run data:

### Basic Flow Properties
```javascript
// Flow name from outer loop
item()?['flowName']

// Flow ID from outer loop
item()?['flowId']

// Environment from outer loop
item()?['environment']
```

### Run Properties
```javascript
// Run ID
items('Apply_to_each_2')?['name']

// Run status
body('Get_flow_run_as_Admin')?['properties']?['status']

// Start time
body('Get_flow_run_as_Admin')?['properties']?['startTime']

// End time
body('Get_flow_run_as_Admin')?['properties']?['endTime']
```

### Error Information
```javascript
// Error code
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']

// Error message
body('Get_flow_run_as_Admin')?['properties']?['error']?['message']

// Full error object (for debugging)
body('Get_flow_run_as_Admin')?['properties']?['error']
```

### Trigger Information
```javascript
// Trigger name
body('Get_flow_run_as_Admin')?['properties']?['trigger']?['name']

// Trigger status
body('Get_flow_run_as_Admin')?['properties']?['trigger']?['status']

// Trigger start time
body('Get_flow_run_as_Admin')?['properties']?['trigger']?['startTime']
```

### Array Operations
```javascript
// Count items in array
length(variables('AlertMessages'))

// Check if array has items
greater(length(body('Filter_array')), 0)

// Join array with separator
join(variables('AlertMessages'), '<br>')

// Join with double line break
join(variables('AlertMessages'), '<br><br>')
```

### Conditional Checks
```javascript
// Check if error exists
not(empty(body('Get_flow_run_as_Admin')?['properties']?['error']))

// Check for specific error code
equals(body('Get_flow_run_as_Admin')?['properties']?['error']?['code'], 'Unauthorized')

// Check if status is Failed
equals(body('Get_flow_run_as_Admin')?['properties']?['status'], 'Failed')

// Check multiple conditions (AND)
and(
  equals(body('Get_flow_run_as_Admin')?['properties']?['status'], 'Failed'),
  not(empty(body('Get_flow_run_as_Admin')?['properties']?['error']))
)

// Check multiple conditions (OR)
or(
  equals(body('Get_flow_run_as_Admin')?['properties']?['status'], 'Failed'),
  equals(body('Get_flow_run_as_Admin')?['properties']?['status'], 'Cancelled')
)
```

---

## Alert Templates

### Template 1: Simple Email Alert

**Subject:** `🚨 Flow Failure Alert - [FlowName]`

**Body:**
```
A monitored flow has failed.

Flow: [FlowName]
Time: [StartTime]
Error: [ErrorCode] - [ErrorMessage]

View Details: https://make.powerautomate.com/environments/[EnvironmentId]/flows/[FlowId]/runs/[RunId]
```

---

### Template 2: Detailed Email Alert

**Subject:** `🚨 Production Flow Monitoring - [Count] Failure(s) Detected`

**Body:**
```html
<h2>Flow Monitoring Alert</h2>

<p><strong>Timestamp:</strong> [utcNow()]</p>
<p><strong>Environment:</strong> Production</p>
<p><strong>Failures Detected:</strong> [Count]</p>

<hr>

<h3>Failure Details:</h3>

[Joined Alert Messages]

<hr>

<p><em>This is an automated alert from Flow Error Monitor.</em></p>
<p><em>To stop receiving these alerts, disable the monitor flow.</em></p>
```

---

### Template 3: Teams Adaptive Card Alert

Use **"Post adaptive card in a chat or channel"** action with this JSON:

```json
{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "size": "Large",
      "weight": "Bolder",
      "text": "🚨 Flow Failure Detected",
      "color": "Attention"
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "Flow Name:",
          "value": "[FlowName]"
        },
        {
          "title": "Status:",
          "value": "Failed"
        },
        {
          "title": "Time:",
          "value": "[StartTime]"
        },
        {
          "title": "Error Code:",
          "value": "[ErrorCode]"
        }
      ]
    },
    {
      "type": "TextBlock",
      "text": "**Error Message:**",
      "weight": "Bolder"
    },
    {
      "type": "TextBlock",
      "text": "[ErrorMessage]",
      "wrap": true,
      "color": "Attention"
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "View Run Details",
      "url": "https://make.powerautomate.com/environments/[EnvironmentId]/flows/[FlowId]/runs/[RunId]"
    }
  ],
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.4"
}
```

**To use this:**
1. Add action **"Post adaptive card in a chat or channel"**
2. Select your Teams channel
3. Paste the JSON above in the **Message** field
4. Replace `[FlowName]`, `[ErrorCode]`, etc. with dynamic content

---

### Template 4: Error Type Categorization

Add a **Switch** statement to categorize errors and send different alerts:

```javascript
// Switch on error code
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']
```

**Cases:**

**Case 1: "Unauthorized" or "Forbidden"**
```
Subject: 🔐 Authentication Error - [FlowName]
Message: A flow has failed due to authentication issues.
The connection may need to be re-authorized.

Action Required: Check connection references and re-authenticate.
```

**Case 2: "Timeout"**
```
Subject: ⏱️ Timeout Error - [FlowName]
Message: A flow has failed due to timeout.
This may indicate performance issues or external service delays.

Action Required: Review flow performance and external API response times.
```

**Case 3: "InvalidTemplate" or "ActionFailed"**
```
Subject: ⚠️ Logic Error - [FlowName]
Message: A flow has failed due to a logic or configuration error.

Action Required: Review flow logic and recent changes.
```

**Case 4: "ConnectionAuthenticationFailed"**
```
Subject: 🔌 Connection Error - [FlowName]
Message: A flow has failed due to connection authentication failure.
The connection credential may have expired.

Action Required: Edit the connection and provide credentials again.
```

**Default:**
```
Subject: ❌ Flow Error - [FlowName]
Message: A flow has failed with an unknown error type.

Error Code: [ErrorCode]
Action Required: Manual investigation needed.
```

---

## Troubleshooting Common Issues

### Issue 1: "Flow not found" Error

**Symptom:** Monitor can't find the flow you specified.

**Solutions:**
- Verify the Flow ID is correct (copy from URL)
- Verify the Environment ID is correct
- Check you have permission to access the flow
- If monitoring someone else's flow, ensure you have "System Administrator" or "Environment Admin" role

---

### Issue 2: "Unable to read error property" Error

**Symptom:** Expression errors when trying to read error details.

**Cause:** Not all failed runs have an error object (some just have status "Failed").

**Solution:** Add safe navigation and null checks:
```javascript
// Instead of:
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']

// Use:
if(
  not(empty(body('Get_flow_run_as_Admin')?['properties']?['error'])),
  body('Get_flow_run_as_Admin')?['properties']?['error']?['code'],
  'No error code available'
)
```

---

### Issue 3: Too Many Alerts

**Symptom:** Getting flooded with alerts for the same failure.

**Solutions:**

**Option A: Track Last Alerted Time**
- Store the last alert time in a SharePoint list or Dataverse table
- Only alert if the failure is new (not already alerted in last X hours)

**Option B: Reduce Check Frequency**
- Change recurrence from 15 min to 30 min or 1 hour

**Option C: Batch Alerts**
- Collect all failures throughout the day
- Send a single summary email at end of day

**Option D: Alert Only on New Failures**
- Keep track of previously failed runs
- Only alert if it's a NEW failure since last check

---

### Issue 4: No Alerts Even Though Flow Failed

**Symptom:** Monitor runs successfully but doesn't detect known failures.

**Debugging Steps:**

1. **Check the filter:**
   - View the "Filter array" action output
   - Verify it's actually finding failed runs

2. **Check the condition:**
   - View the condition evaluation
   - Verify it's entering the "Yes" branch

3. **Check the run count:**
   - You're only checking last 20 runs
   - If the failure is older, increase "Top Count" to 50 or 100

4. **Check timing:**
   - Run the monitor AFTER you've confirmed a flow failed
   - Check if the status is actually "Failed" vs "Cancelled" or other status

---

### Issue 5: "List flow runs" Returns Empty

**Symptom:** The "List flow runs" action returns no results.

**Solutions:**
- Verify the flow has actually run (check manually in portal)
- Verify you're using the correct Flow ID (not the run ID)
- Check your permissions (need at least Environment Maker)
- Try using "List flow runs as Admin" if you have admin rights

---

## Phase 2: Enhancements (After Phase 1 Works)

Once your basic monitor is working, add these features:

### Enhancement 1: Monitor Disabled Flows

Add a parallel branch to check if flows are stopped/disabled.

**After the "List flow runs" action, add a parallel branch:**

1. Click the **+** between actions
2. Select **"Add a parallel branch"**
3. Add action: **"Get flow as Admin"**
   - Environment: `item()?['environment']`
   - Flow Name: `item()?['flowId']`
4. Add **Condition:**
   - Check if: `body('Get_flow_as_Admin')?['properties']?['state']`
   - Is equal to: `Stopped` or `Suspended`
5. If yes, add to alerts:
   ```
   ⏸️ FLOW DISABLED ALERT

   Flow Name: [FlowName]
   Current State: [State]

   This flow is currently stopped and will not run automatically.

   Action Required: Re-enable the flow if it should be active.
   ```

---

### Enhancement 2: Track Consecutive Failures

Detect patterns of repeated failures (e.g., last 5 runs all failed).

**After "List flow runs", before "Filter array":**

1. Add **Filter array** (new one) to get last 5 runs:
   ```javascript
   @take(body('List_flow_runs_as_Admin')?['value'], 5)
   ```

2. Add **Apply to each** to loop through these 5

3. Count how many are Failed:
   ```javascript
   length(filter(take(body('List_flow_runs_as_Admin')?['value'], 5),
                  lambda('x', equals(item()?['properties']?['status'], 'Failed'))))
   ```

4. If count >= 5, send critical alert:
   ```
   🚨🚨🚨 CRITICAL: REPEATED FAILURES

   Flow Name: [FlowName]

   The last 5 consecutive runs have ALL failed.
   This indicates a persistent issue requiring immediate attention.

   IMMEDIATE ACTION REQUIRED
   ```

---

### Enhancement 3: Historical Tracking (SharePoint List)

Store failure history in a SharePoint list for trend analysis.

**Create SharePoint List:**
- List name: `Flow Monitoring History`
- Columns:
  - Title (default - use Flow Name)
  - FlowID (Single line text)
  - RunID (Single line text)
  - ErrorCode (Single line text)
  - ErrorMessage (Multiple lines text)
  - DetectedTime (Date/Time)
  - Status (Choice: Failed, Warning, Disabled)

**In your monitor flow:**

After formatting error details, add:
1. **Create item** (SharePoint)
   - Site Address: Your SharePoint site
   - List Name: Flow Monitoring History
   - Title: `item()?['flowName']`
   - FlowID: `item()?['flowId']`
   - RunID: `items('Apply_to_each_2')?['name']`
   - ErrorCode: `body('Get_flow_run_as_Admin')?['properties']?['error']?['code']`
   - ErrorMessage: `body('Get_flow_run_as_Admin')?['properties']?['error']?['message']`
   - DetectedTime: `utcNow()`
   - Status: `Failed`

**Benefits:**
- Historical record of all failures
- Can build Power BI dashboard
- Can analyze patterns over time
- Audit trail for compliance

---

### Enhancement 4: Dynamic Flow List (SharePoint)

Instead of hard-coding flows in the monitor, store them in SharePoint.

**Create SharePoint List:**
- List name: `Monitored Flows`
- Columns:
  - Title (default - use Flow Name)
  - FlowID (Single line text)
  - Environment (Single line text)
  - IsActive (Yes/No - to enable/disable monitoring)
  - AlertEmail (Single line text - owner's email)
  - Criticality (Choice: Critical, High, Medium, Low)

**In your monitor flow:**

Replace "Initialize variable - FlowsToMonitor" with:
1. **Get items** (SharePoint)
   - Site Address: Your SharePoint site
   - List Name: Monitored Flows
   - Filter Query: `IsActive eq true`

2. Update "Apply to each" to use this list instead

**Benefits:**
- No need to edit flow to add/remove monitored flows
- Non-technical users can manage the list
- Can add metadata (criticality, owner, etc.)
- Can enable/disable monitoring per flow

---

### Enhancement 5: Integration with Teams Channel

Post failures directly to a Teams channel instead of email.

**Replace "Send an email" with:**

1. **Post message in a chat or channel** (Teams)
   - Post as: Flow bot
   - Post in: Channel
   - Team: (Select your team)
   - Channel: (Create a "Flow Monitoring" channel)
   - Message:
   ```
   🚨 **Flow Failure Alert**

   **Flow:** [FlowName]
   **Time:** [StartTime]
   **Status:** Failed

   **Error:** [ErrorCode]
   [ErrorMessage]

   [View Run](https://make.powerautomate.com/...)
   ```

**Benefits:**
- Team visibility
- No email inbox clutter
- Can @mention owners
- Better collaboration on fixes

---

### Enhancement 6: Auto-Remediation for Common Issues

For certain error types, attempt automatic fixes.

**Example: Re-enable Disabled Flow**

```
If error code is "ConnectionAuthenticationFailed":
  1. Get the connection reference
  2. Send notification to connection owner to re-auth
  3. (Optional) If you have admin rights, attempt to re-enable the connection
```

**Example: Retry Failed Run**

```
If error is "Timeout" or "ServiceUnavailable":
  1. Wait 5 minutes
  2. Trigger the flow again (if it's a child flow)
  3. Monitor the retry
```

**Warning:** Be cautious with auto-remediation. Document all automatic actions and alert humans when remediation is attempted.

---

## Phase 3: Power App Dashboard (Advanced)

Create a Power App to visualize monitoring data.

### App Screens:

**Screen 1: Dashboard Overview**
- Gallery of monitored flows
- Traffic light indicators (Green: OK, Yellow: Warnings, Red: Failures)
- Last check time
- Quick stats: Total flows, Failed flows, Disabled flows

**Screen 2: Flow Details**
- Selected flow's run history
- Error trend chart (last 7 days)
- Success rate percentage
- Recent errors list

**Screen 3: Configuration**
- Add/remove flows to monitor
- Configure alert settings
- Enable/disable monitoring
- Test monitor manually

**Screen 4: Historical Analytics**
- Power BI embedded report
- Failure trends over time
- Most common error types
- MTTR (Mean Time To Resolution)

---

## Testing Strategy

### Test Case 1: Detect Failed Run

**Setup:**
1. Create a test flow that fails (divide by zero, invalid API call)
2. Run it manually
3. Wait for monitor to run (or trigger manually)

**Expected Result:**
- Monitor detects the failure
- Error details are captured correctly
- Alert is sent with correct information

---

### Test Case 2: Detect Disabled Flow

**Setup:**
1. Disable one of your monitored flows
2. Wait for monitor to run

**Expected Result:**
- Monitor detects flow is disabled
- Separate alert is sent indicating disabled status

---

### Test Case 3: No False Positives

**Setup:**
1. Ensure all monitored flows are running successfully
2. Run monitor multiple times over a day

**Expected Result:**
- No alerts are sent
- Monitor completes successfully
- No errors in monitor flow itself

---

### Test Case 4: Multiple Failures

**Setup:**
1. Cause 2-3 different flows to fail
2. Run monitor

**Expected Result:**
- All failures are detected
- Single email contains all failures
- Each failure has unique error details

---

### Test Case 5: Authentication Error

**Setup:**
1. Remove credentials from a connection used by a monitored flow
2. Trigger that flow (it will fail with auth error)
3. Run monitor

**Expected Result:**
- Monitor correctly identifies auth error
- Error code is "Unauthorized" or "ConnectionAuthenticationFailed"
- Error message indicates authentication issue

---

## Maintenance & Best Practices

### Weekly Tasks
- [ ] Review alert emails/Teams messages
- [ ] Verify monitor is running on schedule
- [ ] Check for any failures in the monitor flow itself

### Monthly Tasks
- [ ] Review the list of monitored flows (add/remove as needed)
- [ ] Analyze failure trends (if using SharePoint tracking)
- [ ] Optimize alert frequency if getting too many/few alerts
- [ ] Review and clean up historical data (if storing in SharePoint)

### Quarterly Tasks
- [ ] Review and update error categorization
- [ ] Add new flows to monitoring
- [ ] Evaluate if monitoring should expand to other environments
- [ ] Review performance (API call limits, execution time)

---

### Best Practices

1. **Start Small:** Monitor 2-3 critical flows first, then expand

2. **Document Flow Owners:** Keep a list of who owns each monitored flow for escalation

3. **Set Clear SLAs:** Define how quickly failures need to be addressed
   - Critical: 15 min response
   - High: 1 hour response
   - Medium: 4 hours response
   - Low: Next business day

4. **Avoid Alert Fatigue:**
   - Don't alert on every single failure
   - Consider batching alerts
   - Allow snoozing/acknowledgment

5. **Monitor the Monitor:**
   - Create a second flow that checks if the monitor is running
   - Send weekly "heartbeat" emails confirming monitor is active

6. **Version Control:**
   - Export your monitor flow regularly as backup
   - Document all changes
   - Test changes in dev environment first

7. **Security:**
   - Use service accounts for connections, not personal accounts
   - Limit who can modify the monitor flow
   - Store flow IDs securely (consider Azure Key Vault for larger deployments)

8. **Performance:**
   - Be mindful of API rate limits (Power Automate Management API)
   - If monitoring many flows (50+), consider breaking into multiple monitor flows
   - Use pagination if checking large run histories

---

## Expansion Roadmap

### Month 1: Foundation
- ✅ Build basic monitor (Phase 1)
- ✅ Test with 2-3 flows
- ✅ Verify alerts work
- ✅ Monitor runs on schedule

### Month 2: Enhancement
- Add disabled flow detection
- Implement historical tracking (SharePoint)
- Add error categorization
- Expand to 10 flows

### Month 3: Advanced Features
- Dynamic flow list (SharePoint)
- Teams integration
- Consecutive failure detection
- Expand to 20+ flows

### Month 4: Dashboard & Analytics
- Build Power App dashboard
- Create Power BI reports
- Implement trend analysis
- Consider environment-wide monitoring

### Month 5: Enterprise Features
- Auto-remediation for common issues
- Integration with ticketing system
- SLA tracking
- Cross-environment monitoring

---

## Additional Resources

### Microsoft Documentation
- [Power Automate Management Connector](https://learn.microsoft.com/en-us/connectors/flowmanagement/)
- [Power Automate Expression Reference](https://learn.microsoft.com/en-us/power-automate/use-expressions-in-conditions)
- [Error Handling in Power Automate](https://learn.microsoft.com/en-us/power-automate/error-handling)

### Community Resources
- Power Users Community: https://powerusers.microsoft.com/
- Power Automate Blog: https://powerautomate.microsoft.com/blog/

### Your Existing Scripts
- Use `Find-PowerPlatformResource.ps1` to discover flows
- Use `Test-PowerPlatformAccess.ps1` to verify permissions before building

---

## Success Criteria

You'll know your monitor is successful when:

✅ It runs reliably every 15 minutes without manual intervention
✅ It correctly detects flow failures within 15 minutes of occurrence
✅ Alerts contain actionable information (error codes, messages, links)
✅ You catch a real production issue before users report it
✅ Team members start relying on it instead of manually checking flows
✅ False positive rate is < 5%
✅ You've prevented at least one major business impact by early detection

---

## Getting Help

If you run into issues:

1. **Check run history:** Look at the monitor flow's run history for errors
2. **Enable flow checker:** Use built-in checker to identify issues
3. **Test individual actions:** Use "Test" mode to run actions one at a time
4. **Community support:** Post on Power Users Community with specific error messages
5. **Review this guide:** Troubleshooting section has common issues

---

## Conclusion

Congratulations! You now have a comprehensive guide to building a production-ready flow monitoring system.

**What You've Learned:**
- Power Automate Management connector usage
- JSON parsing and error handling
- Array operations and filtering
- Alert notifications and formatting
- Best practices for monitoring automation

**Next Steps:**
1. Start with Phase 1 - get basic monitoring working
2. Test thoroughly with a few flows
3. Gradually add Phase 2 enhancements
4. Expand scope as you gain confidence

**Remember:** Start small, test often, and expand gradually. Good luck!

---

## Appendix: Quick Reference

### Key Expressions Cheat Sheet

```javascript
// Get flow name from loop
item()?['flowName']

// Filter for failed runs
@equals(item()?['properties']?['status'], 'Failed')

// Get error code safely
if(empty(body('Get_flow_run')?['properties']?['error']), 'No error', body('Get_flow_run')?['properties']?['error']?['code'])

// Count array items
length(variables('AlertMessages'))

// Join array
join(variables('AlertMessages'), '<br><br>')

// Current UTC time
utcNow()

// Format date
formatDateTime(utcNow(), 'yyyy-MM-dd HH:mm:ss')
```

### Error Codes Reference

| Error Code | Meaning | Common Causes |
|------------|---------|---------------|
| Unauthorized | Auth failure | Expired credentials, removed permissions |
| Forbidden | Access denied | Insufficient permissions |
| Timeout | Execution timeout | Long-running actions, slow APIs |
| ActionFailed | Logic error | Invalid data, failed validation |
| ConnectionAuthenticationFailed | Connection issue | Expired connection, invalid credentials |
| InvalidTemplate | Configuration error | Malformed expressions, missing required fields |
| ServiceUnavailable | External service down | Third-party API outage |
| TooManyRequests | Rate limit exceeded | Too many API calls |

### Monitor Health Checklist

- [ ] Monitor flow has run in last hour
- [ ] No errors in monitor flow itself
- [ ] All monitored flows are included
- [ ] Alert emails/Teams messages are being received
- [ ] Historical data (if implemented) is being recorded
- [ ] No false positives in last 24 hours
- [ ] Team knows how to respond to alerts

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**Author:** Claude Code Implementation Guide
**For:** SharePoint & Power Platform Learning Project
