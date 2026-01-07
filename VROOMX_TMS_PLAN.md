# VroomX TMS - SaaS Development Plan

## Project Overview

**Product Name:** VroomX TMS
**Type:** Multi-tenant SaaS Transportation Management System
**Based on:** Horizon Star TMS feature set (full parity)
**Team:** You + Claude
**Integration:** Samsara

---

## 1. Final Tech Stack Decision

After analyzing the requirements (full-featured TMS, multi-tenancy, real-time collaboration, Samsara integration), here's the optimal stack:

### Frontend
| Technology | Why |
|------------|-----|
| **Next.js 15** (App Router) | Full-stack React, Server Components, API routes, excellent DX |
| **TypeScript** | Type safety across the entire codebase |
| **Tailwind CSS** | Utility-first, fast iteration, consistent styling |
| **shadcn/ui** | Beautiful, accessible components built on Radix UI |
| **React Query (TanStack)** | Server state management, caching, real-time sync |
| **Zustand** | Lightweight client state (modals, UI state) |
| **React Hook Form + Zod** | Form handling with validation |

### Backend
| Technology | Why |
|------------|-----|
| **Next.js API Routes** | Unified codebase, type sharing |
| **Supabase** | PostgreSQL + Auth + Real-time + Storage (familiar from Horizon Star) |
| **Prisma** | Type-safe ORM, excellent migrations |
| **tRPC** (optional) | End-to-end type safety for API calls |

### Infrastructure
| Technology | Why |
|------------|-----|
| **Vercel** | Best Next.js hosting, edge functions, easy deploys |
| **Supabase Cloud** | Managed Postgres, scales automatically |
| **Stripe** | Subscription billing, usage metering |
| **Resend** | Transactional email (familiar from Horizon Star) |
| **Uploadthing** or **Supabase Storage** | File uploads (documents, images) |
| **Sentry** | Error tracking and monitoring |

### Development Tools
| Tool | Purpose |
|------|---------|
| **pnpm** | Fast package manager with workspaces |
| **ESLint + Prettier** | Code quality |
| **Husky + lint-staged** | Pre-commit hooks |
| **Playwright** | E2E testing |
| **Vitest** | Unit testing |

---

## 2. VroomX Brand Identity

### Color Palette
```css
/* Primary - Electric Blue (Speed, Technology, Trust) */
--vroomx-primary: #2563eb;
--vroomx-primary-hover: #1d4ed8;
--vroomx-primary-light: #dbeafe;

/* Secondary - Vibrant Orange (Energy, Action, CTA) */
--vroomx-secondary: #f97316;
--vroomx-secondary-hover: #ea580c;

/* Accent - Deep Purple (Premium, Innovation) */
--vroomx-accent: #7c3aed;

/* Neutral */
--vroomx-gray-50: #f9fafb;
--vroomx-gray-100: #f3f4f6;
--vroomx-gray-200: #e5e7eb;
--vroomx-gray-300: #d1d5db;
--vroomx-gray-400: #9ca3af;
--vroomx-gray-500: #6b7280;
--vroomx-gray-600: #4b5563;
--vroomx-gray-700: #374151;
--vroomx-gray-800: #1f2937;
--vroomx-gray-900: #111827;

/* Semantic */
--vroomx-success: #10b981;
--vroomx-warning: #f59e0b;
--vroomx-error: #ef4444;
--vroomx-info: #06b6d4;
```

### Typography
```css
/* Display/Headings - Bold, Modern */
--font-display: "Plus Jakarta Sans", sans-serif;

/* Body - Clean, Readable */
--font-body: "Inter", sans-serif;

/* Monospace - Data, Numbers */
--font-mono: "JetBrains Mono", monospace;
```

### Logo Concept
```
VroomX TMS
   ⚡
[V with speed lines] Modern, tech-forward logotype
```

---

## 3. Database Architecture

### Multi-Tenant Schema

