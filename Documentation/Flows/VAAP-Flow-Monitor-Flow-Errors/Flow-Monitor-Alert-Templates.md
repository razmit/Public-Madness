# Flow Error Monitor - Alert Templates

This document contains copy-paste ready alert templates for different notification methods.

---

## Email Alert Templates

### Template 1: Basic Text Alert

**Subject:**
```
🚨 Flow Monitoring Alert - Failures Detected
```

**Body:**
```
Flow monitoring has detected failures in your environment.

ALERT DETAILS
=============
Timestamp: [Insert utcNow() expression]
Environment: Production
Failures Detected: [Insert count]

FAILURE DETAILS
===============

[Insert joined AlertMessages]

---
This is an automated alert from Flow Error Monitor.
Please investigate the failed flows and take corrective action.

To view all flows: https://make.powerautomate.com
```

**How to Build in Power Automate:**
1. Add "Send an email (V2)" action
2. To: `admin@company.com`
3. Subject: `🚨 Flow Monitoring Alert - Failures Detected`
4. Body: Copy template above, then:
   - Click where it says [Insert utcNow() expression]
   - Switch to Expression tab
   - Type: `utcNow()`
   - Click where it says [Insert joined AlertMessages]
   - Switch to Expression tab
   - Type: `join(variables('AlertMessages'), '\n\n---\n\n')`

---

### Template 2: HTML Formatted Email

**Subject:**
```
🚨 Production Flow Monitoring - Action Required
```

