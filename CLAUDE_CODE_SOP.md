# VroomX TMS - Production Multi-Tenant Platform SOP

## Project Overview

**Product Name:** VroomX TMS
**Project:** Multi-Tenant Transportation Management System SaaS Platform
**Objective:** Transform single-tenant internal TMS into a production-grade, multi-tenant SaaS platform with subscription billing and modern UI/UX.

**Current Tech Stack:**
- Frontend: Vanilla JavaScript (no framework)
- Backend: Supabase (PostgreSQL + Auth + Realtime + Edge Functions)
- Hosting: Netlify
- Email: Resend
- AI: Anthropic Claude API
- Fleet Integration: Samsara API

---

## PHASE 1: Multi-Tenant Database Architecture

### 1.1 Create Core Multi-Tenant Tables

Create Supabase migration for tenant infrastructure:

```sql
-- Organizations (Tenants)
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    logo_url TEXT,
    primary_color VARCHAR(7) DEFAULT '#22c55e',
    timezone VARCHAR(50) DEFAULT 'America/New_York',
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT true,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Organization Members (User-Org relationship)
CREATE TABLE organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'DISPATCHER', -- OWNER, ADMIN, MANAGER, DISPATCHER
    invited_by UUID REFERENCES users(id),
    invited_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    is_primary BOOLEAN DEFAULT false, -- User's primary org
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

-- Subscription Tiers/Plans
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL, -- Starter, Professional, Enterprise
    slug VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    price_monthly DECIMAL(10,2) NOT NULL,
    price_yearly DECIMAL(10,2),
    stripe_price_id_monthly VARCHAR(255),
    stripe_price_id_yearly VARCHAR(255),
    features JSONB DEFAULT '{}',
    limits JSONB DEFAULT '{}', -- { max_users: 5, max_trucks: 10, max_drivers: 20 }
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Organization Subscriptions
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES subscription_plans(id),
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'trialing', -- trialing, active, past_due, canceled, unpaid
    billing_email VARCHAR(255),
    billing_name VARCHAR(255),
    trial_ends_at TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT false,
    canceled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Usage Tracking
CREATE TABLE usage_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL, -- users, trucks, drivers, trips, storage_gb
    current_value INTEGER DEFAULT 0,
    limit_value INTEGER,
    period_start DATE,
    period_end DATE,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Feature Flags per Organization
CREATE TABLE feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    feature_key VARCHAR(100) NOT NULL,
    enabled BOOLEAN DEFAULT false,
    config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, feature_key)
);

-- Invitations
CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'DISPATCHER',
    token VARCHAR(255) UNIQUE NOT NULL,
    invited_by UUID REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 1.2 Add Organization ID to ALL Existing Tables

Every existing table MUST have an `organization_id` column:

```sql
-- Add organization_id to all existing tables
ALTER TABLE users ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE drivers ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE trucks ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE trips ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE orders ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE brokers ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE dispatchers ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE expenses ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE fuel_transactions ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE maintenance_records ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE tasks ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE compliance_tasks ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE tickets ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE violations ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE accidents ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE claims ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE chat_messages ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE notifications ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE local_drivers ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE fleet_mileage ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE driver_applications ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE activity_log ADD COLUMN organization_id UUID REFERENCES organizations(id);
ALTER TABLE app_settings ADD COLUMN organization_id UUID REFERENCES organizations(id);
-- Add to any other tables in the schema

-- Create indexes for performance
CREATE INDEX idx_drivers_org ON drivers(organization_id);
CREATE INDEX idx_trucks_org ON trucks(organization_id);
CREATE INDEX idx_trips_org ON trips(organization_id);
CREATE INDEX idx_orders_org ON orders(organization_id);
-- ... create indexes for all tables
```

### 1.3 Implement Row Level Security (RLS)

```sql
-- Enable RLS on all tables
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
-- ... enable for all tables

