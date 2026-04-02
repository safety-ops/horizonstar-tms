// CD Load Importer - Content Script v5
// Injects "Import to TMS" button with pre-import modal
// Works INDEPENDENTLY - does NOT require Super Dispatch extension

(function() {
  'use strict';

  const DEBUG = true;
  const log = (...args) => DEBUG && console.log('[CD Importer]', ...args);

  // Inject animation styles once
  if (!document.getElementById('tms-importer-animations')) {
    const styleEl = document.createElement('style');
    styleEl.id = 'tms-importer-animations';
    styleEl.textContent = `
      @keyframes tms-spin { to { transform: rotate(360deg); } }
      @keyframes tms-scale-in { 0% { transform: scale(0); opacity: 0; } 60% { transform: scale(1.15); } 100% { transform: scale(1); opacity: 1; } }
      @keyframes tms-fade-up { 0% { opacity: 0; transform: translateY(12px); } 100% { opacity: 1; transform: translateY(0); } }
      .tms-spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid rgba(255,255,255,0.3); border-top-color: #fff; border-radius: 50%; animation: tms-spin 0.6s linear infinite; vertical-align: middle; margin-right: 8px; }
      .tms-loading-overlay { position: absolute; inset: 0; background: rgba(15,23,42,0.7); display: flex; align-items: center; justify-content: center; z-index: 10; border-radius: 8px; }
      .tms-loading-overlay .tms-overlay-spinner { width: 36px; height: 36px; border: 3px solid rgba(255,255,255,0.15); border-top-color: #22c55e; border-radius: 50%; animation: tms-spin 0.7s linear infinite; }
    `;
    document.head.appendChild(styleEl);
  }

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
  const PAYMENT_TYPES = ['BILL', 'COD', 'COP', 'LOCAL_COD', 'CHECK', 'SPLIT'];

  // Escape string for use in HTML attributes
  function escapeAttr(str) {
    return String(str || '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // Check if we're on a Central Dispatch page
  function isCentralDispatchPage() {
    return window.location.href.includes('centraldispatch.com');
  }

  // Remove ALL existing TMS buttons (clean slate)
  function removeAllTMSButtons() {
    const existing = document.querySelectorAll('.tms-import-button');
    existing.forEach(btn => {
      // Remove wrapper parent if it exists
      if (btn.parentElement && btn.parentElement.querySelector('.tms-batch-checkbox')) {
        btn.parentElement.remove();
      } else {
        btn.remove();
      }
    });
    batchSelected.clear();
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
      const textLower = (el.textContent || '').toLowerCase();
      if ((textLower.includes('load info') && textLower.includes('origin') && textLower.includes('destination')) ||
          (textLower.includes('shipper info') && textLower.includes('vehicle info') && textLower.length > 500)) {
        return el;
      }
      el = el.parentElement;
    }

    log('Fallback: using document.body');
    return document.body;
  }

  // Track batch-selected cards
  const batchSelected = new Set();

  function updateBatchBar() {
    let bar = document.getElementById('tms-batch-bar');
    if (batchSelected.size === 0) {
      if (bar) bar.remove();
      return;
    }
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'tms-batch-bar';
      bar.style.cssText = `
        position: fixed; bottom: 0; left: 0; right: 0; z-index: 999998;
        background: #1e293b; border-top: 2px solid #22c55e; padding: 12px 24px;
        display: flex; align-items: center; justify-content: space-between;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        box-shadow: 0 -4px 12px rgba(0,0,0,0.3);
      `;
      document.body.appendChild(bar);
    }
    bar.innerHTML = `
      <span style="color: #e2e8f0; font-size: 14px; font-weight: 600;">
        ${batchSelected.size} load${batchSelected.size > 1 ? 's' : ''} selected
      </span>
      <div style="display: flex; gap: 8px;">
        <button id="tms-batch-clear" style="padding: 8px 16px; background: #334155; border: none; border-radius: 6px; color: #e2e8f0; font-size: 13px; cursor: pointer;">Clear</button>
        <button id="tms-batch-import" style="padding: 8px 16px; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); border: none; border-radius: 6px; color: white; font-size: 13px; font-weight: 600; cursor: pointer;">Import All</button>
      </div>
    `;
    document.getElementById('tms-batch-clear').addEventListener('click', () => {
      batchSelected.clear();
      document.querySelectorAll('.tms-batch-checkbox').forEach(cb => cb.checked = false);
      updateBatchBar();
    });
    document.getElementById('tms-batch-import').addEventListener('click', () => {
      showBatchImportModal();
    });
  }

  // Create TMS button with batch checkbox
  function createTMSButton(moreActionsBtn) {
    const wrapper = document.createElement('span');
    wrapper.style.cssText = 'display: inline-flex; align-items: center; gap: 4px; margin-right: 8px;';

    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'tms-batch-checkbox';
    cb.style.cssText = 'cursor: pointer; width: 16px; height: 16px; accent-color: #22c55e;';
    cb.addEventListener('change', () => {
      if (cb.checked) {
        batchSelected.add(moreActionsBtn);
      } else {
        batchSelected.delete(moreActionsBtn);
      }
      updateBatchBar();
    });
    cb.addEventListener('click', (e) => e.stopPropagation());

    const btn = document.createElement('button');
    btn.className = 'tms-import-button';
    btn.innerHTML = '+ Import to TMS';
    btn.title = 'Import this load to Horizon Star TMS';
    btn.style.cssText = `
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 8px 16px;
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

    wrapper.appendChild(cb);
    wrapper.appendChild(btn);
    return wrapper;
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
      broker_contact_name: '',
      broker_phone: '',
      broker_email: '',
      revenue: 0,
      broker_fee: 0,
      payment_type: '',
      vehicle_year: null,
      vehicle_make: '',
      vehicle_model: '',
      vehicle_vin: '',
      vehicle_color: '',
      vehicle_body_type: '',
      origin: '',
      pickup_full_address: '',
      pickup_address: '',
      pickup_city: '',
      pickup_state: '',
      pickup_zip: '',
      pickup_phone: '',
      pickup_contact_name: '',
      pickup_contact_phone: '',
      pickup_date: '',
      destination: '',
      delivery_full_address: '',
      delivery_address: '',
      delivery_city: '',
      delivery_state: '',
      delivery_zip: '',
      delivery_phone: '',
      delivery_contact_name: '',
      delivery_contact_phone: '',
      dropoff_date: '',
      notes: '',
      dispatcher_notes: '',
      vehicle_lot_number: '',
      vehicle_buyer_number: ''
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

    // BROKER DETAILS (MC#, contact, phone, email)
    const mcMatch = cardText.match(/MC\s*#?\s*:?\s*(\d{4,7})/i);
    const brokerContactMatch = cardText.match(/shipper\s*info[\s\S]*?Contact\s*(?:Name)?\s*\n?\s*([A-Za-z][A-Za-z\s.'-]+?)(?:\n|Contact\s*Info|$)/i);
    if (brokerContactMatch) {
      data.broker_contact_name = brokerContactMatch[1].trim();
      log('Found Broker Contact:', data.broker_contact_name);
    }
    const brokerPhoneMatch = cardText.match(/shipper\s*info[\s\S]*?Contact\s*Info[\s\S]*?\((\d{3})\)\s*(\d{3})-(\d{4})/i);
    if (brokerPhoneMatch) {
      data.broker_phone = `(${brokerPhoneMatch[1]}) ${brokerPhoneMatch[2]}-${brokerPhoneMatch[3]}`;
      log('Found Broker Phone:', data.broker_phone);
    }
    const brokerEmailMatch = cardText.match(/shipper\s*info[\s\S]*?([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/i);
    if (brokerEmailMatch) {
      data.broker_email = brokerEmailMatch[1].trim();
      log('Found Broker Email:', data.broker_email);
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

    // BROKER FEE
    const brokerFeeMatch = cardText.match(/(?:Broker\s*Fee|Commission|Fee)\s*\$?\s*([\d,]+(?:\.\d{2})?)/i);
    if (brokerFeeMatch) {
      data.broker_fee = parseFloat(brokerFeeMatch[1].replace(/,/g, ''));
      log('Found Broker Fee:', data.broker_fee);
    }

    // PAYMENT TYPE
    const paymentTermsMatch = cardText.match(/Payment\s*Terms[\s\S]*?(Cash|Certified\s*Funds|COD|COP|BILL|CHECK|ACH)/i);
    if (paymentTermsMatch) {
      const term = paymentTermsMatch[1].toUpperCase();
      if (term.includes('CASH') || term.includes('CERTIFIED')) {
        data.payment_type = 'COD';
      } else if (term === 'ACH') {
        data.payment_type = 'BILL'; // ACH → BILL in TMS
      } else {
        data.payment_type = term;
      }
      log('Found Payment Type:', data.payment_type);
    }

    // PAYMENT TERMS (Net XX, Quick Pay detection)
    const quickPayMatch = cardText.match(/Quick\s*Pay/i);
    const netTermsMatch = cardText.match(/(?:Net|NET)\s*(\d+)/i);
    if (quickPayMatch) {
      data.payment_terms = 'QUICK_PAY';
      log('Found Payment Terms: QUICK_PAY');
    } else if (netTermsMatch) {
      const days = parseInt(netTermsMatch[1]);
      const termsMapping = { 5: 'NET5', 7: 'NET7', 10: 'NET10', 15: 'NET15', 21: 'NET21', 30: 'NET30', 45: 'NET45', 60: 'NET60' };
      data.payment_terms = termsMapping[days] || 'NET30';
      log('Found Payment Terms:', data.payment_terms);
    } else if (data.payment_type === 'BILL' || data.payment_type === 'SPLIT') {
      data.payment_terms = 'NET30';
      log('Defaulting Payment Terms to NET30 for BILL/SPLIT type');
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
        if (year >= 1900 && year <= new Date().getFullYear() + 2) {
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
    } else {
      // Fallback: match VIN-like pattern with spaces/dashes, strip them
      const vinFallback = cardText.match(/VIN\s*\n?\s*([A-HJ-NPR-Z0-9][\s-]?){17,22}/i);
      if (vinFallback) {
        const cleaned = vinFallback[0].replace(/VIN\s*/i, '').replace(/[\s-]/g, '').toUpperCase();
        if (cleaned.length === 17 && /^[A-HJ-NPR-Z0-9]{17}$/.test(cleaned)) {
          data.vehicle_vin = cleaned;
          log('Found VIN (cleaned):', data.vehicle_vin);
        }
      }
    }

    // Vehicle Color
    const colorMatch = cardText.match(/Color\s*\n?\s*([A-Za-z]+(?:\s+[A-Za-z]+)?)/i);
    if (colorMatch) {
      data.vehicle_color = colorMatch[1].trim();
      log('Found Color:', data.vehicle_color);
    }

    // Vehicle Body Type
    const bodyTypeMatch = cardText.match(/(?:Vehicle\s*Type|Body\s*Style|Type)\s*\n?\s*(Sedan|Coupe|SUV|Truck|Pickup|Van|Minivan|Convertible|Wagon|Hatchback|Crossover)/i);
    if (bodyTypeMatch) {
      data.vehicle_body_type = bodyTypeMatch[1].trim();
      log('Found Body Type:', data.vehicle_body_type);
    }

    // BUYER REFERENCE NUMBER (from origin info section)
    const buyerRefMatch = cardText.match(/Buyer\s*Reference\s*Number\s*\n\s*([^\n-]+)/i);
    if (buyerRefMatch && buyerRefMatch[1].trim() !== '') {
      data.vehicle_buyer_number = buyerRefMatch[1].trim();
      log('Found Buyer Reference:', data.vehicle_buyer_number);
    }

    // ORIGIN
    const originMatch = cardText.match(/origin\s*info[\s\S]*?\n([A-Z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/i);
    if (originMatch) {
      let city = originMatch[1].trim();
      let state = originMatch[2];
      let zip = originMatch[3];
      if (!/^[A-Z][a-z]/.test(city)) {
        const altOrigin = cardText.match(/origin\s*info[\s\S]*?\n([A-Z][a-z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/i);
        if (altOrigin) {
          city = altOrigin[1].trim();
          state = altOrigin[2];
          zip = altOrigin[3];
        }
      }
      data.origin = `${city}, ${state}`;
      data.pickup_full_address = `${city}, ${state} ${zip}`;
      data.pickup_city = city;
      data.pickup_state = state;
      data.pickup_zip = zip;
      log('Found Origin:', data.origin);
    }

    // DESTINATION
    const destMatch = cardText.match(/destination\s*info[\s\S]*?\n([A-Z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/i);
    if (destMatch) {
      let city = destMatch[1].trim();
      let state = destMatch[2];
      let zip = destMatch[3];
      if (!/^[A-Z][a-z]/.test(city)) {
        const altDest = cardText.match(/destination\s*info[\s\S]*?\n([A-Z][a-z][a-zA-Z\s]+),\s*([A-Z]{2})\s+(\d{5})/i);
        if (altDest) {
          city = altDest[1].trim();
          state = altDest[2];
          zip = altDest[3];
        }
      }
      data.destination = `${city}, ${state}`;
      data.delivery_full_address = `${city}, ${state} ${zip}`;
      data.delivery_city = city;
      data.delivery_state = state;
      data.delivery_zip = zip;
      log('Found Destination:', data.destination);
    }

    // STREET ADDRESSES (look for street line before city, state zip)
    const originStreetMatch = cardText.match(/origin\s*info[\s\S]*?\n(\d+\s+[A-Za-z0-9\s.#,]+?)(?:\n[A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})/i);
    if (originStreetMatch) {
      data.pickup_address = originStreetMatch[1].trim();
      log('Found Pickup Address:', data.pickup_address);
    }

    const destStreetMatch = cardText.match(/destination\s*info[\s\S]*?\n(\d+\s+[A-Za-z0-9\s.#,]+?)(?:\n[A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})/i);
    if (destStreetMatch) {
      data.delivery_address = destStreetMatch[1].trim();
      log('Found Delivery Address:', data.delivery_address);
    }

    // Recompose full addresses to include street (matches TMS composeFullAddress pattern)
    if (data.pickup_address && data.pickup_city) {
      data.pickup_full_address = `${data.pickup_address}, ${data.pickup_city}, ${data.pickup_state} ${data.pickup_zip}`;
    }
    if (data.delivery_address && data.delivery_city) {
      data.delivery_full_address = `${data.delivery_address}, ${data.delivery_city}, ${data.delivery_state} ${data.delivery_zip}`;
    }

    // PHONE NUMBERS
    const originPhoneMatch = cardText.match(/origin\s*info[\s\S]*?Contact\s*Info[\s\S]*?\((\d{3})\)\s*(\d{3})-(\d{4})/i);
    if (originPhoneMatch) {
      data.pickup_phone = `(${originPhoneMatch[1]}) ${originPhoneMatch[2]}-${originPhoneMatch[3]}`;
      data.pickup_contact_phone = data.pickup_phone;
    }

    const destPhoneMatch = cardText.match(/destination\s*info[\s\S]*?Contact\s*Info[\s\S]*?\((\d{3})\)\s*(\d{3})-(\d{4})/i);
    if (destPhoneMatch) {
      data.delivery_phone = `(${destPhoneMatch[1]}) ${destPhoneMatch[2]}-${destPhoneMatch[3]}`;
      data.delivery_contact_phone = data.delivery_phone;
    }

    // CONTACT NAMES
    const originContactMatch = cardText.match(/origin\s*info[\s\S]*?Contact\s*Info\s*\n\s*([A-Za-z][A-Za-z\s.'-]+?)(?:\n|\(|$)/i);
    if (originContactMatch) {
      data.pickup_contact_name = originContactMatch[1].trim();
      log('Found Pickup Contact:', data.pickup_contact_name);
    }

    const destContactMatch = cardText.match(/destination\s*info[\s\S]*?Contact\s*Info\s*\n\s*([A-Za-z][A-Za-z\s.'-]+?)(?:\n|\(|$)/i);
    if (destContactMatch) {
      data.delivery_contact_name = destContactMatch[1].trim();
      log('Found Delivery Contact:', data.delivery_contact_name);
    }

    // PICKUP DATE
    const datePatterns = [
      /Carrier\s*Pick\s*Up\s*ETA\s*\n?\s*(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Requested\s*Pick\s*Up[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Pick\s*Up[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i
    ];
    // Also check for ISO format (YYYY-MM-DD)
    const isoPickupMatch = cardText.match(/(?:Carrier\s*Pick\s*Up\s*ETA|Requested\s*Pick\s*Up|Pick\s*Up)[\s\S]*?(\d{4}-\d{2}-\d{2})/i);
    if (isoPickupMatch) {
      data.pickup_date = isoPickupMatch[1];
      log('Found Pickup Date (ISO):', data.pickup_date);
    } else {
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
    }

    // DELIVERY DATE
    const deliveryDatePatterns = [
      /Expected\s*Delivery[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Delivery\s*Date[\s\S]*?(\d{1,2}\/\d{1,2}\/\d{4})/i,
      /Carrier\s*Delivery\s*ETA\s*\n?\s*(\d{1,2}\/\d{1,2}\/\d{4})/i
    ];
    const isoDeliveryMatch = cardText.match(/(?:Expected\s*Delivery|Delivery\s*Date|Carrier\s*Delivery\s*ETA)[\s\S]*?(\d{4}-\d{2}-\d{2})/i);
    if (isoDeliveryMatch) {
      data.dropoff_date = isoDeliveryMatch[1];
      log('Found Delivery Date (ISO):', data.dropoff_date);
    } else {
      for (const pattern of deliveryDatePatterns) {
        const match = cardText.match(pattern);
        if (match) {
          const parts = match[1].split('/');
          if (parts.length === 3) {
            data.dropoff_date = `${parts[2]}-${parts[0].padStart(2, '0')}-${parts[1].padStart(2, '0')}`;
            log('Found Delivery Date:', data.dropoff_date);
            break;
          }
        }
      }
    }

    // NOTES / SPECIAL INSTRUCTIONS
    const notesMatch = cardText.match(/(?:Special\s*Instructions|Additional\s*Info|Notes)\s*\n?\s*([\s\S]+?)(?:\n\n|\n[A-Z][a-z]+\s+Info|$)/i);
    if (notesMatch) {
      data.notes = notesMatch[1].trim().substring(0, 500);
      log('Found Notes:', data.notes);
    }

    // Append MC# to dispatcher notes if found
    data.dispatcher_notes = 'Imported from Central Dispatch';
    if (mcMatch) {
      data.dispatcher_notes += ` | MC# ${mcMatch[1]}`;
      log('Found MC#:', mcMatch[1]);
    }

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
          width: 600px;
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
                  <input type="text" id="tms-order-number" value="${escapeAttr(loadData.order_number)}" style="
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

                <!-- Vehicle Cards (one per vehicle) -->
                <div id="tms-vehicles-container">
                ${(() => {
                  const vehicles = loadData.vehicles && loadData.vehicles.length > 0 ? loadData.vehicles : [{ year: loadData.vehicle_year, make: loadData.vehicle_make, model: loadData.vehicle_model, vin: loadData.vehicle_vin, color: loadData.vehicle_color, body_type: loadData.vehicle_body_type, lot_number: loadData.vehicle_lot_number, buyer_number: loadData.vehicle_buyer_number }];
                  const inputStyle = 'width:100%;padding:8px 12px;background:#0f172a;border:1px solid #334155;border-radius:6px;color:#e2e8f0;font-size:14px;box-sizing:border-box;';
                  const labelStyle = 'display:block;font-size:12px;color:#94a3b8;margin-bottom:4px;';
                  const bodyTypes = ['Sedan','Coupe','SUV','Truck','Pickup','Van','Minivan','Convertible','Wagon','Hatchback','Crossover'];
                  return vehicles.map((v, i) => `
                    <div class="tms-vehicle-card" data-vehicle-index="${i}" style="border:1px solid ${vehicles.length > 1 ? '#334155' : 'transparent'};border-radius:8px;padding:${vehicles.length > 1 ? '10px' : '0'};margin-bottom:${vehicles.length > 1 ? '8px' : '0'};${vehicles.length > 1 ? 'background:rgba(255,255,255,0.02);' : ''}">
                      ${vehicles.length > 1 ? `<div style="font-size:11px;font-weight:600;color:#22c55e;margin-bottom:8px;text-transform:uppercase;">Vehicle ${i + 1} of ${vehicles.length}</div>` : ''}
                      <div style="display:grid;grid-template-columns:80px 1fr 1fr;gap:8px;margin-bottom:8px;">
                        <div><label style="${labelStyle}">Year</label><input type="number" class="tms-v-year" value="${escapeAttr(v.year || '')}" style="${inputStyle}"></div>
                        <div><label style="${labelStyle}">Make</label><input type="text" class="tms-v-make" value="${escapeAttr(v.make || '')}" style="${inputStyle}"></div>
                        <div><label style="${labelStyle}">Model</label><input type="text" class="tms-v-model" value="${escapeAttr(v.model || '')}" style="${inputStyle}"></div>
                      </div>
                      <div style="margin-bottom:8px;"><label style="${labelStyle}">VIN</label><input type="text" class="tms-v-vin" value="${escapeAttr(v.vin || '')}" maxlength="17" placeholder="17-character VIN" style="${inputStyle}font-family:monospace;text-transform:uppercase;"></div>
                      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
                        <div><label style="${labelStyle}">Color</label><input type="text" class="tms-v-color" value="${escapeAttr(v.color || '')}" style="${inputStyle}"></div>
                        <div><label style="${labelStyle}">Body Type</label><select class="tms-v-body" style="${inputStyle}"><option value="">Select...</option>${bodyTypes.map(t => `<option value="${t}" ${(v.body_type || '') === t ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
                      </div>
                    </div>
                  `).join('');
                })()}
                </div>

                <!-- Pickup / Delivery Address Section -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Pickup Address</label>
                    <input type="text" id="tms-pickup-address" value="${escapeAttr(loadData.pickup_address)}" placeholder="Street address" style="
                      width: 100%; padding: 8px 12px; background: #0f172a; border: 1px solid #334155;
                      border-radius: 6px; color: #e2e8f0; font-size: 14px; box-sizing: border-box; margin-bottom: 4px;
                    ">
                    <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 4px;">
                      <input type="text" id="tms-pickup-city" value="${escapeAttr(loadData.pickup_city)}" placeholder="City" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                      <input type="text" id="tms-pickup-state" value="${escapeAttr(loadData.pickup_state)}" placeholder="ST" maxlength="2" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box; text-transform: uppercase;
                      ">
                      <input type="text" id="tms-pickup-zip" value="${escapeAttr(loadData.pickup_zip)}" placeholder="ZIP" maxlength="5" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                    </div>
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Delivery Address</label>
                    <input type="text" id="tms-delivery-address" value="${escapeAttr(loadData.delivery_address)}" placeholder="Street address" style="
                      width: 100%; padding: 8px 12px; background: #0f172a; border: 1px solid #334155;
                      border-radius: 6px; color: #e2e8f0; font-size: 14px; box-sizing: border-box; margin-bottom: 4px;
                    ">
                    <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 4px;">
                      <input type="text" id="tms-delivery-city" value="${escapeAttr(loadData.delivery_city)}" placeholder="City" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                      <input type="text" id="tms-delivery-state" value="${escapeAttr(loadData.delivery_state)}" placeholder="ST" maxlength="2" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box; text-transform: uppercase;
                      ">
                      <input type="text" id="tms-delivery-zip" value="${escapeAttr(loadData.delivery_zip)}" placeholder="ZIP" maxlength="5" style="
                        width: 100%; padding: 6px 10px; background: #0f172a; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                    </div>
                  </div>
                </div>

                <!-- Price/Payment/Broker Fee Row -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Price ($)</label>
                    <input type="number" id="tms-revenue" value="${escapeAttr(loadData.revenue)}" style="
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
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Broker Fee ($)</label>
                    <input type="number" id="tms-broker-fee" value="${escapeAttr(loadData.broker_fee || '')}" placeholder="0.00" style="
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
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Local Fee ($)</label>
                    <input type="number" id="tms-local-fee" value="" placeholder="0.00" style="
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

                <!-- Payment Terms (shown for BILL and SPLIT only) -->
                <div id="tms-payment-terms-group" style="display: ${loadData.payment_type === 'BILL' || loadData.payment_type === 'SPLIT' ? 'block' : 'none'};">
                  <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Payment Terms</label>
                  <select id="tms-payment-terms" style="
                    width: 100%;
                    padding: 8px 12px;
                    background: #0f172a;
                    border: 1px solid #334155;
                    border-radius: 6px;
                    color: #e2e8f0;
                    font-size: 14px;
                    box-sizing: border-box;
                  ">
                    <option value="QUICK_PAY" ${loadData.payment_terms === 'QUICK_PAY' ? 'selected' : ''}>Quick Pay (3 days)</option>
                    <option value="NET5" ${loadData.payment_terms === 'NET5' ? 'selected' : ''}>Net 5</option>
                    <option value="NET7" ${loadData.payment_terms === 'NET7' ? 'selected' : ''}>Net 7</option>
                    <option value="NET10" ${loadData.payment_terms === 'NET10' ? 'selected' : ''}>Net 10</option>
                    <option value="NET15" ${loadData.payment_terms === 'NET15' ? 'selected' : ''}>Net 15</option>
                    <option value="NET21" ${loadData.payment_terms === 'NET21' ? 'selected' : ''}>Net 21</option>
                    <option value="NET30" ${loadData.payment_terms === 'NET30' || !loadData.payment_terms ? 'selected' : ''}>Net 30</option>
                    <option value="NET45" ${loadData.payment_terms === 'NET45' ? 'selected' : ''}>Net 45</option>
                    <option value="NET60" ${loadData.payment_terms === 'NET60' ? 'selected' : ''}>Net 60</option>
                    <option value="COLLECT_AT_DELIVERY" ${loadData.payment_terms === 'COLLECT_AT_DELIVERY' ? 'selected' : ''}>Collect At Delivery</option>
                    <option value="COLLECT_AT_PICKUP" ${loadData.payment_terms === 'COLLECT_AT_PICKUP' ? 'selected' : ''}>Collect At Pick Up</option>
                  </select>
                </div>

                <!-- Split Payment Section (shown when SPLIT selected) -->
                <div id="tms-split-section" style="display: ${loadData.payment_type === 'SPLIT' ? 'grid' : 'none'}; grid-template-columns: 1fr 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">COD/COP Amount ($)</label>
                    <input type="number" id="tms-split-cod-amount" value="" placeholder="0.00" style="
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
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Bill Amount ($)</label>
                    <input type="number" id="tms-split-bill-amount" value="" placeholder="Auto-calculated" readonly style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #1e293b;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #94a3b8;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                  </div>
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Cash Type</label>
                    <select id="tms-split-cash-type" style="
                      width: 100%;
                      padding: 8px 12px;
                      background: #0f172a;
                      border: 1px solid #334155;
                      border-radius: 6px;
                      color: #e2e8f0;
                      font-size: 14px;
                      box-sizing: border-box;
                    ">
                      <option value="COD">COD</option>
                      <option value="COP">COP</option>
                      <option value="LOCAL_COD">LOCAL_COD</option>
                    </select>
                  </div>
                </div>

                <!-- Broker / Pickup Date / Delivery Date Row -->
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px;">
                  <div>
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Broker</label>
                    <input type="text" id="tms-broker" value="${escapeAttr(loadData.broker_name)}" style="
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
                    <input type="date" id="tms-pickup-date" value="${escapeAttr(loadData.pickup_date)}" style="
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
                    <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Delivery Date</label>
                    <input type="date" id="tms-delivery-date" value="${escapeAttr(loadData.dropoff_date)}" style="
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

                <!-- Notes -->
                <div>
                  <label style="display: block; font-size: 12px; color: #94a3b8; margin-bottom: 4px;">Special Instructions / Notes</label>
                  <textarea id="tms-notes" rows="2" placeholder="Any special instructions..." style="
                    width: 100%;
                    padding: 8px 12px;
                    background: #0f172a;
                    border: 1px solid #334155;
                    border-radius: 6px;
                    color: #e2e8f0;
                    font-size: 14px;
                    box-sizing: border-box;
                    resize: vertical;
                    font-family: inherit;
                  ">${escapeAttr(loadData.notes)}</textarea>
                </div>

                <!-- Contact Details (collapsible) -->
                <details style="background: #0f172a; border: 1px solid #334155; border-radius: 6px; padding: 0;">
                  <summary style="padding: 10px 12px; cursor: pointer; font-size: 13px; color: #94a3b8; user-select: none;">
                    Contact Details (pickup &amp; delivery)
                  </summary>
                  <div style="padding: 12px; display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                    <div>
                      <label style="display: block; font-size: 11px; color: #64748b; margin-bottom: 4px;">Pickup Contact</label>
                      <input type="text" id="tms-pickup-contact-name" value="${escapeAttr(loadData.pickup_contact_name)}" placeholder="Name" style="
                        width: 100%; padding: 6px 10px; background: #1e293b; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box; margin-bottom: 4px;
                      ">
                      <input type="text" id="tms-pickup-contact-phone" value="${escapeAttr(loadData.pickup_contact_phone || loadData.pickup_phone)}" placeholder="Phone" style="
                        width: 100%; padding: 6px 10px; background: #1e293b; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                    </div>
                    <div>
                      <label style="display: block; font-size: 11px; color: #64748b; margin-bottom: 4px;">Delivery Contact</label>
                      <input type="text" id="tms-delivery-contact-name" value="${escapeAttr(loadData.delivery_contact_name)}" placeholder="Name" style="
                        width: 100%; padding: 6px 10px; background: #1e293b; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box; margin-bottom: 4px;
                      ">
                      <input type="text" id="tms-delivery-contact-phone" value="${escapeAttr(loadData.delivery_contact_phone || loadData.delivery_phone)}" placeholder="Phone" style="
                        width: 100%; padding: 6px 10px; background: #1e293b; border: 1px solid #334155;
                        border-radius: 4px; color: #e2e8f0; font-size: 13px; box-sizing: border-box;
                      ">
                    </div>
                  </div>
                </details>
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
              padding: 14px 16px;
              background: #7f1d1d;
              border: 1px solid #991b1b;
              border-radius: 8px;
              color: #fecaca;
              font-size: 14px;
              font-weight: 500;
              line-height: 1.5;
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

    // Toggle payment terms and split section visibility based on payment type
    const paymentTypeSelect = document.getElementById('tms-payment-type');
    const paymentTermsGroup = document.getElementById('tms-payment-terms-group');
    const splitSection = document.getElementById('tms-split-section');
    if (paymentTypeSelect && paymentTermsGroup) {
      paymentTypeSelect.addEventListener('change', () => {
        const val = paymentTypeSelect.value;
        paymentTermsGroup.style.display = (val === 'BILL' || val === 'SPLIT') ? 'block' : 'none';
        if (splitSection) {
          splitSection.style.display = val === 'SPLIT' ? 'grid' : 'none';
        }
        // Auto-set payment terms for COD/COP
        const termsSelect = document.getElementById('tms-payment-terms');
        if (val === 'COD' && termsSelect) termsSelect.value = 'COLLECT_AT_DELIVERY';
        else if (val === 'COP' && termsSelect) termsSelect.value = 'COLLECT_AT_PICKUP';
      });
    }

    // Auto-calculate split bill amount = revenue - cod amount
    const splitCodInput = document.getElementById('tms-split-cod-amount');
    const splitBillInput = document.getElementById('tms-split-bill-amount');
    const revenueInput = document.getElementById('tms-revenue');
    if (splitCodInput && splitBillInput && revenueInput) {
      const calcBillAmount = () => {
        const revenue = parseFloat(revenueInput.value) || 0;
        const codAmount = parseFloat(splitCodInput.value) || 0;
        const bill = Math.max(0, revenue - codAmount);
        splitBillInput.value = bill > 0 ? bill.toFixed(2) : '';
      };
      splitCodInput.addEventListener('input', calcBillAmount);
      revenueInput.addEventListener('input', calcBillAmount);
    }

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
          if (response.success && response.trips && response.trips.length > 0) {
            tripSelect.innerHTML = '<option value="">Select trip...</option>' +
              response.trips.map(t => `<option value="${t.id}">${t.trip_number} - ${t.driver_name || 'No driver'} (${t.status})</option>`).join('');
          } else if (response.success) {
            tripSelect.innerHTML = '<option value="">No active trips found</option>';
          } else {
            log('Trip fetch error:', response.error);
            tripSelect.innerHTML = `<option value="">Error: ${response.error || 'Failed to load trips'}</option>`;
          }
        } catch (err) {
          log('Error loading trips:', err);
          tripSelect.innerHTML = '<option value="">Error loading trips — check extension settings</option>';
        }
      }
    });

    // Handle import
    importBtn.addEventListener('click', async () => {
      errorDiv.style.display = 'none';

      // Gather form data
      const formData = {
        order_number: document.getElementById('tms-order-number').value.trim(),
        ...(() => {
          // Read all vehicle cards
          const cards = document.querySelectorAll('.tms-vehicle-card');
          const vehicles = Array.from(cards).map(card => ({
            year: parseInt(card.querySelector('.tms-v-year')?.value) || null,
            make: card.querySelector('.tms-v-make')?.value.trim() || null,
            model: card.querySelector('.tms-v-model')?.value.trim() || null,
            vin: card.querySelector('.tms-v-vin')?.value.trim().toUpperCase() || null,
            color: card.querySelector('.tms-v-color')?.value.trim() || null,
            body_type: card.querySelector('.tms-v-body')?.value || null
          }));
          const first = vehicles[0] || {};
          return {
            vehicle_year: first.year,
            vehicle_make: first.make,
            vehicle_model: first.model,
            vehicle_vin: first.vin,
            vehicle_color: first.color,
            vehicle_body_type: first.body_type,
            vehicle_lot_number: null,
            vehicle_buyer_number: null,
            vehicles: vehicles
          };
        })(),
        origin: (() => {
          const c = document.getElementById('tms-pickup-city')?.value.trim();
          const s = document.getElementById('tms-pickup-state')?.value.trim().toUpperCase();
          return (c && s) ? `${c}, ${s}` : (c || s || '');
        })(),
        destination: (() => {
          const c = document.getElementById('tms-delivery-city')?.value.trim();
          const s = document.getElementById('tms-delivery-state')?.value.trim().toUpperCase();
          return (c && s) ? `${c}, ${s}` : (c || s || '');
        })(),
        revenue: parseFloat(document.getElementById('tms-revenue').value) || 0,
        broker_fee: parseFloat(document.getElementById('tms-broker-fee')?.value) || null,
        local_fee: parseFloat(document.getElementById('tms-local-fee')?.value) || null,
        payment_type: (() => {
          const pt = document.getElementById('tms-payment-type').value;
          if (pt === 'SPLIT') return document.getElementById('tms-split-cash-type')?.value || 'COD';
          return pt;
        })(),
        payment_terms: (() => {
          const pt = document.getElementById('tms-payment-type').value;
          if (pt === 'COD') return 'COLLECT_AT_DELIVERY';
          if (pt === 'COP') return 'COLLECT_AT_PICKUP';
          if (pt === 'BILL' || pt === 'SPLIT') return document.getElementById('tms-payment-terms')?.value || null;
          return null;
        })(),
        cod_amount: document.getElementById('tms-payment-type').value === 'SPLIT' ? (parseFloat(document.getElementById('tms-split-cod-amount')?.value) || null) : null,
        bill_amount: document.getElementById('tms-payment-type').value === 'SPLIT' ? (parseFloat(document.getElementById('tms-split-bill-amount')?.value) || null) : null,
        broker_name: document.getElementById('tms-broker').value.trim(),
        broker_contact_name: loadData.broker_contact_name || null,
        broker_phone: loadData.broker_phone || null,
        broker_email: loadData.broker_email || null,
        pickup_date: document.getElementById('tms-pickup-date').value,
        dropoff_date: document.getElementById('tms-delivery-date')?.value || null,
        pickup_phone: loadData.pickup_phone,
        pickup_contact_name: document.getElementById('tms-pickup-contact-name')?.value.trim() || null,
        pickup_contact_phone: document.getElementById('tms-pickup-contact-phone')?.value.trim() || null,
        delivery_phone: loadData.delivery_phone,
        delivery_contact_name: document.getElementById('tms-delivery-contact-name')?.value.trim() || null,
        delivery_contact_phone: document.getElementById('tms-delivery-contact-phone')?.value.trim() || null,
        pickup_address: document.getElementById('tms-pickup-address')?.value.trim() || null,
        pickup_city: document.getElementById('tms-pickup-city')?.value.trim() || null,
        pickup_state: document.getElementById('tms-pickup-state')?.value.trim().toUpperCase() || null,
        pickup_zip: document.getElementById('tms-pickup-zip')?.value.trim() || null,
        pickup_full_address: (() => {
          const st = document.getElementById('tms-pickup-address')?.value.trim();
          const c = document.getElementById('tms-pickup-city')?.value.trim();
          const s = document.getElementById('tms-pickup-state')?.value.trim().toUpperCase();
          const z = document.getElementById('tms-pickup-zip')?.value.trim();
          if (st && c && s && z) return `${st}, ${c}, ${s} ${z}`;
          if (c && s && z) return `${c}, ${s} ${z}`;
          return null;
        })(),
        delivery_address: document.getElementById('tms-delivery-address')?.value.trim() || null,
        delivery_city: document.getElementById('tms-delivery-city')?.value.trim() || null,
        delivery_state: document.getElementById('tms-delivery-state')?.value.trim().toUpperCase() || null,
        delivery_zip: document.getElementById('tms-delivery-zip')?.value.trim() || null,
        delivery_full_address: (() => {
          const st = document.getElementById('tms-delivery-address')?.value.trim();
          const c = document.getElementById('tms-delivery-city')?.value.trim();
          const s = document.getElementById('tms-delivery-state')?.value.trim().toUpperCase();
          const z = document.getElementById('tms-delivery-zip')?.value.trim();
          if (st && c && s && z) return `${st}, ${c}, ${s} ${z}`;
          if (c && s && z) return `${c}, ${s} ${z}`;
          return null;
        })(),
        notes: document.getElementById('tms-notes')?.value.trim() || null,
        dispatcher_notes: loadData.dispatcher_notes || 'Imported from Central Dispatch'
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

      // Disable button and show loading spinner
      importBtn.disabled = true;
      importBtn.innerHTML = '<span class="tms-spinner"></span>Importing...';

      // Add loading overlay to modal body
      const modalBodyEl = modal.querySelector('[style*="overflow-y"]') || modal.querySelector('div > div');
      let loadingOverlay = null;
      if (modalBodyEl) {
        modalBodyEl.style.position = 'relative';
        loadingOverlay = document.createElement('div');
        loadingOverlay.className = 'tms-loading-overlay';
        loadingOverlay.innerHTML = '<div class="tms-overlay-spinner"></div>';
        modalBodyEl.appendChild(loadingOverlay);
      }

      try {
        const response = await chrome.runtime.sendMessage({
          action: 'importLoad',
          data: formData
        });

        if (response.success) {
          // Remove loading overlay
          if (loadingOverlay) loadingOverlay.remove();

          // Show animated success confirmation inside modal
          const successBody = modalBodyEl || modal.querySelector('[style*="overflow-y"]') || modal.querySelector('div > div');
          const vehicleStr = [formData.vehicle_year, formData.vehicle_make, formData.vehicle_model].filter(Boolean).join(' ');
          const routeStr = [formData.origin, formData.destination].filter(Boolean).join(' → ');

          if (successBody) {
            successBody.innerHTML = `
              <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;padding:40px 20px;text-align:center">
                <div style="width:64px;height:64px;border-radius:50%;background:rgba(34,197,94,0.15);display:flex;align-items:center;justify-content:center;margin-bottom:16px;animation:tms-scale-in 0.5s ease-out">
                  <span style="font-size:32px;color:#22c55e">✓</span>
                </div>
                <h3 style="color:#22c55e;font-size:20px;font-weight:700;margin:0 0 8px;animation:tms-fade-up 0.4s ease-out 0.2s both">Load Imported Successfully!</h3>
                <div style="color:#94a3b8;font-size:14px;margin-bottom:20px;animation:tms-fade-up 0.4s ease-out 0.3s both">The load has been added to your TMS</div>
                <div style="background:#1e293b;border:1px solid #334155;border-radius:8px;padding:16px;width:100%;max-width:360px;text-align:left;animation:tms-fade-up 0.4s ease-out 0.4s both">
                  ${formData.order_number ? `<div style="margin-bottom:8px"><span style="color:#64748b;font-size:12px">ORDER #</span><br><span style="color:#e2e8f0;font-size:15px;font-weight:600">${formData.order_number}</span></div>` : ''}
                  ${vehicleStr ? `<div style="margin-bottom:8px"><span style="color:#64748b;font-size:12px">VEHICLE</span><br><span style="color:#e2e8f0;font-size:14px">${vehicleStr}</span></div>` : ''}
                  ${routeStr ? `<div style="margin-bottom:8px"><span style="color:#64748b;font-size:12px">ROUTE</span><br><span style="color:#e2e8f0;font-size:14px">${routeStr}</span></div>` : ''}
                  ${formData.revenue ? `<div><span style="color:#64748b;font-size:12px">REVENUE</span><br><span style="color:#22c55e;font-size:16px;font-weight:700">$${parseFloat(formData.revenue).toFixed(2)}</span></div>` : ''}
                </div>
                <button id="tms-success-dismiss" style="margin-top:20px;padding:8px 24px;background:#334155;border:none;border-radius:6px;color:#e2e8f0;font-size:13px;cursor:pointer;animation:tms-fade-up 0.4s ease-out 0.5s both">Close</button>
              </div>
            `;
            // Allow manual dismiss
            const dismissBtn = modal.querySelector('#tms-success-dismiss');
            if (dismissBtn) dismissBtn.addEventListener('click', () => modal.remove());
          }

          // Auto-close after 2.5s
          setTimeout(() => { if (modal.parentNode) modal.remove(); }, 2500);

          tmsBtn.innerHTML = '✓ Imported!';
          tmsBtn.style.background = '#22c55e';
          setTimeout(() => {
            tmsBtn.innerHTML = originalText;
            tmsBtn.disabled = false;
            tmsBtn.style.opacity = '1';
            tmsBtn.style.background = 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)';
          }, 3000);
        } else {
          throw new Error(response.error || 'Import failed');
        }
      } catch (error) {
        log('Import error:', error);

        const isDuplicate = error.message.includes('duplicate key') ||
                            error.message.includes('23505') ||
                            error.message.includes('already exists');
        const isConnection = error.message.includes('Failed to fetch') ||
                             error.message.includes('NetworkError') ||
                             error.message.includes('net::');

        let errorMsg;
        if (isDuplicate) {
          const orderNum = formData.order_number || 'unknown';
          errorMsg = `⚠️ This load has already been imported to TMS (Order #${orderNum}). Check your orders list.`;
        } else if (isConnection) {
          errorMsg = '⚠️ Could not connect to TMS. Please check your extension settings and internet connection, then try again.';
        } else {
          errorMsg = `⚠️ Import failed: ${error.message}. Please try again.`;
        }
        if (loadingOverlay) loadingOverlay.remove();
        errorDiv.innerHTML = errorMsg;
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

  // Batch Import Modal
  async function showBatchImportModal() {
    // Scrape all selected cards
    const loads = [];
    for (const moreActionsBtn of batchSelected) {
      const card = findCardFromButton(moreActionsBtn);
      const data = scrapeLoadDataFromCard(card);
      if (data.order_number || data.vehicle_make || data.origin) {
        loads.push(data);
      }
    }

    if (loads.length === 0) {
      alert('No valid loads found in selection.');
      return;
    }

    const existingModal = document.getElementById('tms-batch-modal');
    if (existingModal) existingModal.remove();

    const modalHTML = `
      <div id="tms-batch-modal" style="
        position: fixed; top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.7); z-index: 999999;
        display: flex; align-items: center; justify-content: center;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      ">
        <div style="
          background: #1e293b; border-radius: 12px; width: 600px; max-width: 95vw;
          max-height: 90vh; overflow-y: auto; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); color: #e2e8f0;
        ">
          <div style="padding: 16px 20px; border-bottom: 1px solid #334155; display: flex; justify-content: space-between; align-items: center;">
            <h2 style="margin: 0; font-size: 18px; font-weight: 600; color: #f1f5f9;">
              Batch Import — ${loads.length} Loads
            </h2>
            <button id="tms-batch-modal-close" style="background: none; border: none; color: #94a3b8; font-size: 24px; cursor: pointer;">&times;</button>
          </div>
          <div style="padding: 20px;">
            <div style="margin-bottom: 16px; max-height: 200px; overflow-y: auto; border: 1px solid #334155; border-radius: 6px;">
              <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
                <thead>
                  <tr style="background: #0f172a;">
                    <th style="padding: 8px; text-align: left; color: #94a3b8;">Order #</th>
                    <th style="padding: 8px; text-align: left; color: #94a3b8;">Vehicle</th>
                    <th style="padding: 8px; text-align: left; color: #94a3b8;">Route</th>
                  </tr>
                </thead>
                <tbody>
                  ${loads.map(l => `
                    <tr style="border-top: 1px solid #334155;">
                      <td style="padding: 8px; color: #e2e8f0;">${escapeAttr(l.order_number || '—')}</td>
                      <td style="padding: 8px; color: #e2e8f0;">${escapeAttr([l.vehicle_year, l.vehicle_make, l.vehicle_model].filter(Boolean).join(' ') || '—')}</td>
                      <td style="padding: 8px; color: #e2e8f0;">${escapeAttr(l.origin || '?')} → ${escapeAttr(l.destination || '?')}</td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>

            <h3 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #94a3b8; text-transform: uppercase;">
              Destination for ALL loads
            </h3>
            <div style="display: grid; gap: 8px; margin-bottom: 16px;">
              <label style="display: flex; align-items: center; padding: 12px; background: #0f172a; border: 2px solid #22c55e; border-radius: 8px; cursor: pointer;" id="tms-batch-fc-label">
                <input type="radio" name="tms-batch-dest" value="future_cars" id="tms-batch-fc" checked style="margin-right: 12px;">
                <div>
                  <div style="font-weight: 600; color: #f1f5f9;">Future Cars (Load Board)</div>
                  <div style="margin-top: 8px;">
                    <select id="tms-batch-category" style="width: 100%; padding: 8px 12px; background: #1e293b; border: 1px solid #334155; border-radius: 6px; color: #e2e8f0; font-size: 14px; box-sizing: border-box;">
                      <option value="">Select category...</option>
                      ${LOAD_CATEGORIES.map(c => `<option value="${c.id}">${c.name}</option>`).join('')}
                    </select>
                  </div>
                </div>
              </label>
              <label style="display: flex; align-items: center; padding: 12px; background: #0f172a; border: 2px solid #334155; border-radius: 8px; cursor: pointer;" id="tms-batch-trip-label">
                <input type="radio" name="tms-batch-dest" value="trip" id="tms-batch-trip" style="margin-right: 12px;">
                <div style="flex: 1;">
                  <div style="font-weight: 600; color: #f1f5f9;">Assign to Trip</div>
                  <div style="margin-top: 8px; display: none;" id="tms-batch-trip-options">
                    <select id="tms-batch-trip-select" style="width: 100%; padding: 8px 12px; background: #1e293b; border: 1px solid #334155; border-radius: 6px; color: #e2e8f0; font-size: 14px; box-sizing: border-box;">
                      <option value="">Select trip...</option>
                    </select>
                    <select id="tms-batch-direction" style="width: 100%; margin-top: 8px; padding: 8px 12px; background: #1e293b; border: 1px solid #334155; border-radius: 6px; color: #e2e8f0; font-size: 14px; box-sizing: border-box;">
                      <option value="">Select direction...</option>
                      ${VEHICLE_DIRECTIONS.map(d => `<option value="${d.id}">${d.label}</option>`).join('')}
                    </select>
                  </div>
                </div>
              </label>
            </div>

            <div id="tms-batch-progress" style="display: none; margin-bottom: 16px;">
              <div style="background: #334155; border-radius: 4px; height: 8px; overflow: hidden;">
                <div id="tms-batch-progress-bar" style="background: #22c55e; height: 100%; width: 0%; transition: width 0.3s;"></div>
              </div>
              <div id="tms-batch-progress-text" style="font-size: 12px; color: #94a3b8; margin-top: 4px;"></div>
            </div>

            <div id="tms-batch-results" style="display: none; margin-bottom: 16px; padding: 12px; border-radius: 6px; font-size: 14px;"></div>
            <div id="tms-batch-error" style="display: none; padding: 12px; background: #7f1d1d; border-radius: 6px; color: #fecaca; font-size: 14px; margin-bottom: 16px;"></div>

            <div style="display: flex; gap: 12px; justify-content: flex-end;">
              <button id="tms-batch-cancel" style="padding: 10px 20px; background: #334155; border: none; border-radius: 6px; color: #e2e8f0; font-size: 14px; cursor: pointer;">Cancel</button>
              <button id="tms-batch-go" style="padding: 10px 20px; background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%); border: none; border-radius: 6px; color: white; font-size: 14px; font-weight: 600; cursor: pointer;">Import All (${loads.length})</button>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHTML);

    const modal = document.getElementById('tms-batch-modal');
    const closeModal = () => modal.remove();
    document.getElementById('tms-batch-modal-close').addEventListener('click', closeModal);
    document.getElementById('tms-batch-cancel').addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });

    // Toggle destination options
    const batchFcRadio = document.getElementById('tms-batch-fc');
    const batchTripRadio = document.getElementById('tms-batch-trip');
    const batchTripOptions = document.getElementById('tms-batch-trip-options');
    const toggleBatchDest = () => {
      batchTripOptions.style.display = batchTripRadio.checked ? 'block' : 'none';
      document.getElementById('tms-batch-fc-label').style.borderColor = batchFcRadio.checked ? '#22c55e' : '#334155';
      document.getElementById('tms-batch-trip-label').style.borderColor = batchTripRadio.checked ? '#22c55e' : '#334155';
    };
    batchFcRadio.addEventListener('change', toggleBatchDest);
    batchTripRadio.addEventListener('change', async () => {
      toggleBatchDest();
      if (batchTripRadio.checked) {
        const tripSelect = document.getElementById('tms-batch-trip-select');
        tripSelect.innerHTML = '<option value="">Loading trips...</option>';
        try {
          const response = await chrome.runtime.sendMessage({ action: 'getTrips' });
          if (response.success && response.trips && response.trips.length > 0) {
            tripSelect.innerHTML = '<option value="">Select trip...</option>' +
              response.trips.map(t => `<option value="${t.id}">${t.trip_number} - ${t.driver_name || 'No driver'} (${t.status})</option>`).join('');
          } else if (response.success) {
            tripSelect.innerHTML = '<option value="">No active trips found</option>';
          } else {
            tripSelect.innerHTML = `<option value="">Error: ${response.error || 'Failed to load trips'}</option>`;
          }
        } catch (err) {
          tripSelect.innerHTML = '<option value="">Error loading trips — check extension settings</option>';
        }
      }
    });

    // Import All handler
    document.getElementById('tms-batch-go').addEventListener('click', async () => {
      const errorDiv = document.getElementById('tms-batch-error');
      errorDiv.style.display = 'none';

      // Validate destination
      let destFields = {};
      if (batchFcRadio.checked) {
        const category = document.getElementById('tms-batch-category').value;
        if (!category) {
          errorDiv.textContent = 'Please select a category';
          errorDiv.style.display = 'block';
          return;
        }
        destFields = { load_category: category, trip_id: null };
      } else {
        const tripId = document.getElementById('tms-batch-trip-select').value;
        const direction = document.getElementById('tms-batch-direction').value;
        if (!tripId || !direction) {
          errorDiv.textContent = 'Please select a trip and direction';
          errorDiv.style.display = 'block';
          return;
        }
        destFields = { trip_id: parseInt(tripId), vehicle_direction: direction };
      }

      const goBtn = document.getElementById('tms-batch-go');
      goBtn.disabled = true;
      goBtn.textContent = 'Importing...';

      const progressDiv = document.getElementById('tms-batch-progress');
      const progressBar = document.getElementById('tms-batch-progress-bar');
      const progressText = document.getElementById('tms-batch-progress-text');
      progressDiv.style.display = 'block';

      let imported = 0, failed = 0;
      for (let i = 0; i < loads.length; i++) {
        progressBar.style.width = `${((i + 1) / loads.length) * 100}%`;
        progressText.textContent = `Importing ${i + 1} of ${loads.length}...`;

        const formData = {
          ...loads[i],
          ...destFields,
          dispatcher_notes: loads[i].dispatcher_notes || 'Imported from Central Dispatch'
        };

        try {
          const response = await chrome.runtime.sendMessage({ action: 'importLoad', data: formData });
          if (response.success) {
            imported++;
          } else {
            failed++;
            log('Batch import failed for:', loads[i].order_number, response.error);
          }
        } catch (err) {
          failed++;
          log('Batch import error:', err);
        }

        // 300ms delay between imports
        if (i < loads.length - 1) {
          await new Promise(r => setTimeout(r, 300));
        }
      }

      // Show results
      const resultsDiv = document.getElementById('tms-batch-results');
      resultsDiv.style.display = 'block';
      if (failed === 0) {
        resultsDiv.style.background = 'rgba(34, 197, 94, 0.15)';
        resultsDiv.style.border = '1px solid rgba(34, 197, 94, 0.3)';
        resultsDiv.style.color = '#86efac';
        resultsDiv.innerHTML = `<span style="font-size:18px;margin-right:8px">✓</span> All ${imported} load${imported !== 1 ? 's' : ''} imported successfully to TMS!`;
      } else if (imported === 0) {
        resultsDiv.style.background = 'rgba(239, 68, 68, 0.15)';
        resultsDiv.style.border = '1px solid rgba(239, 68, 68, 0.3)';
        resultsDiv.style.color = '#fca5a5';
        resultsDiv.innerHTML = `<span style="font-size:18px;margin-right:8px">⚠️</span> All ${failed} load${failed !== 1 ? 's' : ''} failed to import. Check your connection and try again.`;
      } else {
        resultsDiv.style.background = 'rgba(234, 179, 8, 0.15)';
        resultsDiv.style.border = '1px solid rgba(234, 179, 8, 0.3)';
        resultsDiv.style.color = '#fde68a';
        resultsDiv.innerHTML = `<span style="font-size:18px;margin-right:8px">⚠️</span> ${imported} load${imported !== 1 ? 's' : ''} imported, ${failed} failed. Failed loads may already exist in TMS.`;
      }

      progressText.textContent = 'Complete';
      goBtn.textContent = 'Done';
      goBtn.addEventListener('click', () => {
        closeModal();
        batchSelected.clear();
        document.querySelectorAll('.tms-batch-checkbox').forEach(cb => cb.checked = false);
        updateBatchBar();
      });
      goBtn.disabled = false;
    });
  }

  // Initialize
  // ============================================================
  // SUPER DISPATCH SUPPORT
  // ============================================================

  function isSuperDispatchPage() {
    return window.location.href.includes('carrier.superdispatch.com');
  }

  function parseSDDate(dateStr) {
    if (!dateStr) return null;
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return null;
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  function parseSDAddress(fullAddr) {
    if (!fullAddr) return {};
    const m = fullAddr.match(/^(.+),\s*(.+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$/);
    if (m) return { street: m[1].trim(), city: m[2].trim(), state: m[3], zip: m[4] };
    const m2 = fullAddr.match(/^(.+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$/);
    if (m2) return { street: '', city: m2[1].trim(), state: m2[2], zip: m2[3] };
    return { street: '', city: fullAddr, state: '', zip: '' };
  }

  function parseSDPaymentType(method, terms) {
    const m = (method || '').toLowerCase();
    const t = (terms || '').toLowerCase();
    if (m.includes('cash') || t.includes('cash on delivery') || m === 'cod') return 'COD';
    if (m.includes('certified') || m === 'cop') return 'COP';
    if (m.includes('zelle')) return 'COD';
    return 'BILL';
  }

  function parseSDPaymentTerms(terms) {
    if (!terms) return null;
    const t = terms.toLowerCase();
    if (t.includes('quick pay')) return 'QUICK_PAY';
    const netMatch = t.match(/(\d+)\s*(?:business\s*)?days?/i);
    if (netMatch) {
      const days = parseInt(netMatch[1], 10);
      const valid = [5, 7, 10, 15, 21, 30, 45, 60];
      const closest = valid.reduce((a, b) => Math.abs(b - days) < Math.abs(a - days) ? b : a);
      return 'NET' + closest;
    }
    if (t.includes('cash on delivery') || t.includes('cod')) return null;
    return 'NET30';
  }

  // Known auto makes for vehicle parsing (used by both detail + list scrapers)
  const KNOWN_MAKES = ['Acura','Alfa Romeo','Aston Martin','Audi','Bentley','BMW','Buick','Cadillac','Chevrolet','Chrysler','Dodge','Ferrari','Fiat','Ford','Genesis','GMC','Honda','Hyundai','Infiniti','Jaguar','Jeep','Kia','Lamborghini','Land Rover','Lexus','Lincoln','Lucid','Maserati','Mazda','McLaren','Mercedes','Mercedes-Benz','Mini','Mitsubishi','Nissan','Polestar','Porsche','Ram','Rivian','Rolls-Royce','Rolls Royce','Saab','Saturn','Scion','Smart','Subaru','Tesla','Toyota','Volkswagen','Volvo'];

  function scrapeSDLoadDetail() {
    log('Scraping Super Dispatch load detail page...');
    const data = {};

    // Helper: parse section text into lines
    const getLines = (el) => el ? el.innerText.split('\n').map(l => l.trim()).filter(Boolean) : [];

    // Load number from heading
    const loadHeading = document.querySelector('[aria-label="Load Number"] h2') || document.querySelector('h2');
    if (loadHeading) {
      const num = loadHeading.textContent.trim().match(/^[\dA-Z]+/);
      if (num) data.order_number = num[0].substring(0, 20);
    }

    // === PICKUP (aria-label="Pickup Details") ===
    const pickupSection = document.querySelector('[aria-label="Pickup Details"]');
    if (pickupSection) {
      const lines = getLines(pickupSection);
      // Address: line with state+zip pattern
      for (const line of lines) {
        if (/[A-Z]{2}\s+\d{5}/.test(line)) {
          data.pickup_full_address = line;
          const parsed = parseSDAddress(line);
          data.pickup_address = parsed.street || '';
          data.pickup_city = parsed.city || '';
          data.pickup_state = parsed.state || '';
          data.pickup_zip = parsed.zip || '';
          if (parsed.city && parsed.state) data.origin = parsed.city + ', ' + parsed.state;
          break;
        }
      }
      // Date: line after "Scheduled for"
      for (let i = 0; i < lines.length; i++) {
        if (lines[i] === 'Scheduled for' && lines[i+1]) {
          data.pickup_date = parseSDDate(lines[i+1]);
          break;
        }
        const dm = lines[i].match(/^([A-Z][a-z]{2}\s+\d{1,2},\s*\d{4})$/);
        if (dm) { data.pickup_date = parseSDDate(dm[1]); break; }
      }
      // Phone: line matching phone pattern
      for (const line of lines) {
        if (/^\+?\d[\d\s()-]{8,}$/.test(line)) {
          data.pickup_phone = line;
          data.pickup_contact_phone = line;
          break;
        }
      }
      // Contact name: line before phone that looks like a name
      for (let i = 0; i < lines.length; i++) {
        if (lines[i] === data.pickup_phone && i > 0 && /^[A-Z][a-z]/.test(lines[i-1]) && !/Scheduled|pickup|delivery|No\s|notes/i.test(lines[i-1])) {
          data.pickup_contact_name = lines[i-1];
          break;
        }
      }
    }

    // === DELIVERY (aria-label="Delivery Details") ===
    const deliverySection = document.querySelector('[aria-label="Delivery Details"]');
    if (deliverySection) {
      const lines = getLines(deliverySection);
      for (const line of lines) {
        if (/[A-Z]{2}\s+\d{5}/.test(line)) {
          data.delivery_full_address = line;
          const parsed = parseSDAddress(line);
          data.delivery_address = parsed.street || '';
          data.delivery_city = parsed.city || '';
          data.delivery_state = parsed.state || '';
          data.delivery_zip = parsed.zip || '';
          if (parsed.city && parsed.state) data.destination = parsed.city + ', ' + parsed.state;
          break;
        }
      }
      for (let i = 0; i < lines.length; i++) {
        if (lines[i] === 'Scheduled for' && lines[i+1]) {
          data.dropoff_date = parseSDDate(lines[i+1]);
          break;
        }
        const dm = lines[i].match(/^([A-Z][a-z]{2}\s+\d{1,2},\s*\d{4})$/);
        if (dm) { data.dropoff_date = parseSDDate(dm[1]); break; }
      }
      for (const line of lines) {
        if (/^\+?\d[\d\s()-]{8,}$/.test(line)) {
          data.delivery_phone = line;
          data.delivery_contact_phone = line;
          break;
        }
      }
      for (let i = 0; i < lines.length; i++) {
        if (lines[i] === data.delivery_phone && i > 0 && /^[A-Z][a-z]/.test(lines[i-1]) && !/Scheduled|pickup|delivery|No\s|notes/i.test(lines[i-1])) {
          data.delivery_contact_name = lines[i-1];
          break;
        }
      }
    }

    // === VEHICLES (aria-label="Vehicles Table") — scrape ALL rows ===
    const vehicleTable = document.querySelector('[aria-label="Vehicles Table"]');
    if (vehicleTable) {
      const rows = vehicleTable.querySelectorAll('tbody tr');
      const allVehicles = [];
      const sortedMakes = [...KNOWN_MAKES].sort((a, b) => b.length - a.length);

      rows.forEach((row, rowIdx) => {
        const vehicle = {};
        const firstCell = row.querySelector('td');
        if (firstCell) {
          const paragraphs = firstCell.querySelectorAll('p');
          const vehicleText = paragraphs[0]?.textContent.trim() || firstCell.textContent.trim();
          const vm = vehicleText.match(/(\d{4})\s+(.+)/);
          if (vm) {
            vehicle.year = parseInt(vm[1], 10);
            const rest = vm[2].trim();
            let matched = false;
            for (const make of sortedMakes) {
              if (rest.toUpperCase().startsWith(make.toUpperCase())) {
                vehicle.make = rest.substring(0, make.length).trim();
                vehicle.model = rest.substring(make.length).trim();
                matched = true;
                break;
              }
            }
            if (!matched) {
              const parts = rest.split(/\s+/);
              vehicle.make = parts[0] || '';
              vehicle.model = parts.slice(1).join(' ') || '';
            }
          }
          if (paragraphs.length >= 2) vehicle.body_type = paragraphs[1].textContent.trim();
          // VIN: raw 17-char string
          for (const p of paragraphs) {
            const t = p.textContent.trim();
            if (/^[A-HJ-NPR-Z0-9]{17}$/i.test(t)) { vehicle.vin = t.toUpperCase(); break; }
          }
          if (!vehicle.vin) {
            const cellVin = firstCell.textContent.match(/([A-HJ-NPR-Z0-9]{17})/i);
            if (cellVin) vehicle.vin = cellVin[1].toUpperCase();
          }
        }
        // Price from cells
        const cells = row.querySelectorAll('td');
        for (const cell of cells) {
          const pm = cell.textContent.match(/\$([\d,]+(?:\.\d{2})?)/);
          if (pm) { vehicle.price = parseFloat(pm[1].replace(/,/g, '')); break; }
        }
        allVehicles.push(vehicle);
      });

      // Set first vehicle in legacy fields (backward compat)
      if (allVehicles.length > 0) {
        const first = allVehicles[0];
        data.vehicle_year = first.year;
        data.vehicle_make = first.make;
        data.vehicle_model = first.model;
        data.vehicle_vin = first.vin;
        data.vehicle_body_type = first.body_type;
        data.revenue = first.price;
      }
      // Store all vehicles in array
      data.vehicles = allVehicles;

      // Total revenue from all vehicles if multi
      if (allVehicles.length > 1) {
        const totalRevenue = allVehicles.reduce((s, v) => s + (v.price || 0), 0);
        if (totalRevenue > 0) data.revenue = totalRevenue;
      }

      // Legacy: get revenue from price column if not set
      if (!data.revenue && rows.length > 0) {
        const cells = rows[0].querySelectorAll('td');
        for (const cell of cells) {
          const pm = cell.textContent.match(/\$([\d,]+(?:\.\d{2})?)/);
          if (pm) { data.revenue = parseFloat(pm[1].replace(/,/g, '')); break; }
        }
      }
    }

    // VIN fallback: try "VIN #: xxx" label format (list page) or raw 17-char in page text
    if (!data.vehicle_vin) {
      const vinMatch = document.body.innerText.match(/VIN\s*#?\s*:?\s*([A-HJ-NPR-Z0-9]{17})/i);
      if (vinMatch) data.vehicle_vin = vinMatch[1].toUpperCase();
    }

    // === PAYMENT (aria-label="Payment Agreement Details") ===
    const paymentSection = document.querySelector('[aria-label="Payment Agreement Details"]');
    if (paymentSection) {
      const lines = getLines(paymentSection);
      let method = '', terms = '';
      for (let i = 0; i < lines.length; i++) {
        const lbl = lines[i].toLowerCase();
        const val = lines[i+1] || '';
        if (lbl === 'price') {
          const pm = val.match(/\$([\d,]+(?:\.\d{2})?)/);
          if (pm && !data.revenue) data.revenue = parseFloat(pm[1].replace(/,/g, ''));
        }
        if (lbl === 'method') method = val;
        if (lbl === 'terms') terms = val;
        if (lbl === 'broker fee' && val !== 'No details') {
          const bf = val.match(/\$([\d,]+(?:\.\d{2})?)/);
          if (bf) data.broker_fee = parseFloat(bf[1].replace(/,/g, ''));
        }
      }
      data.payment_type = parseSDPaymentType(method, terms);
      data.payment_terms = parseSDPaymentTerms(terms);
    }

    // === CUSTOMER / BROKER (aria-label="Customer Details") ===
    const customerSection = document.querySelector('[aria-label="Customer Details"]');
    if (customerSection) {
      const lines = getLines(customerSection);
      // Line-by-line parsing:
      // "Customer Information" (heading), Company name, Address, "Billing", email, contact name, phone, support email
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        // Company name: first line that's not the heading and not "Billing" etc
        if (!data.broker_name && i > 0 && /[A-Z]/.test(line) && line !== 'Customer Information' && line !== 'Billing' && !line.includes('@') && !/^\+?\d/.test(line) && !/\d{5}/.test(line)) {
          data.broker_name = line;
          continue;
        }
        // Email
        if (line.includes('@') && !data.broker_email) {
          data.broker_email = line;
          continue;
        }
        // Phone
        if (/^\+?\d[\d\s()-]{8,}$/.test(line) && !data.broker_phone) {
          data.broker_phone = line;
          // Contact name is the line before the phone (after "Billing" + email)
          if (i > 0 && /^[A-Z][a-z]/.test(lines[i-1]) && lines[i-1] !== 'Billing' && !lines[i-1].includes('@')) {
            data.broker_contact_name = lines[i-1];
          }
          continue;
        }
      }
    }

    // === DRIVER INSTRUCTIONS ===
    const instructionsHeading = Array.from(document.querySelectorAll('h3')).find(h => h.textContent.includes('Driver Instructions'));
    if (instructionsHeading) {
      const section = instructionsHeading.closest('div');
      const p = section?.querySelector('p');
      if (p) data.notes = p.textContent.trim().substring(0, 500);
    }

    data.dispatcher_notes = 'Imported from Super Dispatch';
    log('Scraped SD data:', data);
    return data;
  }

  function scrapeSDLoadFromListCard(card) {
    log('Scraping SD list card...');
    const data = {};
    const text = card.innerText;

    // Load number — first line, looks like digits or alphanumeric
    const loadNum = text.match(/^([\dA-Z]{5,})/m);
    if (loadNum) data.order_number = loadNum[1].substring(0, 20);

    // Vehicle line: "2019 Land Rover Range Rover" then "Type: SUV" on next line
    const vehicleLine = text.match(/(\d{4})\s+(.+)/m);
    if (vehicleLine) {
      data.vehicle_year = parseInt(vehicleLine[1], 10);
      const rest = vehicleLine[2].trim();
      // Try to match known make (case-insensitive, longest first)
      const sorted = [...KNOWN_MAKES].sort((a, b) => b.length - a.length);
      let matched = false;
      for (const make of sorted) {
        if (rest.toUpperCase().startsWith(make.toUpperCase())) {
          data.vehicle_make = rest.substring(0, make.length).trim();
          data.vehicle_model = rest.substring(make.length).trim();
          matched = true;
          break;
        }
      }
      if (!matched) {
        // Fallback: first word is make, rest is model
        const parts = rest.split(/\s+/);
        data.vehicle_make = parts[0] || '';
        data.vehicle_model = parts.slice(1).join(' ') || '';
      }
    }
    const typeMatch = text.match(/Type:\s*(\w+)/);
    if (typeMatch) data.vehicle_body_type = typeMatch[1];

    const vinMatch = text.match(/VIN\s*#?\s*:?\s*([A-HJ-NPR-Z0-9]{17})/i);
    if (vinMatch) data.vehicle_vin = vinMatch[1].toUpperCase();

    // Price
    const priceMatch = text.match(/\$([\d,]+(?:\.\d{2})?)/);
    if (priceMatch) data.revenue = parseFloat(priceMatch[1].replace(/,/g, ''));

    // Payment type from text
    if (/Cash/i.test(text)) data.payment_type = 'COD';
    else if (/Zelle/i.test(text)) data.payment_type = 'COD';
    else if (/SuperPay/i.test(text)) data.payment_type = 'BILL';
    else data.payment_type = 'BILL';

    // Origin section
    const originBlock = card.querySelector('[class*="origin"], div');
    const originTexts = text.split('ORIGIN')[1]?.split('DESTINATION')[0] || '';
    const addrMatch = originTexts.match(/([^,\n]+),\s*([A-Z]{2})\s+(\d{5})/);
    if (addrMatch) {
      data.pickup_city = addrMatch[1].trim();
      data.pickup_state = addrMatch[2];
      data.pickup_zip = addrMatch[3];
      data.origin = addrMatch[1].trim() + ', ' + addrMatch[2];
    }
    const pickDateMatch = originTexts.match(/([A-Z][a-z]{2}\s+\d{1,2},\s*\d{4})/);
    if (pickDateMatch) data.pickup_date = parseSDDate(pickDateMatch[1]);

    // Destination section
    const destTexts = text.split('DESTINATION')[1]?.split('SHIPPER')[0] || '';
    const destMatch = destTexts.match(/([^,\n]+),\s*([A-Z]{2})\s+(\d{5})/);
    if (destMatch) {
      data.delivery_city = destMatch[1].trim();
      data.delivery_state = destMatch[2];
      data.delivery_zip = destMatch[3];
      data.destination = destMatch[1].trim() + ', ' + destMatch[2];
    }
    const delDateMatch = destTexts.match(/([A-Z][a-z]{2}\s+\d{1,2},\s*\d{4})/);
    if (delDateMatch) data.dropoff_date = parseSDDate(delDateMatch[1]);

    // Shipper/Customer
    const shipperTexts = text.split('SHIPPER/CUSTOMER')[1] || '';
    const shipperName = shipperTexts.match(/\n\s*([A-Za-z][A-Za-z\s&.,()'-]+)/);
    if (shipperName) data.broker_name = shipperName[1].trim();
    const shipperPhone = shipperTexts.match(/Phone:\s*([\d()+-\s]+)/);
    if (shipperPhone) data.broker_phone = shipperPhone[1].trim();

    data.dispatcher_notes = 'Imported from Super Dispatch';
    log('Scraped SD list data:', data);
    return data;
  }

  function injectSDButtons() {
    if (isInjecting) return;
    isInjecting = true;
    try {
      // Remove existing TMS buttons
      document.querySelectorAll('.tms-import-button, .tms-sd-wrapper').forEach(el => el.remove());
      batchSelected.clear();

      const isDetailPage = /\/tms\/loads\/[a-f0-9-]+/.test(window.location.pathname);

      if (isDetailPage) {
        // Detail page: inject button in header next to "Edit Load"
        const editBtn = document.querySelector('a[href*="/edit"]');
        const optionsBtn = document.querySelector('button[aria-label="options menu"]');
        const target = optionsBtn || editBtn;
        if (target && !target.parentElement.querySelector('.tms-import-button')) {
          const btn = document.createElement('button');
          btn.className = 'tms-import-button';
          btn.innerHTML = '<span class="tms-btn-icon">&#x1F69B;</span> Import to TMS';
          btn.style.marginLeft = '8px';
          btn.onclick = () => {
            const loadData = scrapeSDLoadDetail();
            showImportModal(loadData, btn, btn.innerHTML);
          };
          target.parentElement.insertBefore(btn, target.nextSibling);
          log('Injected SD detail page import button');
        }
      } else {
        // List page: find each load card and inject button
        // SD load cards contain "Assign", "Options", "Edit" button groups
        const assignButtons = document.querySelectorAll('button');
        const cardButtons = [];
        assignButtons.forEach(btn => {
          if (btn.textContent.trim() === 'Assign' && !btn.closest('.tms-sd-wrapper')) {
            cardButtons.push(btn);
          }
        });

        cardButtons.forEach((assignBtn, index) => {
          const btnGroup = assignBtn.parentElement;
          if (!btnGroup || btnGroup.querySelector('.tms-import-button')) return;

          // Find the load card (parent container)
          let card = assignBtn;
          for (let i = 0; i < 8; i++) { card = card.parentElement; if (!card) break; }
          if (!card) return;

          const wrapper = document.createElement('span');
          wrapper.className = 'tms-sd-wrapper';
          wrapper.style.cssText = 'display:inline-flex;align-items:center;gap:4px;margin-left:4px;';

          const checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.className = 'tms-batch-checkbox';
          checkbox.style.cssText = 'width:16px;height:16px;cursor:pointer;accent-color:#22c55e;';
          checkbox.dataset.cardIndex = index;
          checkbox.onchange = () => {
            if (checkbox.checked) batchSelected.add(index);
            else batchSelected.delete(index);
            updateBatchBar();
          };

          const btn = document.createElement('button');
          btn.className = 'tms-import-button';
          btn.innerHTML = '<span class="tms-btn-icon">&#x1F69B;</span> Import';
          btn.style.fontSize = '12px';
          btn.style.padding = '6px 10px';
          btn.dataset.cardIndex = index;
          btn.onclick = () => {
            const loadData = scrapeSDLoadFromListCard(card);
            showImportModal(loadData, btn, btn.innerHTML);
          };

          wrapper.appendChild(checkbox);
          wrapper.appendChild(btn);
          btnGroup.appendChild(wrapper);
          log('Injected SD list button #' + (index + 1));
        });
        log('Total SD buttons injected: ' + cardButtons.length);
      }
    } finally {
      isInjecting = false;
    }
  }

  // ============================================================
  // INIT — Route to CD or SD
  // ============================================================

  function init() {
    log('=== LOAD IMPORTER v6 INITIALIZED ===');
    log('URL:', window.location.href);

    if (isSuperDispatchPage()) {
      log('Super Dispatch detected, initializing SD mode');
      setTimeout(injectSDButtons, 1500);
      let debounceTimer = null;
      const observer = new MutationObserver(() => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(injectSDButtons, 2000);
      });
      observer.observe(document.body, { childList: true, subtree: true });
      setTimeout(injectSDButtons, 4000);
      setTimeout(injectSDButtons, 7000);
    } else if (isCentralDispatchPage()) {
      log('Central Dispatch detected, initializing CD mode');
      setTimeout(injectButtons, 1000);
      let debounceTimer = null;
      const observer = new MutationObserver(() => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(injectButtons, 1500);
      });
      observer.observe(document.body, { childList: true, subtree: true });
      setTimeout(injectButtons, 3000);
      setTimeout(injectButtons, 5000);
    } else {
      log('Unknown page, skipping');
    }
  }

  // Start
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
