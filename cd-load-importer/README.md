# CD Load Importer - Chrome Extension

Import loads from Central Dispatch directly to Horizon Star TMS.

## Installation

1. Open Chrome and go to `chrome://extensions/`
2. Enable **Developer mode** (toggle in top right)
3. Click **Load unpacked**
4. Select the `cd-load-importer` folder

## Setup

1. Click the extension icon in Chrome toolbar
2. Enter your Supabase credentials:
   - **Supabase URL**: `https://yrrczhlzulwvdqjwvhtu.supabase.co`
   - **Supabase Anon Key**: Your anon/public key from Supabase dashboard
3. Click **Save Settings**
4. Click **Test Connection** to verify

## Usage

1. Log into Central Dispatch
2. Go to a dispatched load page (e.g., `app.centraldispatch.com/dispatch/.../carrier`)
3. Look for the green **Import to TMS** button
4. Click it to import the load to your TMS

## Supported Pages

- `www.centraldispatch.com`
- `site.centraldispatch.com`
- `app.centraldispatch.com`

## Data Imported

The extension scrapes and imports:
- Order number
- Broker/Shipper info
- Vehicle details (Year, Make, Model, VIN)
- Origin (city, state, zip, contact, phone)
- Destination (city, state, zip, contact, phone)
- Price and payment type (COD/COP/BILL)

## Troubleshooting

### Button not appearing
- Make sure you're on a load detail page
- Try refreshing the page
- Check the browser console for errors

### Import failing
- Verify your Supabase credentials
- Test connection in extension popup
- Check that you have insert permissions on the orders table

### Scraping issues
- Central Dispatch may have changed their page structure
- Check console logs for scraped data
- Report issues with screenshots

## Development

```bash
# View console logs
# Open Chrome DevTools > Console
# Filter by "[CD Importer]"
```

## Files

- `manifest.json` - Extension configuration
- `content.js` - DOM scraping and button injection
- `background.js` - Supabase API calls
- `popup.html/js` - Settings UI
- `styles.css` - Button styling

## License

Private - Horizon Star LLC