-- Create RLS policies (example for drivers table - repeat for ALL tables)
CREATE POLICY "Users can only view their organization's drivers"
ON drivers FOR SELECT
USING (
    organization_id IN (
        SELECT organization_id FROM organization_members
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can only insert to their organization"
ON drivers FOR INSERT
WITH CHECK (
    organization_id IN (
        SELECT organization_id FROM organization_members
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can only update their organization's data"
ON drivers FOR UPDATE
USING (
    organization_id IN (
        SELECT organization_id FROM organization_members
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can only delete their organization's data"
ON drivers FOR DELETE
USING (
    organization_id IN (
        SELECT organization_id FROM organization_members
        WHERE user_id = auth.uid()
        AND role IN ('OWNER', 'ADMIN')
    )
);
```

---

## PHASE 2: Subscription & Billing System (Stripe Integration)

### 2.1 Subscription Plans Structure

```javascript
const SUBSCRIPTION_PLANS = {
    starter: {
        name: 'Starter',
        price_monthly: 49,
        price_yearly: 470, // 2 months free
        limits: {
            max_users: 3,
            max_trucks: 5,
            max_drivers: 10,
            max_trips_monthly: 100,
            storage_gb: 5
        },
        features: {
            dashboard: true,
            trips: true,
            orders: true,
            fleet_management: true,
            basic_reports: true,
            email_support: true,
            // Disabled features
            ai_advisor: false,
            advanced_reports: false,
            ifta_reports: false,
            api_access: false,
            white_label: false,
            priority_support: false
        }
    },
    professional: {
        name: 'Professional',
        price_monthly: 149,
        price_yearly: 1430,
        limits: {
            max_users: 10,
            max_trucks: 25,
            max_drivers: 50,
            max_trips_monthly: 500,
            storage_gb: 25
        },
        features: {
            dashboard: true,
            trips: true,
            orders: true,
            fleet_management: true,
            basic_reports: true,
            advanced_reports: true,
            ifta_reports: true,
            ai_advisor: true,
            loadboard: true,
            email_support: true,
            priority_support: true,
            // Disabled
            api_access: false,
            white_label: false,
            custom_integrations: false
        }
    },
    enterprise: {
        name: 'Enterprise',
        price_monthly: 399,
        price_yearly: 3830,
        limits: {
            max_users: -1, // Unlimited
            max_trucks: -1,
            max_drivers: -1,
            max_trips_monthly: -1,
            storage_gb: 100
        },
        features: {
            // ALL features enabled
            dashboard: true,
            trips: true,
            orders: true,
            fleet_management: true,
            basic_reports: true,
            advanced_reports: true,
            ifta_reports: true,
            ai_advisor: true,
            loadboard: true,
            api_access: true,
            white_label: true,
            custom_integrations: true,
            sso: true,
            dedicated_support: true,
            sla_guarantee: true
        }
    }
};
```

### 2.2 Stripe Edge Function

Create Supabase Edge Function for Stripe webhooks:

```typescript
// supabase/functions/stripe-webhook/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
    apiVersion: '2023-10-16'
})

serve(async (req) => {
    const signature = req.headers.get('stripe-signature')!
    const body = await req.text()

    const event = stripe.webhooks.constructEvent(
        body,
        signature,
        Deno.env.get('STRIPE_WEBHOOK_SECRET')!
    )

    const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    switch (event.type) {
        case 'checkout.session.completed':
            // Handle successful subscription creation
            break
        case 'customer.subscription.updated':
            // Handle subscription changes
            break
        case 'customer.subscription.deleted':
            // Handle cancellation
            break
        case 'invoice.payment_failed':
            // Handle failed payment
            break
    }

    return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' }
    })
})
```

### 2.3 Feature Gating Implementation

```javascript
// assets/js/subscription.js

const SubscriptionService = {
    currentPlan: null,
    features: {},
    limits: {},

    async loadSubscription() {
        const { data } = await supabase
            .from('subscriptions')
            .select(`
                *,
                plan:subscription_plans(*)
            `)
            .eq('organization_id', currentOrganization.id)
            .single();

        this.currentPlan = data;
        this.features = data?.plan?.features || {};
        this.limits = data?.plan?.limits || {};

        return data;
    },

    hasFeature(featureKey) {
        // Enterprise bypass or explicit feature check
        if (this.currentPlan?.plan?.slug === 'enterprise') return true;
        return this.features[featureKey] === true;
    },

    isWithinLimit(limitKey, currentValue) {
        const limit = this.limits[limitKey];
        if (limit === -1) return true; // Unlimited
        return currentValue < limit;
    },

    async checkAndEnforce(featureKey) {
        if (!this.hasFeature(featureKey)) {
            showUpgradeModal(featureKey);
            return false;
        }
        return true;
    },

    getTrialDaysRemaining() {
        if (!this.currentPlan?.trial_ends_at) return 0;
        const trialEnd = new Date(this.currentPlan.trial_ends_at);
        const now = new Date();
        const diff = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));
        return Math.max(0, diff);
    }
};

