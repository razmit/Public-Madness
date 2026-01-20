# Flow Error Monitor - Troubleshooting Guide

This guide helps you diagnose and fix common issues with your Flow Error Monitor.

---

## Quick Diagnostic Checklist

Start here when something isn't working:

- [ ] Monitor flow has run in the last hour (check run history)
- [ ] Monitor flow completed successfully (no errors in its own execution)
- [ ] All monitored Flow IDs are correct (check URLs)
- [ ] Environment IDs are correct
- [ ] You have necessary permissions (Environment Maker minimum)
- [ ] Premium connectors are licensed
- [ ] Alert email address is correct

---

## Common Issues and Solutions

### Issue 1: "Flow not found" or "Resource not found" Error

**Symptom:**
```
The API operation 'GetFlow' is not found.
OR
Flow with name '[FLOW-ID]' could not be found.
```

**Root Causes:**
1. Incorrect Flow ID
2. Incorrect Environment ID
3. Insufficient permissions
4. Flow was deleted

**How to Diagnose:**
1. Open Power Automate: https://make.powerautomate.com
2. Navigate to the flow manually
3. Check the URL: `...environments/[ENV-ID]/flows/[FLOW-ID]/...`
4. Copy the IDs exactly as they appear

**Solutions:**

**Solution A: Verify Flow ID**
```javascript
// In your FlowsToMonitor array, ensure format is:
[
  {
    "flowId": "12345678-abcd-1234-abcd-1234567890ab",  // GUID format
    "flowName": "Your Flow Name",
    "environment": "Default-12345678-abcd-1234-abcd-1234567890ab"  // Full env ID
  }
]
```

**Solution B: Check Permissions**
1. Go to Power Automate
2. Can you see the flow in "My flows"?
3. If NO → You don't have access (ask owner to share)
4. If YES but still error → Try "List flow runs" instead of "List flow runs as Admin"

**Solution C: Verify Flow Still Exists**
1. Check if flow was deleted
2. Check if flow was moved to different environment
3. Update your FlowsToMonitor array if needed

---

### Issue 2: No Alerts Despite Known Failures

**Symptom:**
- Monitor runs successfully
- You know a flow failed
- But no alert is sent

**How to Diagnose:**

**Step 1: Check Monitor Run History**
1. Open your monitor flow
2. Click run history
3. Find the most recent run
4. Click to expand details

**Step 2: Check "List flow runs" Output**
1. Find the "List flow runs as Admin" action
2. Look at OUTPUTS
3. Is the `value` array populated?
4. Does it contain the failed run?

**Step 3: Check "Filter array" Output**
1. Find the "Filter array" action
2. Look at OUTPUTS
3. Did it find any failed runs?
4. Check the filter condition

**Step 4: Check Condition Evaluation**
1. Find the condition "Check for failures"
2. Did it evaluate to TRUE or FALSE?
3. If FALSE, why didn't it find failures?

**Solutions:**

**Solution A: Increase Run History Count**
```
In "List flow runs" action:
Top Count: 20  →  Change to 50 or 100

The failure might be older than the last 20 runs.
```

**Solution B: Verify Filter Logic**
```javascript
// Current filter:
Status is equal to "Failed"

// Try checking if it's actually "Failed" or something else:
// Possible values: "Succeeded", "Failed", "Cancelled", "Running", "Waiting"

// To debug, add a Compose action to see all statuses:
@join(select(body('List_flow_runs_as_Admin')?['value'], 'properties.status'), ', ')
```

**Solution C: Check Timing**
```
Did the flow fail AFTER the last monitor check?

Monitor runs every: 15 minutes
Last monitor run: 2:00 PM
Flow failed at: 2:05 PM
Next monitor run: 2:15 PM  ← Should detect it then

Wait for next monitor cycle or trigger manually.
```

**Solution D: Verify Alert Logic**
```
Check the final condition:
- Is HasErrors set to true?
- Does AlertMessages array contain items?
- Is the email action inside the correct branch?

Add a Compose action before email to debug:
@{variables('HasErrors')}
@{length(variables('AlertMessages'))}
```

---

### Issue 3: Expression Errors ("Unable to read property...")

