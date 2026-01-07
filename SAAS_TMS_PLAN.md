# SaaS TMS Platform - Development Plan

## Executive Summary

This document outlines the plan to build a **multi-tenant SaaS TMS (Transportation Management System)** based on the feature set of the Horizon Star TMS. The new product will have fresh branding, modern architecture, and be designed for scalability while keeping the original repository untouched.

---

## 1. Current System Analysis

### What We Have (Horizon Star TMS)
| Aspect | Current State |
|--------|---------------|
| **Architecture** | Monolithic SPA (30,000+ line single HTML file) |
| **Frontend** | Vanilla JavaScript, no framework |
| **Backend** | Supabase (PostgreSQL + Auth + Real-time + Edge Functions) |
| **Multi-tenancy** | Single-tenant (one company) |
| **Styling** | Custom CSS with design tokens |
| **Integrations** | Samsara, Resend email, jsPDF |

### Core Feature Modules (30+)
1. **Fleet Management**: Trucks, Drivers, Local Drivers, Brokers, Dispatchers
2. **Operations**: Trips, Orders, Load Board, Live Map, Team Chat
3. **Financials**: Dashboard, Payroll, Fuel Tracking, IFTA, Fixed/Variable Costs
4. **Compliance**: Driver Applications (FMCSA), Safety Tracking, Maintenance
5. **Administration**: Users, Settings, Activity Log, Tasks

---

## 2. SaaS Product Requirements

### Multi-Tenancy Model
Each customer (trucking company) needs:
- **Isolated data** - No cross-tenant data leakage
- **Custom branding** - Logo, colors (optional white-label tier)
- **Separate billing** - Per-seat or per-truck pricing
- **Role-based access** - Admin, Manager, Dispatcher, Driver roles

### Key SaaS Features to Add
| Feature | Description |
|---------|-------------|
| **Tenant Management** | Company signup, onboarding wizard |
| **Subscription Billing** | Stripe integration, plan tiers |
| **Super Admin Portal** | Manage all tenants, view metrics |
| **Self-Service Signup** | Public registration flow |
| **Custom Domains** | CNAME support (enterprise tier) |
| **API Access** | REST API for integrations |
| **Mobile Apps** | iOS/Android apps (later phase) |

---

## 3. Recommended Architecture

### Option A: Modern Full-Stack (Recommended)
```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND                                  │
│  Next.js 14+ (App Router) / React 18                            │
│  • TypeScript                                                    │
│  • Tailwind CSS + shadcn/ui components                          │
│  • React Query for data fetching                                │
│  • Zustand for state management                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        BACKEND                                   │
│  Option 1: Supabase (faster to market)                          │
│  • PostgreSQL with RLS for multi-tenancy                        │
│  • Supabase Auth with tenant context                            │
│  • Edge Functions for business logic                            │
│                                                                  │
│  Option 2: Custom Backend (more control)                        │
│  • Node.js/Express or Next.js API routes                        │
│  • Prisma ORM                                                    │
│  • PostgreSQL                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INFRASTRUCTURE                              │
│  • Vercel (frontend + API routes)                               │
│  • Supabase / PlanetScale (database)                            │
│  • Stripe (billing)                                              │
│  • Resend (transactional email)                                 │
│  • Cloudflare (CDN, custom domains)                             │
│  • Sentry (error tracking)                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Multi-Tenancy Database Design

**Schema-per-tenant** (not recommended for SaaS scale)
vs
**Row-level isolation** (recommended) ✅

```sql
-- Every table gets a tenant_id column
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,  -- mycompany.tms-saas.com
    plan VARCHAR(50) DEFAULT 'starter',
    stripe_customer_id VARCHAR(255),
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Example: trucks table with tenant isolation
CREATE TABLE trucks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    truck_number VARCHAR(50) NOT NULL,
    vin VARCHAR(17),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    -- ... other fields
    UNIQUE(tenant_id, truck_number)  -- Unique per tenant
);

-- Row Level Security Policy
CREATE POLICY tenant_isolation ON trucks
    USING (tenant_id = current_setting('app.current_tenant')::UUID);