// Feature gate decorator for navigation
function requireFeature(featureKey) {
    return function(originalFunction) {
        return async function(...args) {
            if (await SubscriptionService.checkAndEnforce(featureKey)) {
                return originalFunction.apply(this, args);
            }
        };
    };
}
```

---

## PHASE 3: Landing Page Redesign

### 3.1 Design Direction (NOT copying HaulEx - Original Design)

**Brand Identity:**
- Primary Color: VroomX Blue (#3b82f6) or VroomX Green (#22c55e) - TBD
- Secondary: Deep Navy (#0f172a)
- Accent: Electric Orange (#f97316)
- Typography: Space Grotesk (headers), Inter (body)
- Brand Voice: Modern, Fast, Reliable - "Your Fleet, Accelerated"

**Landing Page Sections:**

1. **Hero Section**
   - Bold headline: "Fleet Management at Full Speed" or "Your Fleet, Accelerated"
   - Subheadline: "The all-in-one TMS that handles trips, drivers, trucks, and finances — so you can focus on growing your business"
   - CTA buttons: "Start Free Trial" + "Book Demo"
   - Hero image: Dashboard mockup with dynamic elements or animated truck/logistics visual
   - Trust badges: "No credit card required" + "14-day free trial" + "Setup in minutes"

2. **Social Proof Bar**
   - Logos of integrations: Samsara, Stripe, etc.
   - Quick stats: "500+ trips managed daily" | "99.9% uptime" | "24/7 support"

3. **Features Grid (3x2 or 2x3)**
   - Real-time Trip Tracking
   - Fleet Management
   - Financial Analytics & IFTA
   - Driver Management & Compliance
   - Load Board & Orders
   - AI-Powered Insights

4. **Dashboard Preview**
   - Interactive screenshot carousel or video
   - Highlight key workflows: creating trips, managing fleet, viewing reports

5. **Pricing Section**
   - 3 tiers: Starter / Professional / Enterprise
   - Toggle: Monthly / Yearly (show savings)
   - Feature comparison table
   - "Most Popular" badge on Professional

6. **Testimonials/Case Studies**
   - 2-3 customer quotes with photos
   - "How [Company] reduced administrative time by 40%"

7. **FAQ Section**
   - Accordion-style common questions
   - Pricing, features, integrations, security

8. **Final CTA Section**
   - "Ready to streamline your fleet operations?"
   - Large "Start Your Free Trial" button
   - "Questions? Chat with us" link

9. **Footer**
   - Product links
   - Company links
   - Legal links
   - Social media icons
   - Newsletter signup

### 3.2 Landing Page File Structure

```
/
├── landing/
│   ├── index.html          # Public landing page
│   ├── pricing.html        # Pricing details page
│   ├── features.html       # Features deep-dive
│   ├── about.html          # Company info
│   └── assets/
│       ├── css/
│       │   └── landing.css # Landing-specific styles
│       ├── js/
│       │   └── landing.js  # Animations, interactions
│       └── images/
│           ├── hero/
│           ├── features/
│           └── testimonials/
├── app/                    # TMS application (current index.html content)
│   └── index.html
└── index.html              # Redirect to /landing/ or /app/ based on auth
```

### 3.3 Key Landing Page Components

```html
<!-- Hero Section Example -->
<section class="hero">
    <div class="hero-content">
        <span class="badge">🚀 New: AI-Powered Fleet Insights</span>
        <h1>Fleet Management <span class="gradient-text">at Full Speed</span></h1>
        <p class="hero-subtitle">
            The all-in-one TMS that handles trips, drivers, trucks, and finances.
            Built by trucking professionals, for trucking professionals.
        </p>
        <div class="hero-ctas">
            <a href="/signup" class="btn btn-primary btn-lg">
                Start Free Trial
                <svg><!-- arrow icon --></svg>
            </a>
            <a href="/demo" class="btn btn-secondary btn-lg">
                <svg><!-- play icon --></svg>
                Watch Demo
            </a>
        </div>
        <p class="hero-note">No credit card required • 14-day free trial • Cancel anytime</p>
    </div>
    <div class="hero-visual">
        <img src="/assets/images/dashboard-mockup.png" alt="VroomX TMS Dashboard" />
    </div>
