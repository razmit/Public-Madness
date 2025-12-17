# Manual Fix: Associated Owner Group Issues

## Problem
Site owners cannot access "Site Settings > Advanced Permissions" even though they have Full Control, because the **Associated Owner Group** lost its proper association when someone removed Full Control permissions.

---

## ⚠️ Before You Start

**You will need:**
- Site Collection Admin rights on the site
- Access to SharePoint Online
- The name of the site's associated owner group (e.g., "WPs Content Owners")

**Time required:** 5-10 minutes

---

## 🔧 Step-by-Step Fix

### Step 1: Access Site Settings
1. Go to the SharePoint site (e.g., "WPs Content Owners" site)
2. Click the **Settings gear** (⚙️) in the top right
3. Click **Site settings**
   - If you don't see this option, click "Site information" first, then "View all site settings"

---

### Step 2: Go to People and Groups
1. In Site Settings, under **Users and Permissions**, click **People and groups**
2. This will take you to the groups page

---

### Step 3: Verify the Owner Group
1. In the left sidebar, you should see groups like:
   - **WPs Content Owners** ← This is likely your owner group
   - **WPs Content Members**
   - **WPs Content Visitors**
2. Click on **WPs Content Owners** (or whatever the owner group is called)
3. **Note down the members** in this group (you'll verify them later)

---

### Step 4: Go to Site Permissions
1. Click **Settings** (⚙️) > **Site settings** again
2. Under **Users and Permissions**, click **Site permissions**
3. You should see a list of groups and users with permissions

---

### Step 5: Verify Owner Group Has Full Control
1. In the permissions list, find **WPs Content Owners**
2. Check that it shows **Full Control** as the permission level
3. **If it doesn't have Full Control:**
   - Select the checkbox next to the group
   - Click **Edit User Permissions** in the ribbon
   - Check **Full Control**
   - Click **OK**

---

### Step 6: Set Associated Groups (THE CRITICAL STEP)
1. Still on the Site Permissions page
2. Click the **Settings** button in the ribbon (or **Permissions** tab)
3. Click **Site Settings** dropdown
4. Click **Advanced permissions settings** (if available)
5. In the ribbon, click **Settings** > **Site Settings**
6. Look for a link that says **"Set Up Groups for this Site"** or **"Edit the permission levels for this site"**

**Alternative path:**
1. Go back to **Site Settings** (⚙️ > Site settings)
2. Look for **"Site Administration"** section
3. Click **"Site collection administrators"** (verify you're listed)
4. Go back and look for **"Users and Permissions"** section
5. Click **"Advanced permissions settings"**

---

### Step 7: Re-establish Associated Groups
1. On the Permissions page, click **Settings** in the ribbon
2. Click **Site Settings**
3. You should see an option for **"Set Up Groups for this Site"**
   - This may also be under a dropdown menu
4. When the dialog appears, you'll see three dropdowns:
   - **Owners:** Select "WPs Content Owners"
   - **Members:** Select "WPs Content Members" (or appropriate group)
   - **Visitors:** Select "WPs Content Visitors" (or appropriate group)
5. Click **OK**

---

### Step 8: Verify the Fix
1. Have one of the site owners (who couldn't access before):
   - Sign out of SharePoint completely
   - Wait 2-3 minutes
   - Sign back in
   - Go to Site Settings > Site Permissions
2. They should now be able to access **Advanced permissions settings**

---

## 🚨 If You Can't Find "Set Up Groups for this Site"

### Alternative Method: Direct URL
1. Go to your site URL
2. Add this to the end: `/_layouts/15/permsetup.aspx`
   - Full URL example: `https://yourtenant.sharepoint.com/sites/WPsContent/_layouts/15/permsetup.aspx`
3. This should take you directly to the groups setup page
4. Set the three groups as described in Step 7

---

## 🆘 If That STILL Doesn't Work

### Method: Create New Associated Groups from Scratch
1. Go to Site Settings > Site Permissions
2. Create a **NEW** group called "WPs Content Owners NEW"
3. Add all the members from the old "WPs Content Owners" group
4. Give this new group **Full Control**
5. Use the "Set Up Groups" option to set this NEW group as the owner group
6. Once verified working, you can:
   - Remove the old "WPs Content Owners" group
   - Rename "WPs Content Owners NEW" to "WPs Content Owners" (if desired)

---

## ✅ Success Criteria

The fix is successful when:
- ✅ Site owners can access Site Settings > Site Permissions
- ✅ Site owners can click "Advanced permissions settings"
- ✅ Site owners can manage permissions without errors
- ✅ The owner group shows "Full Control" in permissions
- ✅ The owner group is listed as the associated owner group

---

## 📝 Important Notes

1. **Don't remove Full Control from owner group** - This breaks the association
2. **Don't delete the associated owner group** - Creates orphaned associations
3. **Use "Edit User Permissions"** - Don't remove and re-add the group
4. **Wait for propagation** - Changes can take 5-10 minutes to fully apply

---

## 🔗 Related Issues

- **Issue:** "MAPS Content" group was reused, causing confusion
  - **Solution:** Keep associated groups (Owners/Members/Visitors) separate from custom groups

- **Issue:** Subsite can't inherit permissions properly
  - **Solution:** Fix the parent site's owner group first, then subsite will inherit correctly

---

## 📞 If All Else Fails

Contact your SharePoint admin or Microsoft Support with:
- Site URL
- Associated owner group name
- Error messages (if any)
- Screenshots of the permissions page

---

## 🛡️ Prevention Tips

**Tell the site owner:**
1. ❌ **NEVER** remove Full Control from the "Owners" group
2. ❌ **NEVER** delete the associated owner/member/visitor groups
3. ❌ **NEVER** reuse associated groups for other purposes
4. ✅ **DO** create custom groups for special permissions (like "MAPS Content")
5. ✅ **DO** use "Edit User Permissions" to change permission levels
6. ✅ **DO** add/remove members from groups instead of changing group permissions

---

**Good luck! Once this is fixed, consider hiding the advanced permissions settings from the site owner. 😉**