**Symptom:**
```
InvalidTemplate. Unable to process template language expressions in action 'Compose' inputs at line '1' and column '11': 'The template language expression 'body('Get_flow_run_as_Admin')?['properties']?['error']?['code']' cannot be evaluated because property 'error' doesn't exist...
```

**Root Cause:**
Not all failed runs have an `error` object. Some failures don't populate error details.

**Solution A: Add Null Checks**

Instead of:
```javascript
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']
```

Use:
```javascript
if(
  empty(body('Get_flow_run_as_Admin')?['properties']?['error']),
  'No error code available',
  body('Get_flow_run_as_Admin')?['properties']?['error']?['code']
)
```

**Solution B: Use Coalesce**
```javascript
coalesce(
  body('Get_flow_run_as_Admin')?['properties']?['error']?['code'],
  'Unknown'
)
```

**Solution C: Add Condition Before Accessing**
```javascript
// Add a condition:
@not(empty(body('Get_flow_run_as_Admin')?['properties']?['error']))

// If TRUE → Process error details
// If FALSE → Use default message "Run failed but no error details available"
```

---

### Issue 4: "Apply to each" Action Names Don't Match

**Symptom:**
```
InvalidTemplate. Unable to process template language expression 'items('Apply_to_each_2')?['name']': the template language function 'items' expects its parameter to be a string or of type 'LoopActionNode'...
```

**Root Cause:**
Power Automate auto-names "Apply to each" actions as:
- Apply_to_each
- Apply_to_each_2
- Apply_to_each_3

If you rename them or have different numbers, expressions break.

**Solution:**

**Find Correct Action Name:**
1. Click on "Apply to each" action
2. Look at the action header (top-left of the action card)
3. Note the internal name

**Update Expression:**
```javascript
// If your inner loop is called "Apply_to_each_3":
items('Apply_to_each_3')?['name']

// If you renamed it to "Process_Failed_Runs":
items('Process_Failed_Runs')?['name']
```

**Pro Tip:** Rename your loops for clarity:
1. Click the "..." menu on the action
2. Select "Rename"
3. Use clear names like:
   - "Loop_Through_Monitored_Flows"
   - "Loop_Through_Failed_Runs"

Then update expressions accordingly:
```javascript
items('Loop_Through_Failed_Runs')?['name']
```

---

### Issue 5: Too Many Alerts / Alert Spam

**Symptom:**
- Receiving dozens of emails
- Same failure alerted multiple times
- Alert fatigue setting in

**Root Causes:**
1. Monitor checks every 15 min and re-alerts for same failure
2. Multiple monitors running
3. No deduplication logic

**Solutions:**

**Solution A: Track Previously Alerted Runs**

Add a SharePoint list to track alerted runs:

**List: "Alerted Flow Runs"**
- Columns: FlowID, RunID, AlertedTime

**In Monitor Flow:**
1. Before sending alert, check if RunID already exists in list
2. If exists → Skip alert
3. If not exists → Send alert AND add to list

```javascript
// After getting failed run, add action:
// Get items (SharePoint)
// Filter: FlowID eq '[current flow]' and RunID eq '[current run]'

// Then add Condition:
// If length(outputs('Get_items')) = 0 (run not previously alerted)
//   → Send alert
//   → Create item in SharePoint list
// Else
//   → Skip
```

**Solution B: Reduce Check Frequency**
```
Recurrence:
Every 15 minutes  →  Change to every 1 hour

This reduces alerts but increases detection time.
```

**Solution C: Batch Alerts**
```
Instead of sending individual emails:
1. Collect all failures throughout the day
2. Send one summary email at 5 PM
3. Clear the collection for next day
```

**Implementation:**
- Remove immediate email action
- Add a second flow (runs daily at 5 PM)
- That flow reads from SharePoint list of failures for the day
- Sends single summary
- Archives the records

**Solution D: Alert Only on NEW Failures**
```
Keep track of last known status:
- If flow was succeeding, then failed → ALERT
- If flow was already failing → Don't alert again
- If flow recovered → Send recovery notification
```

---

### Issue 6: Monitor Flow Itself is Failing

**Symptom:**
Your monitoring flow shows errors in its own run history.

**Common Errors:**