</section>
```

---

## PHASE 4: TMS Application Redesign

### 4.1 Modern Dashboard Redesign

**Layout Improvements:**
- Card-based metric display with sparkline charts
- Activity feed with real-time updates
- Quick actions panel
- Period selector (Today, This Week, This Month, Custom)
- Organization switcher in header

**Key Metrics Cards:**
```
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│  Active Trips   │   Total Revenue │   Active Fleet  │  Fuel Efficiency│
│      12         │    $48,350      │    8/10 trucks  │    6.2 MPG      │
│   +3 from last  │   +12% ▲        │    2 in maint.  │    +0.3 ▲       │
│   week          │                 │                 │                 │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

**Widget-Based Layout:**
- Draggable/configurable dashboard widgets
- Save layout preferences per user
- Default layouts per role

### 4.2 Navigation Redesign

**New Sidebar Structure:**
```
┌─────────────────────────────┐
│  [Logo] VroomX              │
│  [Org Switcher ▼]           │
├─────────────────────────────┤
│  🏠 Dashboard               │
│  📍 Live Map                │
│  💬 Team Chat (3)           │
├─────────────────────────────┤
│  OPERATIONS                 │
│  🚚 Trips                   │
│  📦 Orders                  │
│  📋 Load Board              │
├─────────────────────────────┤
│  FLEET                      │
│  👤 Drivers                 │
│  🚛 Trucks                  │
│  📅 Dispatch Calendar       │
├─────────────────────────────┤
│  FINANCIALS    [PRO badge]  │
│  💰 Overview                │
│  📊 Reports                 │
│  ⛽ Fuel & IFTA             │
├─────────────────────────────┤
│  ⚙️ Settings               │
│  ❓ Help & Support         │
└─────────────────────────────┘
│  [User Avatar]              │
│  John Doe                   │
│  Dispatcher                 │
│  [Logout]                   │
└─────────────────────────────┘
```

### 4.3 Component Library Enhancement

**Design Tokens:**
```css
:root {
    /* Colors */
    --color-primary: #22c55e;
    --color-primary-hover: #16a34a;
    --color-secondary: #64748b;
    --color-danger: #ef4444;
    --color-warning: #f59e0b;
    --color-info: #3b82f6;

    /* Surfaces */
    --surface-base: #ffffff;
    --surface-elevated: #f8fafc;
    --surface-overlay: rgba(0,0,0,0.5);

    /* Spacing Scale */
    --space-1: 0.25rem;
    --space-2: 0.5rem;
    --space-3: 0.75rem;
    --space-4: 1rem;
    --space-6: 1.5rem;
    --space-8: 2rem;

    /* Border Radius */
    --radius-sm: 0.375rem;
    --radius-md: 0.5rem;
    --radius-lg: 0.75rem;
    --radius-xl: 1rem;

    /* Shadows */
    --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
    --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.1);
    --shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.1);
}
```