```sql
-- =============================================
-- TENANT & AUTH TABLES
-- =============================================

CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,           -- vroomx.app/acme-trucking
    logo_url TEXT,
    primary_color VARCHAR(7) DEFAULT '#2563eb', -- Custom branding
    settings JSONB DEFAULT '{}',

    -- Billing
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    plan VARCHAR(50) DEFAULT 'trial',            -- trial, starter, pro, enterprise
    trial_ends_at TIMESTAMP,

    -- Samsara Integration
    samsara_api_key TEXT,                        -- Encrypted
    samsara_enabled BOOLEAN DEFAULT false,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    auth_id UUID UNIQUE,                         -- Supabase Auth ID

    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    phone VARCHAR(20),

    role VARCHAR(50) DEFAULT 'dispatcher',       -- owner, admin, manager, dispatcher, driver
    permissions JSONB DEFAULT '[]',              -- Fine-grained permissions

    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, email)
);

CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'dispatcher',
    token VARCHAR(255) UNIQUE NOT NULL,
    invited_by UUID REFERENCES users(id),
    expires_at TIMESTAMP NOT NULL,
    accepted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- FLEET TABLES
-- =============================================

CREATE TABLE trucks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    truck_number VARCHAR(50) NOT NULL,
    vin VARCHAR(17),
    make VARCHAR(100),
    model VARCHAR(100),
    year INTEGER,

    license_plate VARCHAR(20),
    license_state VARCHAR(2),

    status VARCHAR(20) DEFAULT 'active',         -- active, inactive, maintenance, sold
    fuel_type VARCHAR(20) DEFAULT 'diesel',
    fuel_capacity DECIMAL(10,2),

    purchase_date DATE,
    purchase_price DECIMAL(10,2),

    -- Samsara
    samsara_vehicle_id VARCHAR(100),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, truck_number)
);

CREATE TABLE trailers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    trailer_number VARCHAR(50) NOT NULL,
    vin VARCHAR(17),
    type VARCHAR(50),                            -- dry_van, reefer, flatbed, etc.

    length_ft INTEGER,
    capacity_lbs INTEGER,

    license_plate VARCHAR(20),
    license_state VARCHAR(2),

    status VARCHAR(20) DEFAULT 'active',

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, trailer_number)
);

CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),           -- Optional: driver can have login

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),

    -- Address
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),

    -- License
    license_number VARCHAR(50),
    license_state VARCHAR(2),
    license_class VARCHAR(10),
    license_expires DATE,
    endorsements VARCHAR(50)[],                  -- ARRAY: ['H', 'N', 'T', 'X']

    -- Medical
    medical_card_number VARCHAR(50),
    medical_expires DATE,

    -- Employment
    hire_date DATE,
    termination_date DATE,
    status VARCHAR(20) DEFAULT 'active',

    -- Pay
    payment_type VARCHAR(20) DEFAULT 'percentage', -- percentage, per_mile, salary
    payment_rate DECIMAL(10,2),                    -- 25% or $0.55/mile or $1000/week

    -- Samsara
    samsara_driver_id VARCHAR(100),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE owner_operators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    company_name VARCHAR(255),
    contact_name VARCHAR(200) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),

    mc_number VARCHAR(20),
    dot_number VARCHAR(20),

    payment_per_trip DECIMAL(10,2),
    payment_percentage DECIMAL(5,2),

    truck_id UUID REFERENCES trucks(id),

    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE dispatchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),           -- Link to user account

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),

    commission_rate DECIMAL(5,2),                -- Optional dispatcher commission

    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE brokers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    mc_number VARCHAR(20),

    contact_name VARCHAR(200),
    phone VARCHAR(20),
    email VARCHAR(255),

    address TEXT,
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),

    payment_terms INTEGER DEFAULT 30,            -- Days
    credit_limit DECIMAL(10,2),

    notes TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- OPERATIONS TABLES
-- =============================================

CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    trip_number VARCHAR(50) NOT NULL,            -- Auto: TRP-2024-000001

    status VARCHAR(20) DEFAULT 'planned',        -- planned, dispatched, in_progress, completed, cancelled

    trip_date DATE NOT NULL,

    truck_id UUID REFERENCES trucks(id),
    trailer_id UUID REFERENCES trailers(id),
    driver_id UUID REFERENCES drivers(id),
    dispatcher_id UUID REFERENCES dispatchers(id),

    -- Mileage
    start_odometer DECIMAL(10,1),
    end_odometer DECIMAL(10,1),
    total_miles DECIMAL(10,1),

    -- Driver Pay (calculated)
    driver_pay DECIMAL(10,2),

    notes TEXT,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, trip_number)
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    order_number VARCHAR(50) NOT NULL,           -- Auto: ORD-2024-000001

    trip_id UUID REFERENCES trips(id),
    broker_id UUID REFERENCES brokers(id),

    -- Assignment
    vehicle_direction VARCHAR(20),               -- outbound, return
    sequence INTEGER DEFAULT 1,

    -- Load Details
    reference_number VARCHAR(100),               -- Broker's reference
    commodity VARCHAR(255),
    weight_lbs INTEGER,

    -- Locations
    pickup_name VARCHAR(255),
    pickup_address TEXT,
    pickup_city VARCHAR(100),
    pickup_state VARCHAR(2),
    pickup_zip VARCHAR(10),
    pickup_date DATE,
    pickup_time TIME,
    pickup_notes TEXT,

    delivery_name VARCHAR(255),
    delivery_address TEXT,
    delivery_city VARCHAR(100),
    delivery_state VARCHAR(2),
    delivery_zip VARCHAR(10),
    delivery_date DATE,
    delivery_time TIME,
    delivery_notes TEXT,

    -- Financials
    revenue DECIMAL(10,2) DEFAULT 0,
    rate_per_mile DECIMAL(10,2),

    -- Payment
    payment_type VARCHAR(20) DEFAULT 'bill',     -- bill, cod, cop, check, local_cod
    cod_amount DECIMAL(10,2) DEFAULT 0,
    bill_amount DECIMAL(10,2) DEFAULT 0,

    -- Broker Fee
    broker_fee DECIMAL(10,2) DEFAULT 0,
    broker_fee_type VARCHAR(20) DEFAULT 'flat',  -- flat, percentage

    -- Status
    status VARCHAR(20) DEFAULT 'pending',        -- pending, dispatched, picked_up, in_transit, delivered, invoiced, paid

    dispatcher_id UUID REFERENCES users(id),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, order_number)
);

CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    trip_id UUID REFERENCES trips(id),
    truck_id UUID REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),

    category VARCHAR(50) NOT NULL,               -- fuel, maintenance, tolls, lumper, detention, etc.
    description TEXT,
    amount DECIMAL(10,2) NOT NULL,

    expense_date DATE NOT NULL,
    receipt_url TEXT,

    reimbursable BOOLEAN DEFAULT false,
    reimbursed BOOLEAN DEFAULT false,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- FINANCIAL TABLES
-- =============================================

CREATE TABLE fixed_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),                       -- insurance, permits, software, etc.
    amount DECIMAL(10,2) NOT NULL,
    frequency VARCHAR(20) DEFAULT 'monthly',     -- monthly, quarterly, yearly

    start_date DATE,
    end_date DATE,

    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fuel_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    truck_id UUID REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),
    trip_id UUID REFERENCES trips(id),

    transaction_date TIMESTAMP NOT NULL,

    gallons DECIMAL(10,3) NOT NULL,
    price_per_gallon DECIMAL(10,3) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,

    odometer DECIMAL(10,1),

    location VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),

    fuel_card_type VARCHAR(50),                  -- EFS, Comdata, etc.
    transaction_id VARCHAR(100),

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE payroll_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    status VARCHAR(20) DEFAULT 'draft',          -- draft, approved, paid

    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE paystubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    payroll_period_id UUID REFERENCES payroll_periods(id),

    driver_id UUID NOT NULL REFERENCES drivers(id),

    gross_pay DECIMAL(10,2) NOT NULL,
    deductions DECIMAL(10,2) DEFAULT 0,
    bonuses DECIMAL(10,2) DEFAULT 0,
    reimbursements DECIMAL(10,2) DEFAULT 0,
    net_pay DECIMAL(10,2) NOT NULL,

    trips_count INTEGER,
    total_miles DECIMAL(10,1),

    check_number VARCHAR(50),
    paid_at TIMESTAMP,

    pdf_url TEXT,

    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- COMPLIANCE TABLES
-- =============================================

CREATE TABLE driver_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Personal Info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),

    ssn_encrypted TEXT,                          -- Encrypted SSN
    date_of_birth DATE,

    address TEXT,
    city VARCHAR(100),
    state VARCHAR(2),
    zip VARCHAR(10),

    -- License Info
    license_number VARCHAR(50),
    license_state VARCHAR(2),
    license_class VARCHAR(10),
    license_expires DATE,
    endorsements VARCHAR(50)[],

    -- Medical
    medical_card_expires DATE,

    -- Documents
    license_front_url TEXT,
    license_back_url TEXT,
    medical_card_url TEXT,

    -- Employment History (FMCSA 10-year requirement)
    employment_history JSONB DEFAULT '[]',

    -- Accident/Violation History
    accidents_last_3_years JSONB DEFAULT '[]',
    violations_last_3_years JSONB DEFAULT '[]',

    -- Signatures
    certification_signature TEXT,
    certification_date TIMESTAMP,

    -- Status
    status VARCHAR(20) DEFAULT 'pending',        -- pending, under_review, approved, rejected
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE compliance_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    entity_type VARCHAR(20) NOT NULL,            -- driver, truck, trailer, company
    entity_id UUID NOT NULL,

    document_type VARCHAR(100) NOT NULL,         -- cdl, medical_card, registration, insurance, etc.
    document_name VARCHAR(255),
    file_url TEXT NOT NULL,

    issue_date DATE,
    expiry_date DATE,

    notes TEXT,

    uploaded_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE compliance_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    entity_type VARCHAR(20) NOT NULL,
    entity_id UUID NOT NULL,

    alert_type VARCHAR(100) NOT NULL,            -- expiring_license, expiring_medical, etc.
    message TEXT NOT NULL,

    due_date DATE,

    status VARCHAR(20) DEFAULT 'active',         -- active, acknowledged, resolved
    acknowledged_by UUID REFERENCES users(id),
    acknowledged_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    type VARCHAR(50) NOT NULL,                   -- accident, violation, ticket, claim

    driver_id UUID REFERENCES drivers(id),
    truck_id UUID REFERENCES trucks(id),
    trip_id UUID REFERENCES trips(id),

    incident_date TIMESTAMP NOT NULL,
    location TEXT,

    description TEXT NOT NULL,

    -- For accidents
    severity VARCHAR(20),                        -- minor, moderate, severe
    injuries BOOLEAN DEFAULT false,
    fatalities BOOLEAN DEFAULT false,
    police_report_number VARCHAR(100),

    -- For tickets/violations
    violation_type VARCHAR(100),
    fine_amount DECIMAL(10,2),
    points INTEGER,

    -- For claims
    claim_number VARCHAR(100),
    claim_amount DECIMAL(10,2),
    claim_status VARCHAR(50),

    -- Documents
    documents JSONB DEFAULT '[]',

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    truck_id UUID REFERENCES trucks(id),
    trailer_id UUID REFERENCES trailers(id),

    service_type VARCHAR(100) NOT NULL,          -- oil_change, tire_rotation, brake_service, etc.
    description TEXT,

    service_date DATE NOT NULL,
    next_service_date DATE,
    next_service_miles DECIMAL(10,1),

    odometer DECIMAL(10,1),

    vendor_name VARCHAR(255),

    labor_cost DECIMAL(10,2),
    parts_cost DECIMAL(10,2),
    total_cost DECIMAL(10,2),

    invoice_number VARCHAR(100),
    receipt_url TEXT,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- IFTA TABLES
-- =============================================

CREATE TABLE ifta_miles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    quarter INTEGER NOT NULL,                    -- 1, 2, 3, 4
    year INTEGER NOT NULL,

    state VARCHAR(2) NOT NULL,
    miles DECIMAL(10,1) NOT NULL,

    source VARCHAR(20) DEFAULT 'manual',         -- manual, samsara, eld

    created_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, quarter, year, state)
);

CREATE TABLE ifta_fuel (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    quarter INTEGER NOT NULL,
    year INTEGER NOT NULL,

    state VARCHAR(2) NOT NULL,
    gallons DECIMAL(10,3) NOT NULL,

    created_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(org_id, quarter, year, state)
);

-- =============================================
-- COMMUNICATION TABLES
-- =============================================

CREATE TABLE chat_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) DEFAULT 'group',            -- group, direct

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,

    user_id UUID NOT NULL REFERENCES users(id),
    message TEXT NOT NULL,

    attachments JSONB DEFAULT '[]',

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),

    type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,

    link TEXT,

    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- ACTIVITY & AUDIT
-- =============================================

CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    user_id UUID REFERENCES users(id),
    user_email VARCHAR(255),

    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,

    details JSONB,

    ip_address INET,
    user_agent TEXT,

    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_users_org ON users(org_id);
CREATE INDEX idx_trucks_org ON trucks(org_id);
CREATE INDEX idx_drivers_org ON drivers(org_id);
CREATE INDEX idx_trips_org ON trips(org_id);
CREATE INDEX idx_trips_date ON trips(trip_date);
CREATE INDEX idx_orders_org ON orders(org_id);
CREATE INDEX idx_orders_trip ON orders(trip_id);
CREATE INDEX idx_expenses_org ON expenses(org_id);
CREATE INDEX idx_expenses_trip ON expenses(trip_id);
CREATE INDEX idx_fuel_org ON fuel_transactions(org_id);
CREATE INDEX idx_activity_org ON activity_log(org_id);
CREATE INDEX idx_activity_created ON activity_log(created_at);

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- ... enable on all tables

-- Policy Example: Users can only see their organization's data
CREATE POLICY org_isolation ON trucks
    FOR ALL
    USING (org_id = (SELECT org_id FROM users WHERE auth_id = auth.uid()));
```