**Error: "Rate limit exceeded"**
```
Cause: Too many API calls to Power Automate Management API
Solution:
- Reduce number of monitored flows
- Increase check frequency (less often)
- Split monitoring across multiple flows
```

**Error: "Request timeout"**
```
Cause: Monitor is taking too long to complete
Solution:
- Reduce "Top Count" in List flow runs (20 → 10)
- Remove expensive operations
- Optimize loops
- Consider parallel branches
```

**Error: "Unauthorized"**
```
Cause: Monitor lost permissions or connections expired
Solution:
- Re-authenticate Power Automate Management connector
- Verify you still have permissions to monitored flows
- Check if your account was disabled/changed
```

---

### Issue 7: Wrong Flow Details in Alerts

**Symptom:**
Alert says "Flow A" failed, but details are from "Flow B"

**Root Cause:**
Loop variable references are incorrect or conflicting.

**Solution:**

**Use Clear Variable Scoping:**
```javascript
// In outer loop (looping through FlowsToMonitor):
items('Loop_Through_Monitored_Flows')?['flowName']

// In inner loop (looping through failed runs):
items('Loop_Through_Failed_Runs')?['name']  // This is the RUN ID
```

**Don't use:**
```javascript
item()?['flowName']  // Ambiguous - which loop?
```

**Debug Steps:**
1. Add Compose action in outer loop:
   - Name: "Debug - Current Flow Name"
   - Input: `items('Loop_Through_Monitored_Flows')?['flowName']`

2. Add Compose action in inner loop:
   - Name: "Debug - Current Run ID"
   - Input: `items('Loop_Through_Failed_Runs')?['name']`

3. Check run history to verify correct values

---

### Issue 8: Emails Not Sending

**Symptom:**
Monitor completes successfully but no email arrives.

**Diagnosis Steps:**

**Step 1: Check Email Action Ran**
1. Open monitor run history
2. Find the "Send an email" action
3. Did it execute? Or was it skipped?

**Step 2: Check Condition Logic**
```
If email action is inside a condition:
- Was the condition TRUE or FALSE?
- Check HasErrors variable value
- Check AlertMessages array length
```

**Step 3: Check Email Address**
```
Is the recipient email correct?
Check spam/junk folder
Check quarantine if you have email filtering
```

**Step 4: Check Connection**
```
Go to Connections in Power Automate
Find Office 365 Outlook connection
Is it healthy? Any warnings?
Try "Fix connection" if issues
```

**Solutions:**

**Solution A: Force Email Regardless (Testing)**
```
Temporarily move email action OUTSIDE all conditions
Add static test content
Run monitor
Did email arrive?
If YES → Problem is with conditions
If NO → Problem is with email connection or recipient
```

**Solution B: Use Different Email Action**
```
Instead of "Send an email (V2)" try:
- "Send an email notification (V3)"
- "Send email" (Gmail connector)
- "Post message" (Teams) as alternative
```

**Solution C: Add Error Handling**
```
On the "Send email" action:
1. Click "..." menu
2. Configure run after
3. Check "has failed" and "has timed out"
4. Add a parallel action to log the failure
```

---

### Issue 9: Can't Find Environment ID

**Symptom:**
Don't know what to put in the "environment" field.

**Solution:**

**Method 1: From URL**
1. Go to https://make.powerautomate.com
2. Look at URL: `.../environments/[THIS-IS-YOUR-ENV-ID]/...`
3. Copy that part

**Method 2: From Settings**
1. Go to Power Automate
2. Click gear icon (Settings)
3. Click "Session details"
4. Copy "Environment Id"

**Method 3: Using PowerShell**
```powershell
# Use your existing script!
.\Test-PowerPlatformAccess.ps1

# Or use Find-PowerPlatformResource.ps1
# It will show environment information
```

**Method 4: From Azure Portal**
1. Go to https://portal.azure.com
2. Search for "Power Platform"
3. Environments will list with IDs

**Format:**
```
Usually looks like:
Default-12345678-abcd-1234-abcd-1234567890ab

Or:
12345678-abcd-1234-abcd-1234567890ab
```

---

### Issue 10: "Forbidden" or Permission Errors

**Symptom:**
```
Forbidden. The caller does not have permission to perform the operation.
```