**New UI Components:**
- Toast notifications with actions
- Command palette (Ctrl+K) - improved search
- Data tables with sorting, filtering, pagination
- Empty states with illustrations
- Loading skeletons
- Confirmation dialogs
- Progress indicators

---

## PHASE 5: Authentication & Onboarding Flow

### 5.1 New User Registration Flow

```
1. Landing Page → "Start Free Trial"
2. Sign Up Form
   - Full Name
   - Work Email
   - Password
   - Company Name
   - Fleet Size (dropdown: 1-5, 6-15, 16-50, 50+)
   - Phone (optional)

3. Email Verification
   - Send verification email
   - Show "Check your email" page

4. Organization Setup (after verification)
   - Company details
   - Upload logo (optional)
   - Select timezone
   - Invite team members (skip for now)

5. Onboarding Checklist
   - Add your first truck
   - Add your first driver
   - Create a trip
   - Connect integrations (Samsara, etc.)
   - Explore the dashboard

6. Dashboard (with onboarding progress bar)
```

### 5.2 Multi-Organization Support

```javascript
// Organization context management
const OrganizationService = {
    current: null,
    available: [],

    async loadUserOrganizations() {
        const { data } = await supabase
            .from('organization_members')
            .select(`
                organization:organizations(*),
                role
            `)
            .eq('user_id', currentUser.id);

        this.available = data.map(m => ({
            ...m.organization,
            userRole: m.role
        }));

        // Load current org from localStorage or use primary
        const savedOrgId = localStorage.getItem('currentOrganizationId');
        this.current = this.available.find(o => o.id === savedOrgId)
            || this.available.find(o => o.is_primary)
            || this.available[0];

        return this.current;
    },

    async switchOrganization(orgId) {
        this.current = this.available.find(o => o.id === orgId);
        localStorage.setItem('currentOrganizationId', orgId);

        // Reload all data for new organization
        await loadAllData(true);
        renderPage();

        showToast(`Switched to ${this.current.name}`);
    }
};
```

---

## PHASE 6: API Improvements

### 6.1 Organization-Scoped API Layer

```javascript
// Enhanced api.js with automatic organization scoping

async function dbFetch(table, options = {}) {
    let query = supabase.from(table).select(options.select || '*');

    // Auto-add organization filter (except for global tables)
    const globalTables = ['subscription_plans', 'users']; // Tables without org scope
    if (!globalTables.includes(table) && currentOrganization?.id) {
        query = query.eq('organization_id', currentOrganization.id);
    }

    // Apply additional filters
    if (options.filters) {
        for (const [key, value] of Object.entries(options.filters)) {
            query = query.eq(key, value);
        }
    }

    // Apply sorting
    if (options.orderBy) {
        query = query.order(options.orderBy, { ascending: options.ascending ?? false });
    }

    // Apply pagination
    if (options.limit) {
        query = query.limit(options.limit);
    }
    if (options.offset) {
        query = query.range(options.offset, options.offset + (options.limit || 10) - 1);
    }

    const { data, error } = await query;
    if (error) throw error;
    return data;
}

async function dbInsert(table, record) {
    // Auto-add organization_id
    const globalTables = ['subscription_plans', 'users', 'organizations'];
    if (!globalTables.includes(table) && currentOrganization?.id) {
        record.organization_id = currentOrganization.id;
    }

    const { data, error } = await supabase
        .from(table)
        .insert(record)
        .select()
        .single();

    if (error) throw error;
    return data;
}
```

### 6.2 Real-time Subscriptions Update

```javascript
// Update realtime subscriptions to filter by organization
function setupRealtimeSubscriptions() {
    if (!currentOrganization?.id) return;

    const channel = supabase.channel(`org-${currentOrganization.id}`)
        .on('postgres_changes', {
            event: '*',
            schema: 'public',
            table: 'trips',
            filter: `organization_id=eq.${currentOrganization.id}`
        }, handleRealtimeUpdate)
        .on('postgres_changes', {
            event: '*',
            schema: 'public',
            table: 'drivers',
            filter: `organization_id=eq.${currentOrganization.id}`
        }, handleRealtimeUpdate)
        // ... add more tables
        .subscribe();

    return channel;
}
```