---

## 4. Project Structure

```
vroomx-tms/
├── .github/
│   └── workflows/
│       ├── ci.yml                    # Lint, test, build
│       └── deploy.yml                # Vercel deployment
│
├── apps/
│   └── web/                          # Main Next.js application
│       ├── app/
│       │   ├── (auth)/               # Auth pages (no sidebar)
│       │   │   ├── login/
│       │   │   ├── signup/
│       │   │   ├── forgot-password/
│       │   │   ├── reset-password/
│       │   │   └── accept-invite/
│       │   │
│       │   ├── (marketing)/          # Public pages
│       │   │   ├── page.tsx          # Landing page
│       │   │   ├── pricing/
│       │   │   ├── features/
│       │   │   └── contact/
│       │   │
│       │   ├── (dashboard)/          # Protected app pages
│       │   │   ├── layout.tsx        # Sidebar + header
│       │   │   ├── dashboard/
│       │   │   │   └── page.tsx
│       │   │   │
│       │   │   ├── fleet/
│       │   │   │   ├── trucks/
│       │   │   │   │   ├── page.tsx          # List
│       │   │   │   │   ├── [id]/page.tsx     # Detail
│       │   │   │   │   └── new/page.tsx      # Create
│       │   │   │   ├── trailers/
│       │   │   │   ├── drivers/
│       │   │   │   ├── owner-operators/
│       │   │   │   └── dispatchers/
│       │   │   │
│       │   │   ├── operations/
│       │   │   │   ├── trips/
│       │   │   │   ├── orders/
│       │   │   │   ├── loadboard/
│       │   │   │   └── live-map/
│       │   │   │
│       │   │   ├── customers/
│       │   │   │   └── brokers/
│       │   │   │
│       │   │   ├── financials/
│       │   │   │   ├── overview/
│       │   │   │   ├── payroll/
│       │   │   │   ├── expenses/
│       │   │   │   ├── fuel/
│       │   │   │   ├── ifta/
│       │   │   │   └── reports/
│       │   │   │
│       │   │   ├── compliance/
│       │   │   │   ├── overview/
│       │   │   │   ├── documents/
│       │   │   │   ├── applications/
│       │   │   │   ├── incidents/
│       │   │   │   └── maintenance/
│       │   │   │
│       │   │   ├── communication/
│       │   │   │   ├── chat/
│       │   │   │   └── notifications/
│       │   │   │
│       │   │   └── settings/
│       │   │       ├── organization/
│       │   │       ├── users/
│       │   │       ├── billing/
│       │   │       ├── integrations/
│       │   │       └── activity-log/
│       │   │
│       │   ├── api/
│       │   │   ├── auth/
│       │   │   ├── webhooks/
│       │   │   │   └── stripe/
│       │   │   └── trpc/
│       │   │
│       │   ├── layout.tsx
│       │   ├── globals.css
│       │   └── providers.tsx
│       │
│       ├── components/
│       │   ├── ui/                   # shadcn/ui components
│       │   │   ├── button.tsx
│       │   │   ├── input.tsx
│       │   │   ├── dialog.tsx
│       │   │   ├── table.tsx
│       │   │   ├── form.tsx
│       │   │   └── ...
│       │   │
│       │   ├── layout/
│       │   │   ├── sidebar.tsx
│       │   │   ├── header.tsx
│       │   │   ├── mobile-nav.tsx
│       │   │   └── breadcrumbs.tsx
│       │   │
│       │   ├── features/
│       │   │   ├── trucks/
│       │   │   │   ├── truck-table.tsx
│       │   │   │   ├── truck-form.tsx
│       │   │   │   └── truck-card.tsx
│       │   │   ├── drivers/
│       │   │   ├── trips/
│       │   │   ├── orders/
│       │   │   └── ...
│       │   │
│       │   └── shared/
│       │       ├── data-table.tsx
│       │       ├── stats-card.tsx
│       │       ├── date-range-picker.tsx
│       │       ├── file-upload.tsx
│       │       └── ...
│       │
│       ├── lib/
│       │   ├── supabase/
│       │   │   ├── client.ts         # Browser client
│       │   │   ├── server.ts         # Server client
│       │   │   └── middleware.ts     # Auth middleware
│       │   │
│       │   ├── stripe/
│       │   │   ├── client.ts
│       │   │   └── plans.ts
│       │   │
│       │   ├── samsara/
│       │   │   └── client.ts
│       │   │
│       │   ├── utils/
│       │   │   ├── formatters.ts
│       │   │   ├── validators.ts
│       │   │   └── calculations.ts   # Financial calculations from Horizon Star
│       │   │
│       │   └── constants.ts
│       │
│       ├── hooks/
│       │   ├── use-organization.ts
│       │   ├── use-user.ts
│       │   ├── use-realtime.ts
│       │   └── ...
│       │
│       ├── stores/
│       │   ├── ui-store.ts           # Sidebar state, modals, etc.
│       │   └── filters-store.ts      # Table filters, date ranges
│       │
│       ├── types/
│       │   ├── database.ts           # Generated from Supabase
│       │   └── index.ts
│       │
│       ├── middleware.ts             # Auth + org context
│       ├── next.config.js
│       ├── tailwind.config.ts
│       └── package.json
│
├── packages/
│   ├── database/
│   │   ├── prisma/
│   │   │   └── schema.prisma
│   │   ├── migrations/
│   │   └── seed.ts
│   │
│   └── types/
│       └── index.ts                  # Shared types
│
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   └── functions/
│       ├── send-email/
│       └── generate-pdf/
│
├── .env.example
├── .env.local
├── package.json
├── pnpm-workspace.yaml
├── turbo.json
└── README.md
```