**Root Causes:**
1. You don't have access to the flow
2. You're not using the right connector action
3. Your role doesn't have sufficient permissions

**Solutions:**

**Solution A: Use Correct Connector Action**
```
If you're NOT an admin:
Use: "List flow runs" (not "as Admin")
Use: "Get flow" (not "as Admin")

If you ARE an admin:
Use: "List flow runs as Admin"
Use: "Get flow as Admin"
```

**Solution B: Request Access**
```
1. Ask flow owner to share the flow with you
2. They need to add you as a co-owner or can-edit
3. Alternatively, ask for Environment Admin role
```

**Solution C: Only Monitor Your Own Flows**
```
You can always monitor flows YOU own without special permissions.

Start with your own flows, then expand once you get admin role.
```

**Check Your Role:**
1. Go to Power Platform Admin Center
2. Environments → Select your environment
3. Settings → Users + permissions
4. Find your name
5. Check your role:
   - System Administrator ✅ Can monitor all flows
   - Environment Admin ✅ Can monitor all flows
   - Environment Maker ⚠️ Can only monitor your own flows
   - Other roles ❌ Cannot monitor flows

---

### Issue 11: Adaptive Card Not Displaying Correctly

**Symptom:**
Teams adaptive card shows errors or looks wrong.

**Common Causes:**
1. Invalid JSON syntax
2. Missing required fields
3. Dynamic content not formatted correctly

**Solutions:**

**Solution A: Validate JSON**
1. Go to https://adaptivecards.io/designer/
2. Paste your card JSON
3. Preview on right side
4. Fix any errors highlighted

**Solution B: Escape Dynamic Content**
```json
// In JSON, dynamic content needs special format:
"text": "@{variables('FlowName')}"

// NOT:
"text": "[FlowName]"  // This doesn't work
```

**Solution C: Use String Interpolation**
```javascript
// If values have quotes or special characters, wrap in json():
@{json(concat('"', variables('FlowName'), '"'))}
```

**Solution D: Test with Static Content First**
```json
{
  "type": "TextBlock",
  "text": "Static Test Message"
}

// If this works, problem is with dynamic content
// If this fails, problem is with card structure
```

---

### Issue 12: Monitor is Slow / Times Out

**Symptom:**
Monitor takes 5+ minutes to run or times out.

**Root Causes:**
1. Monitoring too many flows
2. Checking too many runs per flow
3. Inefficient loops

**Solutions:**

**Solution A: Reduce Scope**
```
Instead of checking last 50 runs per flow → Check last 10

In "List flow runs":
Top Count: 50  →  10

This is usually enough to catch recent failures.
```

**Solution B: Split into Multiple Monitors**
```
Instead of one monitor for 50 flows:
- Monitor 1: Critical flows (10 flows, checks every 5 min)
- Monitor 2: High priority (20 flows, checks every 15 min)
- Monitor 3: Normal priority (20 flows, checks every 1 hour)
```

**Solution C: Use Parallel Branches**
```
Instead of one loop checking flows sequentially:
Use parallel branches to check multiple flows simultaneously

However, be careful with API rate limits!
```

**Solution D: Optimize Conditions**
```
Move expensive operations (like Get flow run) into conditions:

Only call "Get flow run" IF filter found failures
Don't call it for every run unnecessarily
```

---

## Performance Optimization Tips

### Tip 1: Use Concurrency Control

```
On "Apply to each" loops:
1. Click "..." menu
2. Settings
3. Turn ON "Concurrency Control"
4. Set to 5-10

This processes multiple items in parallel, speeding up the monitor.
```

### Tip 2: Minimize API Calls

```
Before:
- Loop through 20 runs
- Get details for EACH run (20 API calls)

After:
- Filter to only failed runs (e.g., 2 failures)
- Get details only for those (2 API calls)

Savings: 18 API calls!
```

### Tip 3: Cache Results

```
If monitoring same flows frequently:
- Store flow metadata in SharePoint
- Read from SharePoint instead of calling API each time
- Refresh cache once per day
```

### Tip 4: Use Select to Transform Early

```
Instead of looping through huge objects:

Add "Select" action after "List flow runs":
From: body('List_flow_runs')?['value']
Map:
  RunID: item()?['name']
  Status: item()?['properties']?['status']
  StartTime: item()?['properties']?['startTime']

Now you have smaller objects to work with in loops.
```