```

---

## 4. Feature Parity Mapping

### Phase 1: Core MVP (Must-Have)
| Horizon Star Feature | SaaS Version | Priority |
|---------------------|--------------|----------|
| Authentication | Multi-tenant auth with tenant context | P0 |
| Dashboard | Tenant-specific KPIs | P0 |
| Trucks | Fleet management | P0 |
| Drivers | Driver management | P0 |
| Trips | Trip planning & tracking | P0 |
| Orders | Order management | P0 |
| Basic Financials | Revenue tracking | P0 |
| User Management | Tenant admin panel | P0 |

### Phase 2: Operations Enhancement
| Feature | Description | Priority |
|---------|-------------|----------|
| Load Board | Visual trip planning | P1 |
| Dispatchers | Dispatcher management & ranking | P1 |
| Brokers | Broker/customer management | P1 |
| Payroll | Driver earnings & paystubs | P1 |
| Fuel Tracking | Fuel transaction logging | P1 |
| Team Chat | Real-time messaging | P1 |

### Phase 3: Compliance & Advanced
| Feature | Description | Priority |
|---------|-------------|----------|
| Driver Applications | FMCSA-compliant forms | P2 |
| Compliance Dashboard | Safety tracking | P2 |
| Claims/Accidents | Incident management | P2 |
| IFTA Reporting | Tax compliance | P2 |
| Maintenance | Service scheduling | P2 |
| Live Map | GPS integration (Samsara) | P2 |

### Phase 4: Enterprise & Scale
| Feature | Description | Priority |
|---------|-------------|----------|
| AI Advisor | Business recommendations | P3 |
| Custom Reports | Report builder | P3 |
| API Access | Public REST API | P3 |
| White-Label | Custom branding per tenant | P3 |
| Mobile Apps | iOS/Android native | P3 |

---

## 5. New Product Branding

### Suggested Names (Examples)
- **FleetPulse TMS**
- **RouteCommand**
- **TruckFlow Pro**
- **CarrierOS**
- **DispatchHub**

### Design System

```
┌─────────────────────────────────────────────┐
│           DESIGN TOKENS                      │
├─────────────────────────────────────────────┤
│ Primary Colors:                              │
│   --brand-primary: #2563eb (Blue)           │
│   --brand-secondary: #0891b2 (Cyan)         │
│   --brand-accent: #7c3aed (Purple)          │
│                                              │
│ Semantic Colors:                             │
│   --success: #10b981                         │
│   --warning: #f59e0b                         │
│   --error: #ef4444                           │
│   --info: #3b82f6                            │
│                                              │
│ Typography:                                  │
│   --font-display: "Inter", sans-serif       │
│   --font-body: "Inter", sans-serif          │
│   --font-mono: "JetBrains Mono", mono       │
│                                              │
│ Spacing: 4px base unit (4, 8, 12, 16...)   │
│ Border Radius: 6px (sm), 8px (md), 12px(lg)│
└─────────────────────────────────────────────┘
```

### UI Component Library
Recommend: **shadcn/ui** (Radix primitives + Tailwind)
- Modern, accessible components
- Fully customizable
- TypeScript support
- Dark/light mode built-in

---

## 6. Project Structure

```
saas-tms/
├── apps/
│   ├── web/                    # Main Next.js app
│   │   ├── app/
│   │   │   ├── (auth)/        # Login, signup, forgot password
│   │   │   ├── (dashboard)/   # Protected tenant pages
│   │   │   │   ├── dashboard/
│   │   │   │   ├── fleet/
│   │   │   │   │   ├── trucks/
│   │   │   │   │   ├── drivers/
│   │   │   │   │   └── trailers/
│   │   │   │   ├── operations/
│   │   │   │   │   ├── trips/
│   │   │   │   │   ├── orders/
│   │   │   │   │   └── loadboard/
│   │   │   │   ├── financials/
│   │   │   │   │   ├── overview/
│   │   │   │   │   ├── payroll/
│   │   │   │   │   └── reports/
│   │   │   │   ├── compliance/
│   │   │   │   └── settings/
│   │   │   ├── (marketing)/   # Public marketing pages
│   │   │   └── api/           # API routes
│   │   ├── components/
│   │   │   ├── ui/            # shadcn components
│   │   │   ├── features/      # Feature-specific components
│   │   │   └── layouts/       # Layout components
│   │   └── lib/
│   │       ├── supabase/      # Database client
│   │       ├── stripe/        # Billing
│   │       └── utils/         # Helpers
│   │
│   └── admin/                  # Super admin portal
│       └── ...
│
├── packages/
│   ├── database/              # Prisma schema, migrations
│   ├── ui/                    # Shared UI components
│   ├── types/                 # TypeScript types
│   └── utils/                 # Shared utilities
│
├── supabase/
│   ├── migrations/            # SQL migrations
│   └── functions/             # Edge functions
│
└── docs/                       # Documentation
```

---

## 7. Database Schema (Key Tables)

### Core Multi-Tenant Tables

```sql
-- Tenant (Company) Management
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    logo_url TEXT,
    settings JSONB DEFAULT '{}',
    plan_id UUID REFERENCES plans(id),
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    trial_ends_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Subscription Plans
CREATE TABLE plans (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,        -- 'Starter', 'Professional', 'Enterprise'
    price_monthly DECIMAL(10,2),
    price_yearly DECIMAL(10,2),
    max_trucks INT,
    max_users INT,
    features JSONB,                     -- Feature flags
    stripe_price_id VARCHAR(255)
);