---

## 5. Feature Implementation Order

### Sprint 1-2: Foundation
```
[ ] Project setup (Next.js, Tailwind, shadcn/ui)
[ ] Supabase project + schema migration
[ ] Authentication flow (signup, login, logout)
[ ] Organization creation + onboarding
[ ] Basic layout (sidebar, header)
[ ] User management (invite, roles)
```

### Sprint 3-4: Fleet Management
```
[ ] Trucks CRUD + list/detail views
[ ] Trailers CRUD
[ ] Drivers CRUD + detail page
[ ] Owner Operators CRUD
[ ] Dispatchers CRUD
[ ] Brokers CRUD
```

### Sprint 5-6: Operations Core
```
[ ] Trips CRUD + status workflow
[ ] Orders CRUD + trip assignment
[ ] Load Board (visual planning)
[ ] Expenses tracking
[ ] Trip profitability calculations
```

### Sprint 7-8: Financials
```
[ ] Financial dashboard + KPIs
[ ] Payroll periods + paystubs
[ ] PDF generation for paystubs
[ ] Fuel transaction logging
[ ] Fixed/variable costs
```

### Sprint 9-10: Compliance
```
[ ] Driver applications (FMCSA form)
[ ] Document management
[ ] Compliance alerts (expiring docs)
[ ] Incidents (accidents, violations, tickets)
[ ] Maintenance scheduling
```