---

## Debugging Techniques

### Technique 1: Add Compose Actions

```
At each major step, add Compose to see what's happening:

Compose - Debug 1: See FlowsToMonitor array
Compose - Debug 2: See List flow runs output
Compose - Debug 3: See Filter array result
Compose - Debug 4: See AlertMessages array

Check run history to see values at each step.
```

### Technique 2: Enable Flow Checker

```
1. In flow editor, click "Flow Checker" (top-right)
2. It will highlight errors and warnings
3. Fix issues before saving
```

### Technique 3: Test Actions Individually

```
Use "Test" mode:
1. Save flow
2. Click "Test"
3. Select "Test with data from previous runs"
4. Run

This lets you test without waiting for recurrence trigger.
```

### Technique 4: Use Try-Catch Pattern

```
Wrap risky operations in Scope actions:

Scope - Try:
  [Your actions here]

Scope - Catch (configure run after "has failed"):
  [Error handling actions]
  [Log the error]
  [Continue anyway]

This prevents monitor from failing completely if one flow check fails.
```

---

## Error Message Decoder

Common error messages and what they mean:

### "Resource not found"
- Flow ID is wrong
- Environment ID is wrong
- Flow was deleted
- You don't have access

### "Unauthorized"
- Missing permissions
- Need to use "as Admin" actions
- Connection expired

### "InvalidTemplate"
- Expression syntax error
- Missing closing bracket
- Invalid property reference

### "TooManyRequests"
- Hit API rate limit
- Reduce frequency
- Reduce number of flows

### "RequestTimeout"
- Monitor taking too long
- Optimize loops
- Reduce scope

### "BadRequest"
- Invalid parameter value
- Check all dynamic content
- Verify data types match

---

## When to Ask for Help

If you've tried troubleshooting and still stuck, gather this information before asking for help:

**Information to Provide:**
1. **Error message:** Full text of the error
2. **Action name:** Which action is failing
3. **Run history:** Screenshot of failed run
4. **Action configuration:** Screenshot of action settings
5. **Expression used:** Copy exact expression causing error
6. **What you tried:** List of solutions already attempted

**Where to Get Help:**
- Power Users Community: https://powerusers.microsoft.com/
- Microsoft Support: https://support.microsoft.com/
- Your organization's Platform team
- Stack Overflow: Tag [power-automate]

---

## Prevention Checklist

Prevent issues before they happen:

### Before Building:
- [ ] Verify you have premium license
- [ ] Confirm you have necessary permissions
- [ ] Test API access with one flow first
- [ ] Plan monitoring scope (start small)

### While Building:
- [ ] Test each action as you add it
- [ ] Use clear variable names
- [ ] Add error handling (Try-Catch scopes)
- [ ] Use null checks in expressions
- [ ] Rename loops for clarity

### After Building:
- [ ] Test with known failure
- [ ] Test with no failures (no false positives)
- [ ] Document Flow IDs being monitored
- [ ] Set up backup alerts (if monitor itself fails)
- [ ] Schedule regular review (weekly)