**Body (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        .header { background-color: #d32f2f; color: white; padding: 20px; }
        .content { padding: 20px; }
        .alert-box {
            background-color: #ffebee;
            border-left: 4px solid #d32f2f;
            padding: 15px;
            margin: 10px 0;
        }
        .footer {
            background-color: #f5f5f5;
            padding: 10px;
            text-align: center;
            font-size: 12px;
            color: #666;
        }
        .button {
            background-color: #2196F3;
            color: white;
            padding: 10px 20px;
            text-decoration: none;
            display: inline-block;
            margin: 10px 0;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚨 Flow Failure Alert</h1>
    </div>

    <div class="content">
        <h2>Alert Summary</h2>
        <p><strong>Timestamp:</strong> [utcNow]</p>
        <p><strong>Environment:</strong> Production</p>
        <p><strong>Status:</strong> ⚠️ Action Required</p>

        <h2>Failure Details</h2>
        <div class="alert-box">
            [Joined AlertMessages with HTML formatting]
        </div>

        <a href="https://make.powerautomate.com" class="button">View Flows</a>

        <h3>Next Steps</h3>
        <ol>
            <li>Click the link above to access Power Automate</li>
            <li>Navigate to the failed flow(s)</li>
            <li>Review the error details in run history</li>
            <li>Take corrective action based on error type</li>
            <li>Re-run or re-enable the flow as needed</li>
        </ol>
    </div>

    <div class="footer">
        <p>This is an automated alert from Flow Error Monitor</p>
        <p>Monitoring configured by: [Your Team]</p>
    </div>
</body>
</html>
```

**Note:** Make sure to enable HTML formatting in the email action.

---

### Template 3: Severity-Based Alert

**Subject (use Condition to set based on criticality):**
- Critical: `🚨🚨🚨 CRITICAL: Flow Failure Requires Immediate Action`
- High: `🚨 HIGH PRIORITY: Flow Failure Detected`
- Medium: `⚠️ Flow Monitoring Alert - Action Needed`
- Low: `ℹ️ Flow Monitoring - Informational Alert`

**Body:**
```
========================================
FLOW MONITORING ALERT
========================================

SEVERITY: [Critical/High/Medium/Low]
TIMESTAMP: [Current Time]
ENVIRONMENT: Production

========================================
FAILURE SUMMARY
========================================

Total Failures: [Count]
Critical Flows Affected: [Count of critical]
Response Time Required: [15 min / 1 hour / 4 hours]

========================================
DETAILED BREAKDOWN
========================================

[For each failure, include:]

Flow Name: [Name]
Criticality: [Critical/High/Medium/Low]
Owner: [Team/Person]
Error Type: [Category]
Time Failed: [Timestamp]

Error Details:
[Error message]

Recommended Action:
[Based on error type]

Direct Link:
[URL to flow run]

----------------------------------------

========================================
ESCALATION POLICY
========================================

Critical: Respond within 15 minutes
High: Respond within 1 hour
Medium: Respond within 4 hours
Low: Respond within next business day

========================================
```

**How to Implement Severity:**
1. Add a "Switch" action after detecting errors
2. Switch on: Expression `item()?['criticality']` (from your flow config)
3. Create cases for Critical, High, Medium, Low
4. Each case sends appropriate alert

---

## Microsoft Teams Alert Templates

### Template 4: Simple Teams Message

**For "Post message in a chat or channel" action:**

```
🚨 **Flow Failure Detected**

**Flow:** [FlowName]
**Status:** Failed
**Time:** [StartTime]

**Error:** [ErrorCode]
[ErrorMessage]

**Action Required:** [RecommendedAction]

[View Flow Run](https://make.powerautomate.com/environments/[env]/flows/[flowId]/runs/[runId])

---
*Automated alert from Flow Error Monitor*
```

---

### Template 5: Teams Adaptive Card (Recommended)

**For "Post adaptive card in a chat or channel" action:**

```json
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.4",
  "body": [
    {
      "type": "Container",
      "style": "attention",
      "items": [
        {
          "type": "TextBlock",
          "text": "🚨 Flow Failure Alert",
          "size": "Large",
          "weight": "Bolder",
          "color": "Attention"
        }
      ]
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
          "value": "Failed ❌"
        },
        {
          "title": "Time:",
          "value": "[StartTime]"
        },
        {
          "title": "Error Code:",
          "value": "[ErrorCode]"
        },
        {
          "title": "Environment:",
          "value": "Production"
        }
      ]
    },
    {
      "type": "Container",
      "style": "emphasis",
      "items": [
        {
          "type": "TextBlock",
          "text": "Error Message",
          "weight": "Bolder"
        },
        {
          "type": "TextBlock",
          "text": "[ErrorMessage]",
          "wrap": true,
          "color": "Attention"
        }
      ]
    },
    {
      "type": "Container",
      "items": [
        {
          "type": "TextBlock",
          "text": "Recommended Action",
          "weight": "Bolder"
        },
        {
          "type": "TextBlock",
          "text": "[RecommendedAction based on error type]",
          "wrap": true
        }
      ]
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "View Run Details",
      "url": "https://make.powerautomate.com/environments/[EnvironmentId]/flows/[FlowId]/runs/[RunId]"
    },
    {
      "type": "Action.OpenUrl",
      "title": "Edit Flow",
      "url": "https://make.powerautomate.com/environments/[EnvironmentId]/flows/[FlowId]/details"
    }
  ]
}
```

**How to Use:**
1. Add "Post adaptive card in a chat or channel" action
2. Select your Team and Channel
3. Paste the JSON above
4. Replace placeholders with dynamic content:
   - Click on `[FlowName]` → Delete → Add dynamic content
   - Repeat for all `[placeholders]`

**Pro Tip:** Use expressions to make the card dynamic:
```javascript
// For the URL action
concat('https://make.powerautomate.com/environments/', items('Apply_to_each')?['environment'], '/flows/', items('Apply_to_each')?['flowId'], '/runs/', items('Apply_to_each_2')?['name'])
```

---

### Template 6: Teams Card with Multiple Failures

```json
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.4",
  "body": [
    {
      "type": "Container",
      "style": "attention",
      "items": [
        {
          "type": "ColumnSet",
          "columns": [
            {
              "type": "Column",
              "width": "auto",
              "items": [
                {
                  "type": "Image",
                  "url": "https://static2.sharepointonline.com/files/fabric/assets/brand-icons/product/svg/power-automate-48.svg",
                  "size": "Medium"
                }
              ]
            },
            {
              "type": "Column",
              "width": "stretch",
              "items": [
                {
                  "type": "TextBlock",
                  "text": "Flow Monitoring Alert",
                  "size": "Large",
                  "weight": "Bolder"
                },
                {
                  "type": "TextBlock",
                  "text": "[Count] failures detected",
                  "size": "Medium",
                  "color": "Attention"
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "type": "TextBlock",
      "text": "Summary",
      "weight": "Bolder",
      "size": "Medium",
      "separator": true
    },
    {
      "type": "FactSet",
      "facts": [
        {
          "title": "Timestamp:",
          "value": "[utcNow]"
        },
        {
          "title": "Environment:",
          "value": "Production"
        },
        {
          "title": "Total Failures:",
          "value": "[Count]"
        }
      ]
    },
    {
      "type": "TextBlock",
      "text": "Failed Flows",
      "weight": "Bolder",
      "size": "Medium",
      "separator": true
    },
    {
      "type": "Container",
      "style": "emphasis",
      "items": [
        {
          "type": "TextBlock",
          "text": "[List of flow names and errors - you'll need to format this dynamically]",
          "wrap": true
        }
      ]
    }
  ],
  "actions": [
    {
      "type": "Action.OpenUrl",
      "title": "Open Power Automate",
      "url": "https://make.powerautomate.com"
    }
  ]
}
```

---

## Push Notification Template (Power Apps)

If you build a Power App, use this for push notifications:

**For "Send push notification" action:**

```
Title: Flow Failure Alert

Body: [FlowName] has failed with error: [ErrorCode]

Link: https://make.powerautomate.com/environments/[env]/flows/[flowId]
```

---

## SMS/Text Alert Template

**For "Send SMS" or Twilio action:**

```
[ALERT] Flow failure detected: [FlowName] failed at [Time] with error [ErrorCode]. Check Power Automate immediately. Ref: [RunId]
```

**Note:** Keep SMS alerts under 160 characters. Only use for critical flows.

---

## Slack Integration Template

**For "Post message" Slack action:**

```
:rotating_light: *Flow Failure Alert*

*Flow:* [FlowName]
*Status:* Failed
*Time:* [StartTime]
*Error:* `[ErrorCode]`

```
[ErrorMessage]
```

*Action Required:* [RecommendedAction]

<https://make.powerautomate.com/environments/[env]/flows/[flowId]|View Flow>

---
_Automated alert from Flow Error Monitor_
```

---

## Alert Composition Helper

### Compose Action Template for Building Alert Messages

Use this in a "Compose" action to format error details before sending:

```
===========================================
FLOW FAILURE DETECTED
===========================================

Flow Details
------------
Name: @{items('Apply_to_each')?['flowName']}
ID: @{items('Apply_to_each')?['flowId']}
Environment: @{items('Apply_to_each')?['environment']}

Run Information
---------------
Run ID: @{items('Apply_to_each_2')?['name']}
Start Time: @{body('Get_flow_run_as_Admin')?['properties']?['startTime']}
End Time: @{body('Get_flow_run_as_Admin')?['properties']?['endTime']}
Status: @{body('Get_flow_run_as_Admin')?['properties']?['status']}

Error Details
-------------
Error Code: @{body('Get_flow_run_as_Admin')?['properties']?['error']?['code']}
Error Message: @{body('Get_flow_run_as_Admin')?['properties']?['error']?['message']}

Troubleshooting
---------------
@{if(equals(body('Get_flow_run_as_Admin')?['properties']?['error']?['code'], 'Unauthorized'), 'This is an authentication error. Check connection credentials and re-authenticate.', if(equals(body('Get_flow_run_as_Admin')?['properties']?['error']?['code'], 'Timeout'), 'This is a timeout error. Review flow performance and external API response times.', 'Review the error message above and check recent flow changes.'))}

Quick Actions
-------------
View Run: https://make.powerautomate.com/environments/@{items('Apply_to_each')?['environment']}/flows/@{items('Apply_to_each')?['flowId']}/runs/@{items('Apply_to_each_2')?['name']}
Edit Flow: https://make.powerautomate.com/environments/@{items('Apply_to_each')?['environment']}/flows/@{items('Apply_to_each')?['flowId']}/details

===========================================
```

---

## Error Categorization Switch Template

Use this logic to send different alerts based on error type:

### Switch Expression:
```javascript
body('Get_flow_run_as_Admin')?['properties']?['error']?['code']
```

### Case 1: Unauthorized

**Alert:**
```
🔐 AUTHENTICATION ERROR

Flow: [FlowName]
Error: Connection authentication failed

IMMEDIATE ACTION REQUIRED:
1. Go to Power Automate
2. Open the flow connections
3. Re-authenticate the failing connection
4. Test the flow

This is typically caused by:
- Expired credentials
- Changed password
- Removed permissions
- Expired OAuth token

Priority: HIGH - Fix within 1 hour
```

### Case 2: Timeout

**Alert:**
```
⏱️ TIMEOUT ERROR

Flow: [FlowName]
Error: Flow execution timed out

RECOMMENDED ACTIONS:
1. Review flow actions for long-running operations
2. Check external API response times
3. Consider implementing pagination
4. Add timeout handling logic

This is typically caused by:
- Slow external APIs
- Large data processing
- Network latency
- Inefficient loops

Priority: MEDIUM - Fix within 4 hours
```

### Case 3: InvalidTemplate

**Alert:**
```
⚠️ CONFIGURATION ERROR

Flow: [FlowName]
Error: Invalid template or expression

RECOMMENDED ACTIONS:
1. Review recent changes to the flow
2. Check all expressions for syntax errors
3. Verify dynamic content references
4. Test in isolation

This is typically caused by:
- Invalid Power Fx expressions
- Missing required parameters
- Type mismatches
- Recent flow modifications

Priority: HIGH - Fix within 1 hour
```

### Case 4: ConnectionAuthenticationFailed

**Alert:**
```
🔌 CONNECTION ERROR

Flow: [FlowName]
Error: Connection authentication failed

IMMEDIATE ACTION REQUIRED:
1. Go to Connections in Power Automate
2. Find the failing connection
3. Click "Fix connection"
4. Re-enter credentials
5. Test the connection

This is typically caused by:
- Expired credentials
- Deleted/disabled service account
- Changed API keys
- Revoked access

Priority: CRITICAL - Fix within 15 minutes
```

### Default Case:

**Alert:**
```
❌ FLOW ERROR

Flow: [FlowName]
Error Code: [ErrorCode]
Error Message: [ErrorMessage]

RECOMMENDED ACTIONS:
1. Review the error message above
2. Check flow run history for patterns
3. Review recent changes
4. Check Power Automate service health

For assistance, contact the Platform Team.

Priority: MEDIUM - Investigate within 4 hours
```

---

## Batch Alert Template

For sending a single summary email instead of individual alerts:

**Subject:**
```
📊 Daily Flow Monitoring Summary - [Date]
```

**Body:**
```
========================================
DAILY FLOW MONITORING SUMMARY
========================================

Report Date: [Current Date]
Environment: Production
Monitoring Period: Last 24 hours

========================================
OVERVIEW
========================================

Total Flows Monitored: [Count]
Total Failures: [Count]
Flows with Issues: [Count]
Critical Failures: [Count]
Resolution Rate: [Percentage]

========================================
FAILURE BREAKDOWN BY CATEGORY
========================================

Authentication Errors: [Count]
Timeout Errors: [Count]
Logic Errors: [Count]
External Service Errors: [Count]
Other Errors: [Count]

========================================
DETAILED FAILURE LIST
========================================

[For each failure, include compact summary]

1. [FlowName] - [ErrorCode] - [Time]
2. [FlowName] - [ErrorCode] - [Time]
...

========================================
TOP 5 MOST PROBLEMATIC FLOWS
========================================

1. [FlowName] - [Count] failures
2. [FlowName] - [Count] failures
3. [FlowName] - [Count] failures
4. [FlowName] - [Count] failures
5. [FlowName] - [Count] failures

========================================
RECOMMENDATIONS
========================================

[Based on patterns detected]

- Consider reviewing authentication for flows with repeated auth errors
- Investigate timeout patterns for high-volume flows
- Review recent changes to flows with new errors

========================================
LINKS
========================================

View All Flows: [URL]
Monitoring Dashboard: [URL if you build Power App]
Historical Reports: [URL if you store in SharePoint]

========================================

This is an automated summary from Flow Error Monitor.
Next summary: [Tomorrow's Date] at [Time]

========================================
```

---

## Weekly Summary Template

**Subject:**
```
📈 Weekly Flow Health Report - Week of [Date]
```

**Body:**
```
========================================
WEEKLY FLOW HEALTH REPORT
========================================

Week: [Start Date] to [End Date]
Environment: Production

========================================
EXECUTIVE SUMMARY
========================================

✅ Overall Health: [Good/Fair/Poor]
📊 Success Rate: [Percentage]
⏱️ Average Resolution Time: [Hours]
📉 Week-over-Week Change: [+/- Percentage]

========================================
KEY METRICS
========================================

Total Flow Runs: [Count]
Successful Runs: [Count] ([Percentage]%)
Failed Runs: [Count] ([Percentage]%)
Fastest Resolution: [Time]
Slowest Resolution: [Time]

========================================
HIGHLIGHTS
========================================

✅ Successes:
- [Notable achievement 1]
- [Notable achievement 2]

⚠️ Concerns:
- [Issue to address 1]
- [Issue to address 2]

========================================
FAILURE ANALYSIS
========================================

Most Common Error: [ErrorCode] ([Count] occurrences)
Most Affected Flow: [FlowName] ([Count] failures)
Peak Failure Time: [Day/Time]

========================================
TREND ANALYSIS
========================================

[Chart or description of trends]
- Authentication errors: [Trend direction]
- Timeout errors: [Trend direction]
- Logic errors: [Trend direction]

========================================
RECOMMENDATIONS FOR NEXT WEEK
========================================

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

========================================
```

---

## Usage Guidelines

### When to Use Each Template:

1. **Basic Text Alert** - Quick setup, works everywhere
2. **HTML Email** - Professional reports, management visibility
3. **Simple Teams Message** - Quick team notifications
4. **Teams Adaptive Card** - Rich, interactive alerts (RECOMMENDED)
5. **SMS** - Critical flows only, immediate attention needed
6. **Batch/Summary** - Reduce alert fatigue, daily/weekly reviews

### Alert Fatigue Prevention:

- Use severity-based routing (Critical → SMS, Medium → Email)
- Batch non-critical alerts
- Send summary reports instead of individual alerts
- Allow team to configure alert preferences
- Implement "snooze" functionality for known issues

---

## Customization Tips

1. **Add Your Branding:**
   - Include company logo in HTML emails
   - Use company colors in Teams cards
   - Add company-specific troubleshooting links

2. **Add Contextual Information:**
   - Link to internal wikis or documentation
   - Include on-call rotation information
   - Add escalation procedures

3. **Make Alerts Actionable:**
   - Include direct links to fix common issues
   - Add buttons to acknowledge/resolve
   - Provide specific remediation steps

4. **Personalize:**
   - Address alerts to specific flow owners
   - Include team-specific Slack channels
   - Reference internal ticket systems

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**For:** Flow Error Monitor Project