### Sprint 11-12: IFTA & Integrations
```
[ ] IFTA mileage tracking
[ ] IFTA fuel by state
[ ] IFTA report generation
[ ] Samsara integration
[ ] Live map with GPS
```

### Sprint 13-14: Communication & Polish
```
[ ] Team chat (real-time)
[ ] Notifications system
[ ] Activity log
[ ] Email notifications
[ ] Mobile responsive polish
```

### Sprint 15-16: Billing & Launch
```
[ ] Stripe integration
[ ] Subscription plans
[ ] Usage metering
[ ] Marketing pages
[ ] Documentation
[ ] Beta launch
```

---

## 6. Key Components to Build

### Dashboard Components
```typescript
// components/features/dashboard/
├── stats-overview.tsx        // Revenue, trips, miles cards
├── revenue-chart.tsx         // Line/bar chart
├── trips-calendar.tsx        // Calendar heatmap
├── top-performers.tsx        // Trucks, drivers ranking
├── compliance-alerts.tsx     // Expiring documents
├── recent-activity.tsx       // Activity feed
└── cash-flow-widget.tsx      // COD/Bill tracking
```

### Data Table Component
```typescript
// components/shared/data-table.tsx
- Server-side pagination
- Sorting
- Filtering
- Column visibility
- Row selection
- Export to CSV
- Bulk actions
```