### Ongoing:
- [ ] Monitor the monitor (check it's running)
- [ ] Review alert accuracy weekly
- [ ] Update flow list as flows added/removed
- [ ] Optimize based on performance metrics
- [ ] Keep documentation updated

---

## Emergency Recovery

If monitoring is completely broken:

### Step 1: Disable the Monitor
```
1. Open the monitor flow
2. Click "Turn off" (top-right)
3. This stops it from running and causing issues
```

### Step 2: Check Recent Changes
```
1. Go to run history
2. When did it last work?
3. What changed since then?
4. Revert those changes
```

### Step 3: Start Fresh (If Needed)
```
If you can't fix it:
1. Export current flow as backup
2. Create new flow from scratch
3. Follow implementation guide again
4. Start with 1 flow to test
5. Gradually expand
```

### Step 4: Set Up Manual Checks
```
While monitor is down:
- Set calendar reminder to check flows manually
- Export run history daily
- Have team report issues
```

---

## Maintenance Schedule

Regular maintenance prevents issues:

### Daily (Automated):
- Monitor runs automatically
- Sends alerts if issues found

### Weekly (5 minutes):
- Check monitor run history (is it running?)
- Review alert emails (any patterns?)
- Verify monitored flows list is current

### Monthly (30 minutes):
- Review false positive rate
- Analyze failure trends
- Update error categorization
- Optimize alert frequency
- Clean up historical data

### Quarterly (1 hour):
- Full audit of monitored flows
- Permission review
- Performance optimization
- Documentation update
- Test disaster recovery

---

## Testing Scenarios

Test these scenarios regularly:

### Test 1: Happy Path
- [ ] All flows running successfully
- [ ] Monitor completes without errors
- [ ] No alerts sent

### Test 2: Single Failure
- [ ] Create test flow that fails
- [ ] Wait for monitor cycle
- [ ] Verify alert received
- [ ] Check alert has correct details

### Test 3: Multiple Failures
- [ ] Cause 2-3 flows to fail
- [ ] Verify all detected
- [ ] Verify single alert with all details

### Test 4: Authentication Error
- [ ] Remove connection credentials
- [ ] Trigger affected flow
- [ ] Verify auth error detected
- [ ] Check error categorization

### Test 5: Monitor Self-Failure
- [ ] Intentionally break monitor (wrong flow ID)
- [ ] Verify you notice it's broken
- [ ] Fix and test recovery

### Test 6: Recovery
- [ ] Cause flow to fail
- [ ] Wait for alert
- [ ] Fix the flow
- [ ] Verify next check shows success
- [ ] Optional: Send recovery notification

---

## Success Metrics

Track these to measure effectiveness:

### Detection Metrics:
- **Mean Time To Detect (MTTD):** How long until failure is noticed
  - Target: < 15 minutes
- **Detection Rate:** % of failures caught by monitor
  - Target: 100%
- **False Positive Rate:** % of alerts that aren't real issues
  - Target: < 5%

### Response Metrics:
- **Mean Time To Resolution (MTTR):** How long to fix
  - Target: < 1 hour for critical
- **Acknowledgment Time:** How long until someone looks
  - Target: < 30 minutes

### Reliability Metrics:
- **Monitor Uptime:** % of time monitor itself is working
  - Target: 99%+
- **Alert Delivery Rate:** % of alerts successfully sent
  - Target: 100%

**Track in SharePoint List:**
Create "Monitor Metrics" list to log:
- Date
- Failures Detected
- False Positives
- MTTD (minutes)
- MTTR (minutes)
- Monitor Uptime %

Build Power BI dashboard to visualize trends.

---

## Advanced Troubleshooting: Logs

### Enable Detailed Logging

Add logging to understand what's happening:

**Log to SharePoint List:**

Create "Monitor Debug Logs" list:
- Timestamp
- Action
- Details
- Status

**In Monitor Flow, Add Create Item Actions:**
```
After each major action:
Create item:
  Timestamp: utcNow()
  Action: "List flow runs for [FlowName]"
  Details: "Found [count] runs, [count] failed"
  Status: "Success"
```

This creates audit trail for troubleshooting.

**Review Logs:**
```
1. Open SharePoint list
2. Filter to today
3. Look for patterns
4. Identify where monitor is failing
```

---

## Rollback Procedure

If new version has issues, roll back:

### Step 1: Export Current Version
```
1. Open monitor flow
2. Export flow (top menu)
3. Save .zip file with date
```

### Step 2: Restore Previous Version
```
1. Go to run history
2. Find last successful run
3. Note the date
4. Import the backup from before that date
```

### Step 3: Verify
```
1. Test the restored version
2. Verify it works
3. Document what went wrong
```

---

## Contact Information

Keep this updated with your team's info:

```
Monitor Owner: ___________________________
Email: ___________________________
Team: ___________________________

Backup Contact: ___________________________
Email: ___________________________

Escalation Path:
1. ___________________________
2. ___________________________
3. ___________________________

Documentation Location:
- Implementation Guide: [Link]
- Troubleshooting Guide: [Link]
- Alert Templates: [Link]

Support Channels:
- Teams Channel: ___________________________
- Ticket System: ___________________________
- Email: ___________________________
```

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**For:** Flow Error Monitor Project