-- Users (with tenant association)
CREATE TABLE users (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'dispatcher',  -- admin, manager, dispatcher, driver
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

-- Invitations
CREATE TABLE invitations (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50),
    invited_by UUID REFERENCES users(id),
    expires_at TIMESTAMP,
    accepted_at TIMESTAMP
);
```

### Fleet & Operations Tables
(Same structure as Horizon Star, with `tenant_id` added to each table)

```sql
CREATE TABLE trucks (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    truck_number VARCHAR(50) NOT NULL,
    vin VARCHAR(17),
    make VARCHAR(100),
    model VARCHAR(100),
    year INT,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    license_plate VARCHAR(20),
    fuel_type VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE drivers (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID REFERENCES users(id),  -- Link to user account (optional)
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    license_number VARCHAR(50),
    license_state VARCHAR(2),
    license_class VARCHAR(10),
    license_expires DATE,
    medical_expires DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    payment_cut DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE trips (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    trip_number VARCHAR(50),            -- Auto-generated: T-2024-0001
    status VARCHAR(20) DEFAULT 'PLANNED',
    trip_date DATE NOT NULL,
    truck_id UUID REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),
    total_miles DECIMAL(10,2),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    order_number VARCHAR(50),           -- Auto-generated: ORD-2024-0001
    trip_id UUID REFERENCES trips(id),
    broker_id UUID REFERENCES brokers(id),
    pickup_location TEXT,
    delivery_location TEXT,
    pickup_date DATE,
    delivery_date DATE,
    revenue DECIMAL(10,2),
    payment_type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'PENDING',
    dispatcher_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 8. Pricing Strategy

### Suggested Tier Structure

| Tier | Price/mo | Trucks | Users | Features |
|------|----------|--------|-------|----------|
| **Starter** | $49 | 5 | 3 | Core TMS, Dashboard, Basic Reports |
| **Professional** | $149 | 25 | 10 | + Compliance, Payroll, Fuel Tracking |
| **Business** | $349 | 100 | 25 | + API Access, Advanced Reports, Priority Support |
| **Enterprise** | Custom | Unlimited | Unlimited | + White-label, Custom Integrations, SLA |

### Usage-Based Add-ons
- GPS Tracking (Samsara): +$5/truck/month
- SMS Notifications: +$0.02/message
- Additional Users: +$10/user/month
- API Calls: +$0.001/request (over 10k/month)

---

## 9. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-6)
```
Week 1-2: Project Setup
├── Initialize Next.js 14 project with TypeScript
├── Setup Supabase project with multi-tenant schema
├── Configure Tailwind + shadcn/ui
├── Setup CI/CD pipeline (GitHub Actions → Vercel)
└── Basic authentication flow

Week 3-4: Core Infrastructure
├── Multi-tenancy middleware
├── Tenant signup/onboarding flow
├── User management (invite, roles)
├── Settings page
└── Basic dashboard layout

Week 5-6: Fleet MVP
├── Trucks CRUD
├── Drivers CRUD
├── Basic dashboard with stats
└── Activity logging
```

### Phase 2: Operations Core (Weeks 7-12)
```
Week 7-8: Trip Management
├── Trips CRUD with status workflow
├── Trip calendar view
├── Assign trucks/drivers to trips
└── Trip detail page

Week 9-10: Order Management
├── Orders CRUD
├── Assign orders to trips
├── Load board (visual planning)
└── Basic financials (revenue tracking)

Week 11-12: Communication
├── Team chat (real-time)
├── Notifications system
├── Email alerts
└── Mobile-responsive polish
```

### Phase 3: Financial & Compliance (Weeks 13-18)
```
Week 13-14: Financial Module
├── Comprehensive financials dashboard
├── Payroll calculation engine
├── Paystub generation (PDF)
└── Expense tracking

Week 15-16: Compliance
├── Driver applications (FMCSA forms)
├── Document management
├── Compliance tracking dashboard
└── Maintenance scheduling

Week 17-18: Billing Integration
├── Stripe integration
├── Plan management
├── Usage metering
└── Invoice history
```

### Phase 4: Polish & Launch (Weeks 19-24)
```
Week 19-20: Advanced Features
├── IFTA reporting
├── Fuel tracking with analytics
├── Advanced reporting
└── Data import tools

Week 21-22: Testing & QA
├── End-to-end testing
├── Performance optimization
├── Security audit
└── User acceptance testing

Week 23-24: Launch Preparation
├── Marketing website
├── Documentation
├── Support system setup
└── Beta launch
```

---

## 10. Technology Decisions

### Recommended Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **Framework** | Next.js 14 (App Router) | Full-stack, excellent DX, Vercel deployment |
| **Language** | TypeScript | Type safety, better maintainability |
| **Styling** | Tailwind CSS | Utility-first, fast iteration |
| **Components** | shadcn/ui | High quality, accessible, customizable |
| **State** | Zustand + React Query | Simple, performant, server-state friendly |
| **Database** | Supabase (PostgreSQL) | Familiar, real-time, auth included |
| **ORM** | Prisma | Type-safe queries, migrations |
| **Auth** | Supabase Auth | Multi-tenant ready, social logins |
| **Billing** | Stripe | Industry standard, webhooks |
| **Email** | Resend | Modern API, good DX |
| **File Storage** | Supabase Storage | Integrated, S3-compatible |
| **Hosting** | Vercel | Edge functions, easy deploys |
| **Monitoring** | Sentry + Vercel Analytics | Error tracking, performance |

### Alternative Considerations

| If you prefer... | Consider |
|------------------|----------|
| Full control over auth | Auth.js (NextAuth) + custom DB |
| More backend control | tRPC + Prisma + custom API |
| Lower costs at scale | Railway/Render + self-hosted Postgres |
| Vue ecosystem | Nuxt 3 + similar stack |

---

## 11. Key Differences from Horizon Star

| Aspect | Horizon Star | SaaS Version |
|--------|--------------|--------------|
| **Tenancy** | Single company | Multi-tenant |
| **Architecture** | Monolithic SPA | Modular Next.js |
| **Code organization** | 1 HTML file | Component-based |
| **Authentication** | Basic Supabase | Multi-tenant aware |
| **Database** | Single instance | RLS-isolated |
| **Billing** | None | Stripe subscriptions |
| **Onboarding** | Manual setup | Self-service wizard |
| **Branding** | Horizon Star | New brand (configurable) |
| **API** | Internal only | Public REST API |
| **Mobile** | PWA | Native apps (future) |

---

## 12. Migration Strategy for Features

### Code Reuse Opportunities
1. **Business Logic**: Financial calculations, payroll formulas → Extract to utility functions
2. **Database Schema**: Core table structures → Add tenant_id, migrate
3. **PDF Generation**: jsPDF templates → Port to server-side or keep client-side
4. **Real-time Sync**: Supabase channels → Same pattern, tenant-scoped

### What Needs Rewriting
1. **UI Components**: Vanilla JS → React/shadcn components
2. **State Management**: Global vars → Zustand stores
3. **Routing**: Manual navigate() → Next.js App Router
4. **Auth Flow**: Basic login → Multi-tenant with org context

---

## 13. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Feature creep | Strict MVP scope, phase releases |
| Multi-tenancy bugs | Comprehensive RLS testing, security audit |
| Performance at scale | Load testing early, optimize queries |
| Stripe complexity | Use Stripe's hosted checkout initially |
| Competition | Focus on UX, niche features (FMCSA compliance) |

---

## 14. Success Metrics

### Launch Metrics (Month 1-3)
- 50 beta signups
- 10 paying customers
- <2s page load time
- 99.9% uptime

### Growth Metrics (Month 6-12)
- $10k MRR
- 100 paying customers
- <1% monthly churn
- NPS > 40

---

## 15. Next Steps

### Immediate Actions
1. **Decide on product name** and register domain
2. **Create new repository** for SaaS version
3. **Setup Supabase project** with multi-tenant schema
4. **Initialize Next.js project** with recommended stack
5. **Design brand identity** (logo, colors, typography)

### Questions to Answer
1. What's the target launch date?
2. Who are the first beta customers?
3. What's the pricing strategy validation approach?
4. Build in-house or hire additional developers?
5. Which integrations are must-have for MVP (Samsara, ELD, etc.)?

---

## Appendix A: Feature Checklist

### Phase 1 MVP Checklist
- [ ] Multi-tenant authentication
- [ ] Tenant signup & onboarding
- [ ] User invitation system
- [ ] Dashboard with KPIs
- [ ] Trucks management
- [ ] Drivers management
- [ ] Trips management
- [ ] Orders management
- [ ] Basic financials
- [ ] Settings page
- [ ] Stripe billing integration

### Phase 2 Checklist
- [ ] Load board
- [ ] Dispatchers management
- [ ] Brokers management
- [ ] Payroll with paystubs
- [ ] Fuel tracking
- [ ] Team chat
- [ ] Notifications

### Phase 3 Checklist
- [ ] Driver applications (FMCSA)
- [ ] Compliance dashboard
- [ ] Claims/Accidents tracking
- [ ] IFTA reporting
- [ ] Maintenance scheduling
- [ ] Live map (GPS)

### Phase 4 Checklist
- [ ] AI Advisor
- [ ] Custom report builder
- [ ] Public API
- [ ] White-label support
- [ ] Mobile apps

---

*Document Version: 1.0*
*Created: January 2026*
*Based on: Horizon Star TMS Analysis*
