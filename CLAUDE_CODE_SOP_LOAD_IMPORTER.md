# Claude Code SOP: Build Central Dispatch Load Importer Chrome Extension

## Project Overview

Build a Chrome extension that imports load data from Central Dispatch into your TMS. The extension should work similarly to Super Dispatch and Ship.Cars importers - injecting an "Import to TMS" button on Central Dispatch load pages and scraping the load details when clicked.

---

## PROMPT FOR CLAUDE CODE

Copy and paste this entire prompt into Claude Code:

```
## PROJECT: Central Dispatch Load Importer Chrome Extension

### OBJECTIVE
Build a Chrome Extension (Manifest V3) that:
1. Detects when user is viewing a load on Central Dispatch (centraldispatch.com and site.centraldispatch.com)
2. Injects an "Import to TMS" button on load detail pages
3. When clicked, scrapes all load data from the page
4. Sends the data to TMS API endpoint
5. Shows success/error feedback to user

### TECHNICAL REQUIREMENTS

**Chrome Extension Manifest V3 Structure:**
```
cd-load-importer/
├── manifest.json          # Extension configuration
├── content.js             # Injected into Central Dispatch pages
├── background.js          # Service worker for API calls
├── popup.html             # Extension popup UI
├── popup.js               # Popup logic
├── styles.css             # Button and popup styling
├── icons/
│   ├── icon16.png
│   ├── icon48.png
│   └── icon128.png
└── README.md
```

**manifest.json requirements:**
- manifest_version: 3
- Permissions: activeTab, storage, scripting
- Host permissions for: *://www.centraldispatch.com/*, *://site.centraldispatch.com/*, and your TMS API domain
- Content scripts matching Central Dispatch domains
- Background service worker
- Browser action with popup

### CENTRAL DISPATCH PAGE STRUCTURE

The extension needs to work on these Central Dispatch pages:
1. Main domain: www.centraldispatch.com
2. New subdomain: site.centraldispatch.com
3. Load detail pages in "Dispatched To Me" section
4. Load detail pages in search results

**Data to scrape from load pages:**

SHIPMENT INFO:
- Load/Order ID
- Price/Rate
- Payment terms (COD, COP, etc.)
- Dispatch date
- Estimated pickup date
- Estimated delivery date

PICKUP LOCATION:
- Contact name
- Company name
- Address (street, city, state, zip)
- Phone number
- Special instructions/notes

DELIVERY LOCATION:
- Contact name
- Company name
- Address (street, city, state, zip)
- Phone number
- Special instructions/notes

VEHICLE(S):
- Year
- Make
- Model
- Type (sedan, SUV, truck, etc.)
- VIN (if available)
- Condition (running/non-running)
- Color (if available)

BROKER INFO:
- Broker company name
- Broker MC number
- Contact name
- Phone
- Email

### IMPLEMENTATION STEPS

**Step 1: Create manifest.json**
```json
{
  "manifest_version": 3,
  "name": "CD Load Importer",
  "version": "1.0.0",
  "description": "Import loads from Central Dispatch to TMS",
  "permissions": [
    "activeTab",
    "storage",
    "scripting"
  ],
  "host_permissions": [
    "*://www.centraldispatch.com/*",
    "*://site.centraldispatch.com/*",
    "*://YOUR-TMS-DOMAIN.com/*"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [
    {
      "matches": [
        "*://www.centraldispatch.com/*",
        "*://site.centraldispatch.com/*"
      ],
      "js": ["content.js"],
      "css": ["styles.css"],
      "run_at": "document_idle"
    }
  ],
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  }
}
```

**Step 2: Create content.js**

The content script should:
1. Detect if user is on a load detail page
2. Wait for page to fully load (Central Dispatch uses dynamic content)
3. Inject the "Import to TMS" button in a visible location
4. On button click:
   - Scrape all load data using DOM selectors
   - Show loading state on button
   - Send message to background script with scraped data
   - Show success/error state

Key functions needed:
- `isLoadDetailPage()` - Check if current page is a load detail
- `injectImportButton()` - Add the button to the page
- `scrapeLoadData()` - Extract all load information
- `handleImportClick()` - Process the import action

**Important:** Central Dispatch may use different selectors on www vs site subdomain. The script should handle both.

**Step 3: Create background.js**

The background service worker should:
1. Listen for messages from content script
2. Make API call to TMS with load data
3. Handle authentication (API key from storage)
4. Return success/error to content script

**Step 4: Create popup.html and popup.js**

The popup should:
1. Show connection status to TMS
2. Allow user to enter/save their API key
3. Show recent imports
4. Provide settings (auto-open TMS after import, etc.)

**Step 5: Create styles.css**

Style the import button to:
- Be clearly visible (green background like Ship.Cars uses)
- Have hover and active states
- Show loading spinner during import
- Show checkmark on success, X on error

### DATA FORMAT FOR API

Send scraped data to TMS in this JSON format:

```json
{
  "source": "central_dispatch",
  "source_load_id": "CD123456",
  "imported_at": "2025-01-05T12:00:00Z",
  
  "shipment": {
    "price": 850.00,
    "payment_terms": "COD",
    "dispatch_date": "2025-01-05",
    "pickup_date": "2025-01-07",
    "delivery_date": "2025-01-10",
    "notes": "String of any special instructions"
  },
  
  "pickup": {
    "contact_name": "John Doe",
    "company_name": "ABC Auto Sales",
    "street": "123 Main St",
    "city": "Houston",
    "state": "TX",
    "zip": "77001",
    "phone": "555-123-4567",
    "notes": "Call 30 min before arrival"
  },
  
  "delivery": {
    "contact_name": "Jane Smith",
    "company_name": "XYZ Motors",
    "street": "456 Oak Ave",
    "city": "Dallas",
    "state": "TX",
    "zip": "75201",
    "phone": "555-987-6543",
    "notes": "Delivery hours 9am-5pm"
  },
  
  "vehicles": [
    {
      "year": "2022",
      "make": "Honda",
      "model": "Accord",
      "type": "Sedan",
      "vin": "1HGCV1F34NA000001",
      "condition": "running",
      "color": "Black"
    }
  ],
  
  "broker": {
    "company_name": "Fast Auto Transport",
    "mc_number": "MC-123456",
    "contact_name": "Bob Wilson",
    "phone": "555-555-5555",
    "email": "bob@fastauto.com"
  }
}
```

### ERROR HANDLING

Handle these scenarios:
1. User not logged into Central Dispatch
2. Page structure changed (selectors don't match)
3. Network error sending to TMS
4. TMS API returns error
5. Missing required fields
6. User not configured API key

Show user-friendly error messages for each case.

### TESTING CHECKLIST

- [ ] Extension loads without errors
- [ ] Button appears on www.centraldispatch.com load pages
- [ ] Button appears on site.centraldispatch.com load pages
- [ ] Button doesn't appear on non-load pages
- [ ] Scraping captures all required fields
- [ ] API call sends correct data format
- [ ] Success message shows after import
- [ ] Error messages are clear and helpful
- [ ] Settings save and persist
- [ ] Works after browser restart

### ADDITIONAL FEATURES (PHASE 2)

After basic functionality works:
1. Bulk import - Import multiple loads at once
2. Duplicate detection - Warn if load already imported
3. Rate analysis - Show if rate is good/bad compared to lane average
4. Auto-fill broker info from saved database
5. Quick notes - Add notes before importing

### FILES TO CREATE

Please create all the following files with complete, working code:

1. manifest.json - Extension configuration
2. content.js - DOM manipulation and scraping logic
3. background.js - API communication service worker
4. popup.html - Settings and status popup
5. popup.js - Popup functionality
6. styles.css - Button and UI styling
7. README.md - Installation and usage instructions

### IMPORTANT NOTES

1. Central Dispatch uses dynamic content loading - use MutationObserver or polling to detect when load data is available

2. The site.centraldispatch.com subdomain is newer and may have different HTML structure - handle both

3. Some data fields may not always be present - handle gracefully with defaults or null values

4. The extension should work without requiring page refresh after installation

5. Follow Chrome Extension Manifest V3 best practices - no remote code execution, use service workers not background pages

6. Store API key securely using chrome.storage.sync

7. Add console logging for debugging but make it toggleable

Please build this extension with clean, well-commented code. Start with the core functionality (button injection and basic scraping) and we can iterate from there.
```