---

## PHASE 7: Security Enhancements

### 7.1 Security Checklist

- [ ] All RLS policies implemented and tested
- [ ] Organization ID validation on all API calls
- [ ] Stripe webhook signature verification
- [ ] CSRF protection on forms
- [ ] Rate limiting on auth endpoints
- [ ] Input sanitization for all user inputs
- [ ] XSS prevention (escape all dynamic content)
- [ ] SQL injection prevention (parameterized queries - Supabase handles this)
- [ ] Secure session management
- [ ] Password requirements enforcement
- [ ] Two-factor authentication (optional, enterprise tier)

### 7.2 Audit Logging

```javascript
// Enhanced activity logging
async function logActivity(action, details = {}) {
    await supabase.from('activity_log').insert({
        organization_id: currentOrganization?.id,
        user_id: currentUser?.id,
        action: action,
        details: {
            ...details,
            ip_address: null, // Would need server-side
            user_agent: navigator.userAgent,
            timestamp: new Date().toISOString()
        }
    });
}

// Log important actions
logActivity('trip.created', { trip_id: newTrip.id });
logActivity('user.invited', { email: invitedEmail });
logActivity('subscription.upgraded', { from_plan: 'starter', to_plan: 'professional' });
```

---

## PHASE 8: Performance Optimization

### 8.1 Code Splitting Strategy

Current: Single 30K+ line index.html
Target: Modular, lazy-loaded pages

```
/app/
├── index.html (shell + core)
├── assets/
│   └── js/
│       ├── core/
│       │   ├── config.js
│       │   ├── auth.js
│       │   ├── api.js
│       │   ├── router.js
│       │   └── subscription.js
│       ├── pages/
│       │   ├── dashboard.js (lazy)
│       │   ├── trips.js (lazy)
│       │   ├── drivers.js (lazy)
│       │   ├── trucks.js (lazy)
│       │   ├── financials.js (lazy)
│       │   └── settings.js (lazy)
│       └── components/
│           ├── sidebar.js
│           ├── header.js
│           ├── modals.js
│           └── tables.js
```

### 8.2 Data Loading Optimization

```javascript
// Implement smart data loading
const DataLoader = {
    async loadEssential() {
        // Load only what's needed for current view
        const essentialData = await Promise.all([
            dbFetch('users', { limit: 100 }),
            dbFetch('trucks'),
            dbFetch('drivers')
        ]);
        return essentialData;
    },

    async loadForPage(pageName) {
        const pageDataMap = {
            dashboard: ['trips', 'orders', 'tasks'],
            trips: ['trips', 'drivers', 'trucks', 'brokers'],
            financials: ['expenses', 'trips', 'fuel_transactions']
        };

        const tables = pageDataMap[pageName] || [];
        return Promise.all(tables.map(t => dbFetch(t)));
    }
};
```

---

## PHASE 9: Testing Strategy

### 9.1 Test Categories

1. **Unit Tests** - Individual functions
2. **Integration Tests** - API + Database
3. **E2E Tests** - Full user flows
4. **Security Tests** - RLS policies, auth
5. **Performance Tests** - Load testing

### 9.2 Critical Test Scenarios

```
Multi-Tenancy Tests:
- [ ] User A cannot see User B's organization data
- [ ] RLS blocks cross-organization queries
- [ ] Organization switching updates all data views
- [ ] Invitation system creates correct memberships
- [ ] Deleted organization cascades properly

Subscription Tests:
- [ ] Trial expires correctly
- [ ] Feature gates block access properly
- [ ] Upgrade flow works end-to-end
- [ ] Downgrade handles data limits
- [ ] Stripe webhook updates subscription status
- [ ] Past-due status restricts access

Authentication Tests:
- [ ] Registration creates org + membership
- [ ] Login loads correct organization
- [ ] Multi-org users can switch
- [ ] Session timeout works
- [ ] Password reset flow complete
```

