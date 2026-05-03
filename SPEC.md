# Catering Management System — Specification

> A multi-tenant web app to manage office catering, daily lunch polls, custom orders, and billing. Built so any office can spin up their own workspace.

---

## 1. Overview

### 1.1 Problem
Offices that arrange their own lunch catering (not provided by the company) struggle with:
- Manually tracking who ate on which day
- Calculating monthly dues per person
- Coordinating daily attendance via WhatsApp polls
- Handling cases where someone wants food from a different source instead of catering

### 1.2 Solution
A web app that:
- Replaces WhatsApp polls with a structured daily attendance system
- Auto-calculates monthly dues per person
- Supports custom orders (food from outside the catering)
- Lets multiple offices use the same platform (multi-tenant)

### 1.3 Goals
- **MVP in 4–6 weeks** — solve the immediate pain for one office (J&J catering use case)
- **Multi-tenant from day one** — architecture supports any office, even though v1 is used internally only
- **Mobile-first** — most usage will be from phones, especially for daily check-ins
- **Zero-cost to start** — run on free tiers until there's real usage
- **Internal validation first** — our own company is the experimental rollout. No external signups, no subscriptions in v1. Open up to other offices only after internal validation.

### 1.4 Non-Goals (for MVP)
- Native mobile apps (PWA is enough)
- Payment gateway integration (track payments, don't process them)
- Inventory or food preparation management (that's the caterer's problem)
- Multi-language support in v1 (English only initially)
- **Subscriptions, paid tiers, usage limits** (deferred — will be evaluated post-MVP)
- **Public/external workspace signups** (internal use only in v1)

---

## 2. Users & Roles

The system has **four roles**, all living within a single project/codebase. The System Admin is just a special permission flag, not a separate app.

### 2.1 System Admin (Root Admin)
- The developer/platform owner (you)
- Has access to a hidden `/system` route within the same app
- Can view all workspaces, suspend/delete them, view platform analytics
- Identified by a `is_system_admin` boolean on the user record
- Login flow is the same as everyone else, but extra routes unlock based on the flag
- Stricter security: 2FA required, all actions audit-logged

### 2.2 Workspace Owner
- The user who created the workspace
- Has all Workspace Admin permissions plus exclusive rights:
  - Transfer ownership to another member
  - Delete the workspace
- Exactly one owner per workspace at any time
- Can transfer ownership to any existing member; after transfer, becomes a regular member or admin (configurable at transfer time)
- After transferring, the previous owner can delete their own user account without affecting the workspace

### 2.3 Workspace Admin
- The office assistant or coordinator (e.g., Jabed Vai)
- Manages a single workspace
- Configures meal price, working days, members, billing
- Multiple workspace admins per workspace allowed (co-admins)
- Cannot delete workspace or transfer ownership (only the owner can)

### 2.4 Manager (Optional)
- Helps the workspace admin
- Can manage daily orders and lock days
- Cannot access billing or workspace settings

### 2.5 Member
- Regular office staff
- Marks own daily attendance, places custom orders
- Views own dues and payment history

---

## 3. Core Concepts

### 3.1 Workspace
A workspace represents one office's lunch group. Each workspace has its own members, settings, meals, and billing. Data is fully isolated per workspace.

### 3.2 Meal Day
A single date in a workspace. Has a status: `open` (accepting responses), `locked` (no more edits), or `closed` (billing finalized).

### 3.3 Meal Entry
One person's response for one meal day. Has a type: `catering`, `custom`, or `skip`.

### 3.4 Custom Order
A meal entry where the person wants food from somewhere other than the catering. Includes item name, source, price, and notes.

### 3.5 Bill
A calculated total for one member over a date range, summing all catering meals at standard rate plus all custom orders at their individual prices.

---

## 4. Features (MVP Scope)

### 4.1 Authentication
- Email/password signup
- Google OAuth login
- Magic link login
- Password reset
- User profile (name, phone, photo)
- Logout from all devices

### 4.2 Workspace Management
- Create workspace (name, timezone, currency, working days, bill due date)
- Workspace settings page
- Currency selection (BDT default, supports USD, INR, EUR, etc.) — locked once transactions exist
- Bill due date configuration (e.g., 5th of next month, last working day, custom)
- Default meal cutoff: **10:00 AM** workspace local time (overridable)
- Invite members via shareable link (**valid for 24 hours**)
- Invite members via email
- Workspace switcher (user can be in multiple workspaces)
- Transfer ownership to another member
- Archive/delete workspace (owner only)

### 4.3 Daily Lunch Poll
- Three-option entry: **Catering / Custom Order / Skip**
- Recurring weekly schedule ("I always eat Mon, Wed, Fri")
- Bulk mark for date range ("on leave June 5–10")
- Guest meal addition (+1 today)
- Live count of today's responses
- Edit own response before cutoff
- Cutoff time enforcement (default **10:00 AM**, configurable per workspace)
- **Auto-default to Skip** if user doesn't respond by cutoff (recurring schedule overrides this if set)
- Lock day after meal served

### 4.4 Custom Orders
- Item name, source/restaurant, estimated price, notes
- Earlier cutoff than catering (configurable)
- Status flow: Requested → Ordered → Delivered → Confirmed
- Admin updates final price after delivery
- Saved favorites for quick reuse

### 4.5 Catering Configuration
- Standard meal price (per workspace)
- Day-specific pricing override (e.g., Friday biriyani costs more)
- Caterer info (name, contact, optional)
- Holiday calendar (auto-skip days)

### 4.6 Workspace Admin Dashboard
- Today's summary: catering count, custom orders, skips
- Tomorrow's preview
- Pending custom orders list with status
- Outstanding dues summary across members
- Quick actions: lock day, override entry, mark order as delivered
- Print-friendly daily order sheet

### 4.7 Billing
- Auto-calculated monthly bill per member
- Custom date range billing
- **Bill due date** configurable per workspace (e.g., 5th of next month, last working day, custom)
- Bill breakdown (catering + custom orders + adjustments)
- Mark dues as paid/unpaid
- Partial payment support
- Payment method tracking (cash, bKash, bank, etc.)
- Payment history per member
- Outstanding balance with aging (based on due date)
- Manual adjustment entry
- Bill PDF export

### 4.8 Notifications
- Morning reminder ("Mark your lunch by 10 AM")
- Email notifications
- Browser push notifications (PWA)
- Cutoff approaching alert
- Custom order status updates
- Monthly bill ready notification

### 4.9 System Admin (Inside Same App)
- Hidden `/system` routes, only accessible if `is_system_admin = true`
- Workspace directory (list, search, filter)
- Workspace detail view
- Suspend / restore workspace
- Soft-delete workspace (30-day retention)
- Platform user search
- Platform analytics dashboard
- Audit log viewer
- Global announcement banner (optional in v1)

### 4.10 Quality of Life
- Mobile-responsive design (PWA)
- Dark mode
- Onboarding tutorial for new workspaces
- Feedback button

---

## 5. Tech Stack

### 5.1 Frontend + Backend
- **Next.js 15** with App Router and TypeScript
- Single codebase handles UI, API routes, and server logic
- Server Components for performance
- Server Actions for mutations

> Note: the installed Next.js in this repo is **16.2.4** (newer than 15). Treat the installed version as authoritative; consult `node_modules/next/dist/docs/` for current APIs and conventions before writing code.

### 5.2 Database & Auth
- **Supabase** (Postgres + Auth + Realtime + Storage)
- Row-level security (RLS) for workspace isolation
- Realtime subscriptions for live poll counts

### 5.3 Styling & UI
- **Tailwind CSS** for utility-first styling
- **shadcn/ui** for copy-paste React components
- **Lucide React** for icons

### 5.4 State & Data
- **TanStack Query** for server state
- **Zustand** for small client state
- **React Hook Form + Zod** for forms and validation

### 5.5 Hosting & Infrastructure
- **Vercel** for hosting (Next.js native)
- **Supabase Cloud** for database
- **Vercel Cron** for scheduled jobs (cutoff enforcement, reminders)

### 5.6 Notifications
- **Resend** for transactional email
- **Web Push API** for browser notifications
- **Twilio / WhatsApp Business API** for WhatsApp (Phase 2)

### 5.7 Other
- **Sentry** for error tracking
- **PostHog** for product analytics
- **react-pdf** for bill generation

---

## 6. System Architecture

### 6.1 Single Project, Permission-Gated Routes

```
/app
├── (public)              → Marketing, login, signup
├── (auth)                → Auth flows
├── (workspace)           → Member + workspace admin pages
│   ├── dashboard
│   ├── poll
│   ├── orders
│   ├── billing
│   └── settings
├── system                → System admin pages (gated by is_system_admin)
│   ├── workspaces
│   ├── users
│   ├── analytics
│   └── audit
└── api                   → API routes
```

**Critical rule:** The `/system` routes are protected by middleware that checks `is_system_admin`. They live in the same Next.js project, share the same database, and use the same auth — but unauthorized users get a 404 (not 403, to avoid leaking the existence of the admin panel).

### 6.2 Data Isolation
- Every workspace-scoped table has a `workspace_id` foreign key
- Postgres Row-Level Security (RLS) enforces "users can only see data from workspaces they belong to"
- System admin role bypasses RLS via a service role key (only used in `/system` routes)

### 6.3 Authentication Flow
1. User signs up / logs in via Supabase Auth (email, Google, magic link)
2. JWT token issued and stored in cookies
3. Middleware reads JWT on every request, attaches user context
4. RLS uses JWT claims to filter rows per request

---

## 7. Database Schema (High-Level)

### 7.1 Core Tables

**users**
- `id` (uuid, PK)
- `email`
- `name`
- `phone`
- `photo_url`
- `is_system_admin` (boolean, default false)
- `created_at`

**workspaces**
- `id` (uuid, PK)
- `name`
- `owner_id` (FK to users — exactly one owner at a time)
- `timezone`
- `currency` (default 'BDT'; locked once transactions exist)
- `working_days` (array: ['sun','mon','tue','wed','thu'])
- `meal_cutoff_time` (default '10:00')
- `custom_order_cutoff_time` (default '10:00')
- `default_meal_price`
- `bill_due_config` (jsonb: e.g., `{type: 'day_of_next_month', day: 5}` or `{type: 'last_working_day'}` or `{type: 'custom', day: 15}`)
- `status` (active, suspended, deleted)
- `created_at`

**workspace_members**
- `id` (uuid, PK)
- `workspace_id` (FK)
- `user_id` (FK)
- `role` (owner, admin, manager, member)
- `joined_at`

**meal_days**
- `id` (uuid, PK)
- `workspace_id` (FK)
- `date`
- `status` (open, locked, closed)
- `meal_price` (override of workspace default)
- `is_holiday` (boolean)

**meal_entries**
- `id` (uuid, PK)
- `meal_day_id` (FK)
- `user_id` (FK)
- `type` (catering, custom, skip)
- `guest_count` (default 0)
- `created_at`
- `updated_at`

**custom_orders**
- `id` (uuid, PK)
- `meal_entry_id` (FK)
- `item_name`
- `source` (restaurant)
- `estimated_price`
- `final_price`
- `notes`
- `status` (requested, ordered, delivered, confirmed)

**recurring_schedules**
- `id` (uuid, PK)
- `user_id` (FK)
- `workspace_id` (FK)
- `days_of_week` (array)
- `default_type` (catering, custom, skip)

**payments**
- `id` (uuid, PK)
- `workspace_id` (FK)
- `user_id` (FK)
- `amount`
- `method` (cash, bkash, bank, other)
- `note`
- `paid_on`
- `recorded_by` (FK to users)

**adjustments**
- `id` (uuid, PK)
- `workspace_id` (FK)
- `user_id` (FK)
- `amount` (can be negative)
- `reason`
- `created_at`

**audit_logs**
- `id` (uuid, PK)
- `actor_user_id` (FK)
- `action`
- `target_type`
- `target_id`
- `metadata` (jsonb)
- `created_at`

**workspace_invites**
- `id` (uuid, PK)
- `workspace_id` (FK)
- `email`
- `token`
- `invited_by`
- `expires_at` (default: created_at + 24 hours)
- `accepted_at`

---

## 8. Key User Flows

### 8.1 New User Signs Up & Creates Workspace
1. User visits site, clicks "Get Started"
2. Signs up with email/Google
3. Lands on "Create Workspace or Join One" screen
4. Creates workspace (name, timezone, currency [BDT default], working days, meal price, bill due date, cutoff time [10:00 AM default])
5. Becomes the **workspace owner** automatically
6. Sees onboarding tutorial
7. Invites members via shareable link (valid for 24 hours)

### 8.2 Daily Member Flow (Morning)
1. Member opens app (PWA on phone)
2. Sees today's question: "Lunch today?"
3. Taps Catering / Custom / Skip
4. If Custom: fills item, source, optional price
5. Sees confirmation + live count of today's catering total
6. Optional: receives push notification reminder if not responded by 9:30 AM

### 8.3 Workspace Admin Daily Flow (Morning)
1. Jabed Vai opens dashboard
2. Sees today's summary: 12 catering, 3 custom, 2 skip
3. Reviews custom orders list
4. Calls/orders custom items, marks each as "Ordered"
5. After cutoff time, locks the day
6. After lunch, marks orders as "Delivered" and confirms final prices

### 8.4 Monthly Billing Flow
1. End of month, admin opens Billing tab
2. System auto-generates bills for all members
3. Admin reviews each member's breakdown
4. Shares bill PDF or in-app link with each member
5. As members pay, admin marks them as paid (records method)
6. Outstanding dues remain visible with aging

### 8.5 System Admin Flow
1. Logs in normally (same login page)
2. Because `is_system_admin = true`, sees a "System Admin" link in profile menu
3. Goes to `/system/workspaces`
4. Searches/filters workspaces, views stats
5. Can suspend a workspace if abuse detected
6. Every action logged in audit trail

### 8.6 Ownership Transfer Flow
1. Owner goes to Workspace Settings → Transfer Ownership
2. Selects a member from the workspace
3. Chooses what role they will have post-transfer (admin or member)
4. Confirms with password re-entry
5. New owner receives notification
6. Previous owner can now optionally delete their account without affecting the workspace

---

## 9. Permissions Matrix

| Action | Member | Manager | Workspace Admin | Workspace Owner | System Admin |
|--------|--------|---------|-----------------|-----------------|--------------|
| Mark own meal entry | Yes | Yes | Yes | Yes | Yes |
| View own dues | Yes | Yes | Yes | Yes | Yes |
| View workspace member list | Yes | Yes | Yes | Yes | Yes |
| View other members' dues | No | Yes | Yes | Yes | Yes |
| Lock/unlock meal day | No | Yes | Yes | Yes | Yes |
| Manage custom orders | No | Yes | Yes | Yes | Yes |
| Configure workspace settings | No | No | Yes | Yes | Yes |
| Invite members | No | No | Yes | Yes | Yes |
| Record payments | No | No | Yes | Yes | Yes |
| Transfer ownership | No | No | No | Yes | Yes |
| Delete workspace | No | No | No | Yes | Yes |
| View all workspaces | No | No | No | No | Yes |
| Suspend any workspace | No | No | No | No | Yes |
| View platform analytics | No | No | No | No | Yes |

---

## 10. Security Considerations

### 10.1 General
- All routes protected by Next.js middleware
- HTTPS only (Vercel handles this)
- CSRF protection via SameSite cookies
- Rate limiting on auth endpoints
- Input validation with Zod on every API route

### 10.2 Workspace Isolation
- Every database query filtered by `workspace_id`
- Postgres RLS as a second line of defense
- API routes verify user belongs to workspace before any operation

### 10.3 System Admin
- `is_system_admin` flag set manually in DB (no UI to grant it)
- Required 2FA before accessing `/system` routes
- All system admin actions logged with timestamp, IP, user agent
- Impersonation feature (Phase 2) requires explicit reason input
- `/system` routes return 404 (not 403) for non-admins

### 10.4 Data Protection
- Passwords hashed by Supabase (never stored in plain text)
- PII encrypted at rest
- Soft-delete workspaces (30-day grace period before hard delete)
- Users can export their own data (GDPR-style, Phase 2)

---

## 11. Phasing & Roadmap

### Phase 1 — MVP (4–6 weeks)
**Rollout strategy:** Internal use only. Our own company will be the first and only workspace during this phase to validate real-world usage.

- Auth (email, Google, magic link)
- Workspace creation, member invites (24-hour link expiry)
- Daily poll (3 options, 10 AM cutoff, auto-skip default, lock)
- Custom orders (basic flow)
- Workspace admin dashboard
- Monthly billing with PDF export, configurable due dates
- Payment tracking
- Ownership transfer
- Basic system admin (workspace list, suspend, audit log)
- Mobile-responsive PWA

### Phase 2 (After MVP feedback)
- WhatsApp notifications
- Recurring schedules
- Group custom orders (combine same-restaurant)
- Analytics & reporting
- Multi-caterer support
- Menu of the day
- System admin: impersonation, announcement banner, support inbox
- Open up to other offices (if validated internally)

### Phase 3 (Long-term)
- Multi-language (Bengali, Hindi)
- Native mobile apps (only if real demand)
- Payment gateway integration
- Caterer-side portal (for the catering company itself)
- Public roadmap & feature voting
- **Subscriptions/tiers** (decide based on Phase 1–2 usage data)

---

## 12. Success Metrics

### MVP Success Criteria
- Your office uses it for 30 consecutive days without falling back to WhatsApp
- Monthly billing accuracy: 100% (no manual corrections needed)
- Daily check-in completion rate > 90% before cutoff
- At least 2 other offices try it within 3 months of launch

### Long-term Metrics
- Monthly active workspaces
- Daily active users per workspace
- Average meals tracked per workspace per month
- Workspace retention at 30/60/90 days
- Bill accuracy (manual adjustments / total bills)

---

## 13. Resolved Decisions

The following decisions are locked for v1. Anything marked "deferred" will be revisited in a later release.

1. **Cutoff defaults** — Default cutoff is **10:00 AM** (workspace local timezone) for both catering and custom orders. Workspace admin can override per workspace.
2. **Auto-default behavior** — If a user doesn't respond by cutoff, they are marked as **Skip lunch** automatically. This is the safest default — no charge, no waste. Recurring schedules can override this for users who set them.
3. **Currency** — **BDT is the primary/default currency.** Workspace admin can choose a different currency in workspace settings (USD, INR, EUR, etc.). Currency is set per-workspace and cannot be changed once transactions exist (to avoid billing inconsistencies).
4. **Invite link expiry** — Invite links are valid for **24 hours** from creation. Expired links can be regenerated by workspace admin.
5. **Bill due dates** — **Each workspace sets its own bill due date** (e.g., "5th of the following month", "last working day", or a custom day). Configured in workspace settings.
6. **Workspace ownership transfer** — The workspace owner can transfer ownership to any existing member of that workspace. Once transferred, the previous owner becomes a regular member (or admin, configurable at transfer time). After transfer, the previous owner can delete their own account without affecting the workspace.
7. **Subscriptions / tiers** — **Deferred.** v1 has no paid tiers, no subscription logic, no usage limits. The platform will be used internally by our own company as the experimental rollout. Monetization decisions will be made post-MVP based on real usage data.
8. **Mid-month working-day changes apply forward only.** Changing a workspace's `working_days` does not retroactively alter already-generated `meal_days` or existing entries. New `meal_days` from the change date onward use the updated set.
9. **Guest meals are billed to the host.** A `+1` guest count on a member's entry adds one meal at that day's `meal_price` (or workspace default) to the host's bill.
10. **Day-specific pricing uses `meal_days.meal_price` (nullable).** Null means "use workspace default". A separate pricing-rules table is deferred until a real recurring-rule requirement appears.
11. **Sole-owner accounts cannot self-delete.** If a user is the only owner of any workspace, account deletion is blocked until ownership is transferred. After transfer, deletion proceeds normally.

---

## 14. Glossary

- **Workspace** — A single office's lunch group with isolated data
- **Meal Day** — One specific date within a workspace
- **Meal Entry** — One person's response for one meal day
- **Cutoff** — The time after which meal entries are frozen
- **Lock** — Admin action to freeze a meal day for editing
- **Catering Meal** — Standard meal from the contracted caterer
- **Custom Order** — Meal from a non-catering source (e.g., chowmein from XYZ)
- **System Admin** — Platform owner/developer with cross-workspace access
- **Workspace Admin** — Office coordinator who manages a single workspace
- **RLS** — Row-Level Security, Postgres feature for data isolation

---

## Appendix A — Reference Use Case (J&J Catering)

**Setup:**
- Office of ~20 people in Bangladesh
- Office Assistant Jabed Vai coordinates with J&J catering
- Currency: BDT (default)
- Working days: Sunday to Thursday (skip Fri, Sat)
- Standard meal price: BDT 120 (example)
- Cutoff: 10:00 AM (default)
- Bill due date: 5th of the following month
- Friday is off; occasionally someone wants chowmein from a nearby restaurant

**Workflow that this app replaces:**
1. WhatsApp poll daily morning → app daily poll (auto-skip if no response by 10 AM)
2. Manual spreadsheet of who ate what → auto-tracked
3. Manual monthly calculation → auto-generated bill
4. Cash collection with manual notes → recorded payments with history

This is the primary validation case for MVP. The platform is internal-only during this phase.