---

## HOW TO USE THIS WITH CLAUDE CODE

### Step 1: Start Claude Code
Open your terminal and run:
```bash
claude
```

### Step 2: Create Project Directory
Tell Claude Code:
```
Create a new directory called "cd-load-importer" and cd into it
```

### Step 3: Paste the Prompt
Copy the entire prompt above (everything between the ``` marks) and paste it into Claude Code.

### Step 4: Let Claude Build
Claude Code will create all the files. Review each file as it's created.

### Step 5: Test the Extension

1. Open Chrome and go to: `chrome://extensions/`
2. Enable "Developer mode" (toggle in top right)
3. Click "Load unpacked"
4. Select the `cd-load-importer` folder
5. Go to Central Dispatch and test

### Step 6: Iterate
If something doesn't work, tell Claude Code:
```
The button isn't appearing on site.centraldispatch.com. Can you check the content script and fix it?
```

Or:
```
The scraping isn't getting the vehicle VIN. Can you update the selectors?
```

---

## IMPORTANT: GETTING THE RIGHT SELECTORS

The hardest part is finding the correct CSS selectors for Central Dispatch. Here's how to do it:

### Method 1: Manual Inspection
1. Log into Central Dispatch
2. Go to a load detail page
3. Right-click on the data you want (e.g., pickup address)
4. Click "Inspect"
5. Look at the HTML structure
6. Find unique identifiers (IDs, classes, data attributes)

### Method 2: Ask Claude to Help
Take a screenshot of a Central Dispatch load page and share it with Claude:
```
Here's a screenshot of a Central Dispatch load page. Can you help me identify what CSS selectors might work for scraping the pickup address, delivery address, vehicle info, and price?
```

### Method 3: Console Testing
In Chrome DevTools console, test selectors:
```javascript
// Test if selector finds the element
document.querySelector('.your-selector')

// Get text content
document.querySelector('.your-selector')?.textContent

// Get all matching elements
document.querySelectorAll('.vehicle-row')
```

---

## TMS API ENDPOINT

You'll need to create an API endpoint in your TMS to receive the imported loads. Here's a basic example:

### Node.js/Express Example:
```javascript
app.post('/api/loads/import', authenticateApiKey, async (req, res) => {
  try {
    const loadData = req.body;
    
    // Validate required fields
    if (!loadData.pickup || !loadData.delivery || !loadData.vehicles) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Create load in database
    const newLoad = await Load.create({
      source: loadData.source,
      source_load_id: loadData.source_load_id,
      // ... map all fields
    });
    
    res.json({ 
      success: true, 
      load_id: newLoad.id,
      message: 'Load imported successfully'
    });
    
  } catch (error) {
    res.status(500).json({ error: 'Import failed' });
  }
});
```

---

## TROUBLESHOOTING COMMON ISSUES

### Button not appearing
- Check if content script is being injected (look in DevTools Sources tab)
- Central Dispatch may have changed their HTML structure
- Try adding a delay before injecting button

### Scraping returns empty values
- Page may not be fully loaded - add longer delay or use MutationObserver
- Selectors may be wrong - test in console first
- Data might be in an iframe

### API calls failing
- Check CORS settings on your TMS
- Verify API key is correct
- Check network tab for actual error

### Extension not updating after code changes
- Go to chrome://extensions
- Click the refresh icon on your extension
- Or remove and re-add the unpacked extension

---

## NEXT STEPS AFTER BASIC VERSION WORKS

1. **Add PDF Import** - Parse dispatch sheet PDFs
2. **Add More Load Boards** - CarsArrive, RAT, CarMax
3. **Add AI Analysis** - Use Claude to analyze if load is profitable
4. **Add Broker Vetting** - Pull broker reviews/ratings automatically

Let me know when you're ready to start and I can help you through any issues!
