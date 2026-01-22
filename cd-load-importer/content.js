// CD Load Importer - Content Script v5
// Injects "Import to TMS" button with pre-import modal
// Works INDEPENDENTLY - does NOT require Super Dispatch extension

(function() {
  'use strict';

  const DEBUG = true;
  const log = (...args) => DEBUG && console.log('[CD Importer]', ...args);

  // Global lock to prevent concurrent injection runs
  let isInjecting = false;

  // Load categories for Future Cars
  const LOAD_CATEGORIES = [
    { id: 'ny_to_home', name: 'NY to Home', subs: [
      { id: 'ny_sf', name: 'San Francisco' },
      { id: 'ny_la', name: 'Los Angeles' },
      { id: 'ny_tn', name: 'Tennessee' },
      { id: 'ny_ar', name: 'Arkansas' },
      { id: 'ny_nv', name: 'Nevada' },
      { id: 'ny_ok', name: 'Oklahoma' }
    ]},
    { id: 'home_to_ny', name: 'Home to NY', subs: [] },
    { id: 'home_to_ca', name: 'Home to CA', subs: [
      { id: 'ca_sf', name: 'San Francisco' },
      { id: 'ca_la', name: 'Los Angeles' }
    ]},
    { id: 'ca_to_home', name: 'CA to Home', subs: [] },
    { id: 'fl_to_ca', name: 'FL to CA', subs: [] },
    { id: 'fl_to_home', name: 'FL to Home', subs: [] },
    { id: 'ny_to_fl', name: 'NY to FL', subs: [] }
  ];

  // Vehicle directions for trip assignment
  const VEHICLE_DIRECTIONS = [
    { id: 'HOME_TO_CA', label: 'Home to CA' },
    { id: 'CA_TO_HOME', label: 'CA to Home' },
    { id: 'HOME_TO_FL', label: 'Home to FL' },
    { id: 'FL_TO_HOME', label: 'FL to Home' },
    { id: 'FL_TO_CA', label: 'FL to CA' },
    { id: 'CA_TO_FL', label: 'CA to FL' }
  ];

  // Payment types
  const PAYMENT_TYPES = ['COD', 'COP', 'BILL', 'CHECK', 'ACH'];

  // Check if we're on a Central Dispatch page
  function isCentralDispatchPage() {
    return window.location.href.includes('centraldispatch.com');
  }

  // Remove ALL existing TMS buttons (clean slate)
  function removeAllTMSButtons() {
    const existing = document.querySelectorAll('.tms-import-button');
    existing.forEach(btn => btn.remove());
    log(`Removed ${existing.length} existing TMS buttons`);
  }

  // Find all "More Actions" buttons - exactly ONE per dispatch card
  function findMoreActionsButtons() {
    const buttons = [];
    document.querySelectorAll('button, a, [role="button"]').forEach(el => {
      const text = el.textContent?.trim();
      if (text === 'More Actions') {
        buttons.push(el);
      }
    });
    log(`Found ${buttons.length} "More Actions" buttons`);
    return buttons;
  }

  // Find the dispatch content - either a card or the full page
  function findCardFromButton(moreActionsBtn) {
    const isDetailPage = /\/dispatch\/[a-f0-9-]+/i.test(window.location.href);
    if (isDetailPage) {
      const mainContent = document.querySelector('[class*="dispatch"]') ||
                          document.querySelector('main') ||
                          document.body;
      log('Detail page detected, scraping from:', mainContent.tagName);
      return mainContent;
    }

    let el = moreActionsBtn.parentElement;
    for (let i = 0; i < 20 && el && el !== document.body; i++) {
      const text = el.textContent || '';
      if ((text.includes('Load Info') && text.includes('Origin') && text.includes('Destination')) ||
          (text.includes('shipper info') && text.includes('vehicle info') && text.length > 500)) {
        return el;
      }
      el = el.parentElement;
    }

    log('Fallback: using document.body');
    return document.body;
  }

  // Create TMS button
  function createTMSButton(moreActionsBtn) {
    const btn = document.createElement('button');
    btn.className = 'tms-import-button';
    btn.innerHTML = '+ Import to TMS';
    btn.title = 'Import this load to Horizon Star TMS';
    btn.style.cssText = `
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 8px 16px;
      margin-right: 8px;
      background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
      color: white;
      border: none;
      border-radius: 4px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
      transition: all 0.2s;
      white-space: nowrap;
    `;

    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const card = findCardFromButton(moreActionsBtn);
      handleImportClick(btn, card);
    });

    btn.addEventListener('mouseenter', () => {
      btn.style.background = 'linear-gradient(135deg, #16a34a 0%, #15803d 100%)';
      btn.style.transform = 'translateY(-1px)';
    });

    btn.addEventListener('mouseleave', () => {
      btn.style.background = 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)';
      btn.style.transform = 'translateY(0)';
    });

    return btn;
  }

  // Main injection function
  function injectButtons() {
    if (isInjecting) {
      log('Already injecting, skipping...');
      return;
    }
    isInjecting = true;

    try {
      removeAllTMSButtons();
      const moreActionsButtons = findMoreActionsButtons();
      moreActionsButtons.forEach((moreActionsBtn, index) => {
        const tmsBtn = createTMSButton(moreActionsBtn);
        moreActionsBtn.parentElement.insertBefore(tmsBtn, moreActionsBtn);
        log(`Injected TMS button #${index + 1}`);
      });
      log(`Total: Injected ${moreActionsButtons.length} TMS buttons`);
    } finally {
      isInjecting = false;
    }
  }

  // Scrape load data from the dispatch card
  function scrapeLoadDataFromCard(card) {
    log('Scraping from card:', card);

    const data = {
      order_number: '',
      broker_name: '',
      revenue: 0,
      payment_type: '',
      vehicle_year: null,
      vehicle_make: '',
      vehicle_model: '',
      vehicle_vin: '',
      vehicle_color: '',
      origin: '',
      pickup_full_address: '',
      pickup_phone: '',
      pickup_date: '',
      destination: '',
      delivery_full_address: '',
      delivery_phone: '',
      delivery_date: '',
      dispatcher_notes: ''
    };

    const cardText = card.innerText || card.textContent || '';
    log('Card text length:', cardText.length);

    // LOAD ID
    const loadIdMatch = cardText.match(/Load\s*ID\s*\n\s*(.+?)(?:\n|$)/i);
    if (loadIdMatch) {
      data.order_number = loadIdMatch[1].trim().substring(0, 20);
      log('Found Load ID:', data.order_number);
    } else {
      const altOrderMatch = cardText.match(/(\d{4}\s+\d{2}\s+\d{2}\s+[^\n]+?)(?:\n|Total|$)/);
      if (altOrderMatch) {
        data.order_number = altOrderMatch[1].trim().substring(0, 20);
      }
    }

    // BROKER/SHIPPER
    const shipperMatch = cardText.match(/shipper\s*info[\s\S]*?Shipper\s*\n\s*([A-Za-z][\w\s'&.,()-]+?)(?:\n|$)/i);
    if (shipperMatch) {
      data.broker_name = shipperMatch[1].trim().substring(0, 100);
      log('Found Broker:', data.broker_name);
    }

    // TOTAL PRICE
    const priceMatch = cardText.match(/Total\s*Price\s*\n?\s*\$?\s*([\d,]+(?:\.\d{2})?)/i);
    if (priceMatch) {
      data.revenue = parseFloat(priceMatch[1].replace(/,/g, ''));
      log('Found Revenue:', data.revenue);
    } else {
      const altPriceMatch = cardText.match(/\$\s*([\d,]+(?:\.\d{2})?)/);
      if (altPriceMatch) {
        data.revenue = parseFloat(altPriceMatch[1].replace(/,/g, ''));
      }
    }

    // PAYMENT TYPE
    const paymentTermsMatch = cardText.match(/Payment\s*Terms[\s\S]*?(Cash|Certified\s*Funds|COD|COP|BILL|CHECK|ACH)/i);
    if (paymentTermsMatch) {
      const term = paymentTermsMatch[1].toUpperCase();
      if (term.includes('CASH') || term.includes('CERTIFIED')) {
        data.payment_type = 'COD';
      } else {
        data.payment_type = term;
      }
      log('Found Payment Type:', data.payment_type);
    }

    // VEHICLE
    const vehicleMatch = cardText.match(/Vehicle\s*Year\/Make\/Model\s*\n\s*(\d{4})\s+([A-Za-z]+)\s+(.+?)(?:\n|$)/i);
    if (vehicleMatch) {
      data.vehicle_year = parseInt(vehicleMatch[1]);
      data.vehicle_make = vehicleMatch[2].trim();
      data.vehicle_model = vehicleMatch[3].trim().substring(0, 50);
      log('Found Vehicle:', data.vehicle_year, data.vehicle_make, data.vehicle_model);
    } else {
      const altVehicleMatch = cardText.match(/(\d{4})\s+([A-Za-z]+)\s+(\d+\s*Series|[A-Za-z0-9]+[A-Za-z0-9\s]*?)(?:\n|VIN|Sedan|Coupe|SUV|$)/i);
      if (altVehicleMatch) {
        const year = parseInt(altVehicleMatch[1]);
        if (year >= 1900 && year <= 2030) {
          data.vehicle_year = year;
          data.vehicle_make = altVehicleMatch[2].trim();
          data.vehicle_model = altVehicleMatch[3].trim().substring(0, 50);
        }
      }
    }

    // VIN - 17 character alphanumeric (no I, O, Q in VINs)
    const vinMatch = cardText.match(/VIN\s*\n?\s*([A-HJ-NPR-Z0-9]{17})/i);
    if (vinMatch) {
      data.vehicle_vin = vinMatch[1].toUpperCase();
      log('Found VIN:', data.vehicle_vin);
    }

    // Vehicle Color
    const colorMatch = cardText.match(/Color\s*\n?\s*([A-Za-z]+(?:\s+[A-Za-z]+)?)/i);
    if (colorMatch) {
      data.vehicle_color = colorMatch[1].trim();
      log('Found Color:', data.vehicle_color);
    }

    // ORIGIN
    const originMatch = cardText.match(/origin\s*info[\s\S]*?\n([A-Z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/);
    if (originMatch) {
      let city = originMatch[1].trim();
      if (!/^[A-Z][a-z]/.test(city)) {
        const altOrigin = cardText.match(/origin\s*info[\s\S]*?\n([A-Z][a-z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/);
        if (altOrigin) {
          city = altOrigin[1].trim();
          data.origin = `${city}, ${altOrigin[2]}`;
          data.pickup_full_address = `${city}, ${altOrigin[2]} ${altOrigin[3]}`;
        }
      } else {
        data.origin = `${city}, ${originMatch[2]}`;
        data.pickup_full_address = `${city}, ${originMatch[2]} ${originMatch[3]}`;
      }
      log('Found Origin:', data.origin);
    }

    // DESTINATION
    const destMatch = cardText.match(/destination\s*info[\s\S]*?\n([A-Z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/);
    if (destMatch) {
      let city = destMatch[1].trim();
      if (!/^[A-Z][a-z]/.test(city)) {
        const altDest = cardText.match(/destination\s*info[\s\S]*?\n([A-Z][a-z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/);
        if (altDest) {
          city = altDest[1].trim();
          data.destination = `${city}, ${altDest[2]}`;
          data.delivery_full_address = `${city}, ${altDest[2]} ${altDest[3]}`;
        }
      } else {
        data.destination = `${city}, ${destMatch[2]}`;
        data.delivery_full_address = `${city}, ${destMatch[2]} ${destMatch[3]}`;
      }
      log('Found Destination:', data.destination);
    }

    // PHONE NUMBERS
    const originPhoneMatch = cardText.match(/origin\s*info[\s\S]*?Contact\s*Info[\s\S]*?\((\d{3})\)\s*(\d{3})-(\d{4})/i);
    if (originPhoneMatch) {
      data.pickup_phone = `(${originPhoneMatch[1]}) ${originPhoneMatch[2]}-${originPhoneMatch[3]}`;
    }

    const destPhoneMatch = cardText.match(/destination\s*info[\s\S]*?Contact\s*Info[\s\S]*?\((\d{3})\)\s*(\d{3})-(\d{4})/i);
    if (destPhoneMatch) {
      data.delivery_phone = `(${destPhoneMatch[1]}) ${destPhoneMatch[2]}-${destPhoneMatch[3]}`;
    }

    // PICKUP DATE
    const datePatterns = [
      /Carrier\s*Pick\s*Up\s*ETA\s*\n?\s*(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Requested\s*Pick\s*Up[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Pick\s*Up[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i
    ];
    for (const pattern of datePatterns) {
      const match = cardText.match(pattern);
      if (match) {
        const parts = match[1].split('/');
        if (parts.length === 3) {
          data.pickup_date = `${parts[2]}-${parts[0].padStart(2, '0')}-${parts[1].padStart(2, '0')}`;
          log('Found Pickup Date:', data.pickup_date);
          break;
        }
      }
    }

    // DELIVERY DATE
    const deliveryDatePatterns = [
      /Expected\s*Delivery[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Delivery\s*Date[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Carrier\s*Delivery\s*ETA\s*\n?\s*(\d{1,2}\/\d{1,2}\/\d{4})/i
    ];
    for (const pattern of deliveryDatePatterns) {
      const match = cardText.match(pattern);
      if (match) {
        const parts = match[1].split('/');
        if (parts.length === 3) {
          data.delivery_date = `${parts[2]}-${parts[0].padStart(2, '0')}-${parts[1].padStart(2, '0')}`;
          log('Found Delivery Date:', data.delivery_date);
          break;
        }
      }
    }

    data.dispatcher_notes = 'Imported from Central Dispatch';

    log('Scraped data:', data);
    return data;
  }

  // Create and show the import modal
  function showImportModal(loadData, tmsBtn, originalText) {
    // Remove any existing modal
    const existingModal = document.getElementById('tms-import-modal');
    if (existingModal) existingModal.remove();

    // Create modal HTML
    const modalHTML = `
      <div id="tms-import-modal" style="
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0,0,0,0.7);
        z-index: 999999;
        display: flex;
        align-items: center;
        justify-content: center;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      ">
        <div style="
          background: #1e293b;
          border-radius: 12px;
          width: 500px;
          max-width: 95vw;
          max-height: 90vh;
          overflow-y: auto;
          box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5);
          color: #e2e8f0;
        ">
          <!-- Header -->
          <div style="
            padding: 16px 20px;
            border-bottom: 1px solid #334155;
            display: flex;
            justify-content: space-between;
            align-items: center;
          ">
            <h2 style="margin: 0; font-size: 18px; font-weight: 600; color: #f1f5f9;">
              Import Load to TMS
            </h2>
            <button id="tms-modal-close" style="
              background: none;
              border: none;
              color: #94a3b8;
              font-size: 24px;
              cursor: pointer;
              padding: 0;
              line-height: 1;
            ">&times;</button>
          </div>

          <!-- Content -->
          <div style="padding: 20px;">
            <!-- Load Details Section -->
            <div style="margin-bottom: 20px;">
              <h3 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #94a3b8; text-transform: uppercase;">
                Load Details
              </h3>
              <div style="display: grid; gap: 12px;">
                <!-- Order Number -->
                <div>
                  <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Order #</label>
                  <input type="text" id="tms-order-number" value="${loadData.order_number || ''}" style="
                    width: 100%;
                    padding: 8px 12px;
                    background: #0f172a;
                    border: 1px solid #334155;
                    border-radius: 6px;
                    color: #e2e8f0;
                    font-size: 14px;
                    box-sizing: border-box;
                  ">
                </div>

                <!-- Vehicle Row -->
                <div style="display: grid; grid-template-columns: 80px 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Year</label>
                    <input type="number" id="tms-vehicle-year" value="${loadData.vehicle_year || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Make</label>
                    <input type="text" id="tms-vehicle-make" value="${loadData.vehicle_make || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Model</label>
                    <input type="text" id="tms-vehicle-model" value="${loadData.vehicle_model || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                </div>

                <!-- VIN Row -->
                <div>
                  <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">VIN</label>
                  <input type="text" id="tms-vehicle-vin" value="${loadData.vehicle_vin || ''}" maxlength="17" placeholder="17-character VIN" style="
                    width: 100%;
                    padding: 8px 12px;
                    background: #0f172a;
                    border: 1px solid #334155;
                    border-radius: 6px;
                    color: #e2e8f0;
                    font-size: 14px;
                    font-family: monospace;
                    text-transform: uppercase;
                    box-sizing: border-box;
                  ">
                </div>

                <!-- Origin/Destination Row -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Origin</label>
                    <input type="text" id="tms-origin" value="${loadData.origin || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Destination</label>
                    <input type="text" id="tms-destination" value="${loadData.destination || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                </div>

                <!-- Price/Payment Row -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Price ($)</label>
                    <input type="number" id="tms-revenue" value="${loadData.revenue || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Payment Type</label>
                    <select id="tms-payment-type" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                      <option value="">Select...</option>
                      ${PAYMENT_TYPES.map(p => `<option value="${p}" ${loadData.payment_type === p ? 'selected' : ''}>${p}</option>`).join('')}
                    </select>
                  </div>
                </div>

                <!-- Broker/Pickup Row -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Broker</label>
                    <input type="text" id="tms-broker" value="${loadData.broker_name || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Pickup Date</label>
                    <input type="date" id="tms-pickup-date" value="${loadData.pickup_date || ''}" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                </div>
              </div>
            </div>

            <!-- Divider -->
            <hr style="border: none; border-top: 1px solid #334155; margin: 20px 0;">

            <!-- Destination Selection -->
            <div style="margin-bottom: 20px;">
              <h3 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #94a3b8; text-transform: uppercase;">
                Where should this load go?
              </h3>

              <!-- Future Cars Option -->
              <label style="
                display: flex;
                align-items: flex-start;
                padding: 12px;
                background: #0f172a;
                border: 2px solid #334155;
                border-radius: 8px;
                cursor: pointer;
                margin-bottom: 8px;
              " id="tms-option-future-cars-label">
                <input type="radio" name="tms-destination-type" value="future_cars" id="tms-option-future-cars" checked style="margin-right: 12px; margin-top: 2px;">
                <div style="flex: 1;">
                  <div style="font-weight: 600; color: #f1f5f9; margin-bottom: 4px;">Future Cars (Load Board)</div>
                  <div style="font-size: 12px; color: #94a3b8;">Add to load board for later assignment</div>

                  <!-- Category Selection -->
                  <div id="tms-future-cars-options" style="margin-top: 12px; display: grid; gap: 8px;">
                    <div>
                      <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Category *</label>
                      <select id="tms-load-category" style="
                        width: 100%;
                        padding: 8px 12px;
                        background: #1e293b;
                        border: 1px solid #334155;
                        border-radius: 6px;
                        color: #e2e8f0;
                        font-size: 14px;
                        box-sizing: border-box;
                      ">
                        <option value="">Select category...</option>
                        ${LOAD_CATEGORIES.map(c => `<option value="${c.id}">${c.name}</option>`).join('')}
                      </select>
                    </div>
                    <div id="tms-subcategory-container" style="display: none;">
                      <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Subcategory</label>
                      <select id="tms-load-subcategory" style="
                        width: 100%;
                        padding: 8px 12px;
                        background: #1e293b;
                        border: 1px solid #334155;
                        border-radius: 6px;
                        color: #e2e8f0;
                        font-size: 14px;
                        box-sizing: border-box;
                      ">
                        <option value="">Select subcategory...</option>
                      </select>
                    </div>
                  </div>
                </div>
              </label>

              <!-- Assign to Trip Option -->
              <label style="
                display: flex;
                align-items: flex-start;
                padding: 12px;
                background: #0f172a;
                border: 2px solid #334155;
                border-radius: 8px;
                cursor: pointer;
              " id="tms-option-trip-label">
                <input type="radio" name="tms-destination-type" value="trip" id="tms-option-trip" style="margin-right: 12px; margin-top: 2px;">
                <div style="flex: 1;">
                  <div style="font-weight: 600; color: #f1f5f9; margin-bottom: 4px;">Assign to Trip</div>
                  <div style="font-size: 12px; color: #94a3b8;">Assign directly to an existing trip</div>

                  <!-- Trip Selection -->
                  <div id="tms-trip-options" style="margin-top: 12px; display: none;">
                    <div style="display: grid; gap: 8px;">
                      <div>
                        <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Trip *</label>
                        <select id="tms-trip-select" style="
                          width: 100%;
                          padding: 8px 12px;
                          background: #1e293b;
                          border: 1px solid #334155;
                          border-radius: 6px;
                          color: #e2e8f0;
                          font-size: 14px;
                          box-sizing: border-box;
                        ">
                          <option value="">Loading trips...</option>
                        </select>
                      </div>
                      <div>
                        <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Vehicle Direction *</label>
                        <select id="tms-vehicle-direction" style="
                          width: 100%;
                          padding: 8px 12px;
                          background: #1e293b;
                          border: 1px solid #334155;
                          border-radius: 6px;
                          color: #e2e8f0;
                          font-size: 14px;
                          box-sizing: border-box;
                        ">
                          <option value="">Select direction...</option>
                          ${VEHICLE_DIRECTIONS.map(d => `<option value="${d.id}">${d.label}</option>`).join('')}
                        </select>
                      </div>
                    </div>
                  </div>
                </div>
              </label>
            </div>

            <!-- Error Message -->
            <div id="tms-modal-error" style="
              display: none;
              padding: 12px;
              background: #7f1d1d;
              border-radius: 6px;
              color: #fecaca;
              font-size: 14px;
              margin-bottom: 16px;
            "></div>

            <!-- Buttons -->
            <div style="display: flex; gap: 12px; justify-content: flex-end;">
              <button id="tms-modal-cancel" style="
                padding: 10px 20px;
                background: #334155;
                border: none;
                border-radius: 6px;
                color: #e2e8f0;
                font-size: 14px;
                font-weight: 500;
                cursor: pointer;
              ">Cancel</button>
              <button id="tms-modal-import" style="
                padding: 10px 20px;
                background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
                border: none;
                border-radius: 6px;
                color: white;
                font-size: 14px;
                font-weight: 600;
                cursor: pointer;
              ">Import Load</button>
            </div>
          </div>
        </div>
      </div>
    `;

    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML);

    const modal = document.getElementById('tms-import-modal');
    const closeBtn = document.getElementById('tms-modal-close');
    const cancelBtn = document.getElementById('tms-modal-cancel');
    const importBtn = document.getElementById('tms-modal-import');
    const futureCarRadio = document.getElementById('tms-option-future-cars');
    const tripRadio = document.getElementById('tms-option-trip');
    const futureCarOptions = document.getElementById('tms-future-cars-options');
    const tripOptions = document.getElementById('tms-trip-options');
    const categorySelect = document.getElementById('tms-load-category');
    const subcategoryContainer = document.getElementById('tms-subcategory-container');
    const subcategorySelect = document.getElementById('tms-load-subcategory');
    const errorDiv = document.getElementById('tms-modal-error');

    // Close modal function
    const closeModal = () => {
      modal.remove();
      tmsBtn.innerHTML = originalText;
      tmsBtn.disabled = false;
      tmsBtn.style.opacity = '1';
    };

    // Event listeners for close/cancel
    closeBtn.addEventListener('click', closeModal);
    cancelBtn.addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeModal();
    });

    // Toggle between Future Cars and Trip options
    const updateOptionVisibility = () => {
      const isFutureCars = futureCarRadio.checked;
      futureCarOptions.style.display = isFutureCars ? 'grid' : 'none';
      tripOptions.style.display = isFutureCars ? 'none' : 'block';

      // Update border colors
      document.getElementById('tms-option-future-cars-label').style.borderColor = isFutureCars ? '#22c55e' : '#334155';
      document.getElementById('tms-option-trip-label').style.borderColor = isFutureCars ? '#334155' : '#22c55e';
    };

    futureCarRadio.addEventListener('change', updateOptionVisibility);
    tripRadio.addEventListener('change', updateOptionVisibility);

    // Handle category change to show/hide subcategories
    categorySelect.addEventListener('change', () => {
      const selectedCategory = LOAD_CATEGORIES.find(c => c.id === categorySelect.value);
      if (selectedCategory && selectedCategory.subs.length > 0) {
        subcategorySelect.innerHTML = '<option value="">Select subcategory...</option>' +
          selectedCategory.subs.map(s => `<option value="${s.id}">${s.name}</option>`).join('');
        subcategoryContainer.style.display = 'block';
      } else {
        subcategoryContainer.style.display = 'none';
        subcategorySelect.value = '';
      }
    });

    // Load trips when trip option is selected
    tripRadio.addEventListener('change', async () => {
      if (tripRadio.checked) {
        const tripSelect = document.getElementById('tms-trip-select');
        tripSelect.innerHTML = '<option value="">Loading trips...</option>';

        try {
          const response = await chrome.runtime.sendMessage({ action: 'getTrips' });
          if (response.success && response.trips) {
            tripSelect.innerHTML = '<option value="">Select trip...</option>' +
              response.trips.map(t => `<option value="${t.id}">${t.trip_number} - ${t.driver_name || 'No driver'}</option>`).join('');
          } else {
            tripSelect.innerHTML = '<option value="">No trips available</option>';
          }
        } catch (err) {
          log('Error loading trips:', err);
          tripSelect.innerHTML = '<option value="">Error loading trips</option>';
        }
      }
    });

    // Handle import
    importBtn.addEventListener('click', async () => {
      errorDiv.style.display = 'none';

      // Gather form data
      const formData = {
        order_number: document.getElementById('tms-order-number').value.trim(),
        vehicle_year: parseInt(document.getElementById('tms-vehicle-year').value) || null,
        vehicle_make: document.getElementById('tms-vehicle-make').value.trim(),
        vehicle_model: document.getElementById('tms-vehicle-model').value.trim(),
        vehicle_vin: document.getElementById('tms-vehicle-vin')?.value.trim().toUpperCase() || null,
        vehicle_color: loadData.vehicle_color || null,
        origin: document.getElementById('tms-origin').value.trim(),
        destination: document.getElementById('tms-destination').value.trim(),
        revenue: parseFloat(document.getElementById('tms-revenue').value) || 0,
        payment_type: document.getElementById('tms-payment-type').value,
        broker_name: document.getElementById('tms-broker').value.trim(),
        pickup_date: document.getElementById('tms-pickup-date').value,
        delivery_date: loadData.delivery_date || null,
        pickup_phone: loadData.pickup_phone,
        delivery_phone: loadData.delivery_phone,
        pickup_full_address: loadData.pickup_full_address,
        delivery_full_address: loadData.delivery_full_address,
        dispatcher_notes: 'Imported from Central Dispatch'
      };

      // Add destination-specific fields
      if (futureCarRadio.checked) {
        const category = document.getElementById('tms-load-category').value;
        if (!category) {
          errorDiv.textContent = 'Please select a category for Future Cars';
          errorDiv.style.display = 'block';
          return;
        }
        formData.load_category = category;
        formData.load_subcategory = document.getElementById('tms-load-subcategory').value || null;
        formData.trip_id = null;
      } else {
        const tripId = document.getElementById('tms-trip-select').value;
        const direction = document.getElementById('tms-vehicle-direction').value;
        if (!tripId) {
          errorDiv.textContent = 'Please select a trip';
          errorDiv.style.display = 'block';
          return;
        }
        if (!direction) {
          errorDiv.textContent = 'Please select a vehicle direction';
          errorDiv.style.display = 'block';
          return;
        }
        formData.trip_id = parseInt(tripId);
        formData.vehicle_direction = direction;
      }

      // Disable button and show loading
      importBtn.disabled = true;
      importBtn.textContent = 'Importing...';

      try {
        const response = await chrome.runtime.sendMessage({
          action: 'importLoad',
          data: formData
        });

        if (response.success) {
          modal.remove();
          tmsBtn.innerHTML = '✓ Imported!';
          tmsBtn.style.background = '#22c55e';
          setTimeout(() => {
            tmsBtn.innerHTML = originalText;
            tmsBtn.disabled = false;
            tmsBtn.style.opacity = '1';
            tmsBtn.style.background = 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)';
          }, 2000);
        } else {
          throw new Error(response.error || 'Import failed');
        }
      } catch (error) {
        log('Import error:', error);

        const isDuplicate = error.message.includes('duplicate key') ||
                            error.message.includes('23505') ||
                            error.message.includes('already exists');

        if (isDuplicate) {
          errorDiv.textContent = 'This load has already been imported to TMS';
        } else {
          errorDiv.textContent = error.message;
        }
        errorDiv.style.display = 'block';
        importBtn.disabled = false;
        importBtn.textContent = 'Import Load';
      }
    });
  }

  // Handle import click
  async function handleImportClick(tmsBtn, card) {
    log('Import button clicked');

    const originalText = tmsBtn.innerHTML;
    tmsBtn.innerHTML = '⏳ Loading...';
    tmsBtn.disabled = true;
    tmsBtn.style.opacity = '0.7';

    try {
      const loadData = scrapeLoadDataFromCard(card);

      // Check what data we were able to extract
      const hasOrderInfo = loadData.order_number || loadData.broker_name;
      const hasVehicleInfo = loadData.vehicle_make || loadData.vehicle_year;
      const hasLocationInfo = loadData.origin || loadData.destination;
      const hasFinancialInfo = loadData.revenue > 0;

      // Need at least SOME useful data to show modal
      if (!hasOrderInfo && !hasVehicleInfo && !hasLocationInfo && !hasFinancialInfo) {
        throw new Error('Could not extract load data from this view. Please click on the load to open the detail page, then try importing from there.');
      }

      // Show the import modal
      showImportModal(loadData, tmsBtn, originalText);

    } catch (error) {
      log('Scrape error:', error);
      tmsBtn.innerHTML = '✕ Error';
      tmsBtn.style.background = '#ef4444';
      tmsBtn.title = error.message;

      setTimeout(() => {
        tmsBtn.innerHTML = originalText;
        tmsBtn.disabled = false;
        tmsBtn.style.opacity = '1';
        tmsBtn.style.background = 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)';
        tmsBtn.title = 'Import this load to Horizon Star TMS';
      }, 3000);
    }
  }

  // Initialize
  function init() {
    log('=== CD LOAD IMPORTER v5 INITIALIZED ===');
    log('URL:', window.location.href);

    if (!isCentralDispatchPage()) {
      log('Not a Central Dispatch page, skipping');
      return;
    }

    setTimeout(injectButtons, 1000);

    let debounceTimer = null;
    const observer = new MutationObserver(() => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(injectButtons, 1500);
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    setTimeout(injectButtons, 3000);
    setTimeout(injectButtons, 5000);
  }

  // Start
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