### Form Components
```typescript
// Using React Hook Form + Zod
- Truck form (with VIN decoder)
- Driver form (with license validation)
- Trip form (with truck/driver selection)
- Order form (with broker lookup)
- Expense form (with receipt upload)
```

---

## 7. Samsara Integration

```typescript
// lib/samsara/client.ts

interface SamsaraConfig {
  apiKey: string;
  baseUrl: string;
}

class SamsaraClient {
  // Vehicles
  async getVehicles(): Promise<Vehicle[]>
  async getVehicleLocations(): Promise<VehicleLocation[]>
  async getVehicleStats(vehicleId: string): Promise<VehicleStats>

  // Drivers
  async getDrivers(): Promise<Driver[]>
  async getDriverHOS(driverId: string): Promise<HOSStatus>

  // Fleet
  async getFleetMiles(startDate: Date, endDate: Date): Promise<FleetMiles>
  async getFuelUsage(startDate: Date, endDate: Date): Promise<FuelUsage[]>

  // IFTA
  async getIFTAReport(quarter: number, year: number): Promise<IFTAReport>
}

// Sync job (runs on schedule)
async function syncSamsaraData(orgId: string) {
  const org = await getOrganization(orgId);
  if (!org.samsara_enabled) return;

  const client = new SamsaraClient({ apiKey: org.samsara_api_key });

  // Sync vehicles
  const vehicles = await client.getVehicles();
  await syncTrucks(orgId, vehicles);

  // Sync locations for live map
  const locations = await client.getVehicleLocations();
  await cacheLocations(orgId, locations);

  // Sync fuel data
  const fuel = await client.getFuelUsage(startOfMonth, today);
  await syncFuelTransactions(orgId, fuel);
}
```

---

## 8. Environment Variables

```bash
# .env.local

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_APP_NAME="VroomX TMS"

# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# Email
RESEND_API_KEY=re_xxx

# Samsara (optional per tenant)
# Stored in database per organization

# Sentry
NEXT_PUBLIC_SENTRY_DSN=xxx
```

---

## 9. Deployment Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install
      - run: pnpm lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install
      - run: pnpm test

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install
      - run: pnpm build
```

---

## 10. Next Steps

### Immediate (This Week)
1. **Create new repository**: `vroomx-tms`
2. **Initialize Next.js project** with all configurations
3. **Setup Supabase project** with multi-tenant schema
4. **Configure design system** (colors, fonts, shadcn/ui)
5. **Build authentication flow**

### Questions for You
1. **Domain**: Have you registered a domain for VroomX?
2. **Hosting**: Are you okay with Vercel, or prefer another host?
3. **Beta users**: Do you have trucking companies lined up to test?
4. **Design**: Do you want me to create more detailed UI mockups first?

---

*Ready to start building when you are!*