---

## PHASE 10: Deployment & DevOps

### 10.1 Environment Configuration

```env
# .env.production
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=xxx
VITE_STRIPE_PUBLISHABLE_KEY=pk_live_xxx
VITE_APP_URL=https://app.vroomx.io

# Supabase Edge Functions
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
RESEND_API_KEY=re_xxx
```

### 10.2 Deployment Checklist

Pre-deployment:
- [ ] All migrations tested on staging
- [ ] RLS policies verified
- [ ] Stripe webhook endpoints configured
- [ ] DNS records updated
- [ ] SSL certificates valid
- [ ] Error monitoring setup (Sentry, etc.)
- [ ] Analytics configured

Post-deployment:
- [ ] Smoke test critical flows
- [ ] Monitor error rates
- [ ] Check Stripe webhooks receiving
- [ ] Verify email delivery
- [ ] Test on multiple browsers

---

## Implementation Priority Order

### Sprint 1: Foundation (Database & Auth)
1. Create database migrations for multi-tenancy
2. Implement RLS policies
3. Update authentication for organization context
4. Create organization service layer

### Sprint 2: Subscription System
1. Set up Stripe account and products
2. Create subscription edge functions
3. Implement feature gating
4. Build billing settings UI

### Sprint 3: Landing Page
1. Design and build new landing page
2. Create pricing page
3. Implement signup/onboarding flow
4. Add demo request form

### Sprint 4: TMS Redesign
1. Refactor navigation/sidebar
2. Redesign dashboard
3. Update all pages with new design system
4. Implement organization switcher

### Sprint 5: Polish & Launch
1. Performance optimization
2. Security audit
3. Testing
4. Documentation
5. Soft launch to beta users

---

## Key Decisions & Trade-offs

| Decision | Options | Chosen | Rationale |
|----------|---------|--------|-----------|
| Framework | React/Vue/Vanilla | Vanilla JS (keep) | Lower migration risk, team familiarity |
| Billing | Stripe/Paddle/Custom | Stripe | Industry standard, great API |
| Auth | Supabase/Auth0/Custom | Supabase Auth (keep) | Already integrated |
| Hosting | Vercel/Netlify/AWS | Netlify (keep) | Already configured |
| CSS | Tailwind/Custom | Custom + CSS Variables | Already exists, extend it |

---

## Success Metrics

**Launch Goals:**
- [ ] 50 organizations signed up within 30 days
- [ ] 90% of trials convert to viewing dashboard
- [ ] < 5% churn in first 3 months
- [ ] Zero security incidents
- [ ] 99.9% uptime

**Technical Metrics:**
- [ ] Page load < 3 seconds
- [ ] API response < 500ms
- [ ] Zero cross-tenant data leaks
- [ ] < 1% error rate

---

## Questions to Resolve

Before implementation, clarify:
1. What subscription tiers and pricing?
2. What features per tier?
3. Trial length (7 days? 14 days?)
4. Credit card required for trial?
5. White-label requirements for enterprise?
6. SSO requirements?
7. API access requirements?
8. Data export/import requirements?

---

## Brand Guidelines Summary

**Product Name:** VroomX TMS (or just "VroomX")
**Tagline Options:**
- "Your Fleet, Accelerated"
- "Fleet Management at Full Speed"
- "Move Faster. Manage Smarter."

**Logo Concept:** Stylized "V" with speed lines or a checkmark embedded, suggesting both velocity and reliability

**Color Palette:**
- Primary: #3b82f6 (VroomX Blue) - trust, technology
- Accent: #f97316 (Electric Orange) - energy, speed
- Success: #22c55e (Green) - positive actions
- Dark: #0f172a (Navy) - professional, serious

**Voice & Tone:**
- Professional but approachable
- Action-oriented language
- Focus on speed, efficiency, and growth
- Avoid jargon, be clear

---

*Document Version: 1.1*
*Product: VroomX TMS*
*Last Updated: January 2026*
*Author: Claude Code Assistant*
