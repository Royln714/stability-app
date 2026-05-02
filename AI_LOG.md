# AI_LOG.md — FormuLab Hub: Build Summary

**Project:** FormuLab Hub — Cosmetic Stability Testing & Formulation Management System
**Stack:** Node.js / Express + React 18 + MongoDB
**Generated:** 2026-05-01

---

## 1. Project Overview

FormuLab Hub is a full-stack web application designed for cosmetic and chemical manufacturers to:
- Track temperature-dependent stability tests across multiple time points (up to 3 months)
- Manage product formulations with ingredient databases and PDF export
- Administer users, roles, and audit trails
- Send automated daily email reminders for overdue or due-soon test results

The application is structured as a monorepo: an Express backend (`server.js`) serving a React frontend (`client/`) built with Vite.

---

## 2. Directory Structure

```
stability-app/
├── client/                        # React frontend
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Dashboard.jsx      # Sample list, status, alerts
│   │   │   ├── SampleDetail.jsx   # Results entry, charts, images, PDF
│   │   │   ├── Formulations.jsx   # Formulation card grid
│   │   │   ├── FormulationSheet.jsx  # Full formulation editor
│   │   │   ├── AdminPanel.jsx     # User management, audit log, backup
│   │   │   ├── ComparisonPage.jsx # Multi-sample chart comparison
│   │   │   ├── LoginPage.jsx      # Auth + forgot password
│   │   │   └── ResetPasswordPage.jsx  # Token-based password reset
│   │   ├── components/
│   │   │   ├── DataEntryModal.jsx # Measurements input modal
│   │   │   └── Charts.jsx         # pH and viscosity trend charts
│   │   ├── App.jsx                # Root layout, routing, nav, notifications
│   │   ├── api.js                 # Axios HTTP client for all endpoints
│   │   ├── main.jsx               # React entry point
│   │   ├── index.css              # Tailwind CSS + custom component classes
│   │   ├── pdfReport.js           # jsPDF-based report generator
│   │   └── ingredientDB.js        # ~300 cosmetic ingredient records
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── tailwind.config.js
│   └── postcss.config.js
├── server.js                      # Express backend (~850 lines)
├── package.json                   # Backend dependencies
├── render.yaml                    # Render.com deployment config
├── railway.json                   # Railway deployment config
├── nixpacks.toml                  # Nix build config (for Railway)
├── github_push.ps1                # PowerShell: pushes source to GitHub via API
├── dev.bat                        # Windows: starts dev servers (concurrent)
├── deploy.bat                     # Windows: deploys to Railway
├── start.bat                      # Windows: production build + start
└── .node-version                  # Pins Node.js 20.x
```

---

## 3. Backend — `server.js`

### Framework & Middleware

| Middleware | Purpose |
|---|---|
| `express` | Web framework, routing |
| `cors` | Allow cross-origin requests with credentials |
| `cookie-parser` | Parse HTTP-only JWT cookies |
| `express.json()` | JSON request body parsing |
| `express.static()` | Serve React build + `/uploads` directory |

### Authentication Logic

- **JWT tokens** are issued on login and stored in **HTTP-only cookies** (7-day expiry, `SameSite=strict`).
- All `/api` routes (except `/api/auth/`) require a valid token via an `authenticate` middleware.
- Passwords are hashed with **bcryptjs** (10 salt rounds) and never stored in plaintext.
- **Rate limiting** on the login endpoint: max 10 attempts per IP per 15 minutes (custom in-memory map).
- Default admin user (`admin` / `Admin@123`) is seeded on first run if no users exist.

### Password Reset Flow

1. User submits email via `/api/auth/forgot-password`.
2. Server generates a 32-byte random hex token, stores it with a 1-hour expiry in the `password_resets` collection.
3. **Nodemailer** sends a reset link to the user's email address.
4. User clicks link → `ResetPasswordPage.jsx` → `POST /api/auth/reset-password` validates the token and updates the password.
5. Admins can also generate reset links directly from the Admin Panel via `POST /api/admin/users/:id/reset-link`.

### MongoDB Collections & Schema

| Collection | Key Fields |
|---|---|
| `samples` | `_id` (auto-increment int), `name`, `ref_no`, `date_started`, `status`, `temp_config`, `spec_ph_min/max`, `spec_visc_min/max` |
| `results` | `sample_id`, `time_point` (`Initial`/`2_weeks`/`1_month`/`2_months`/`3_months`), pH/viscosity/SG/turbidity per temperature, appearance, notes |
| `images` | `sample_id`, `url`, `filename`, `caption`, `public_id` (Cloudinary) |
| `formulations` | `product_name`, `ref_no`, `ingredients[]`, `procedure[]`, `specifications[]`, `company_*`, `logo_url`, `linked_sample_id` |
| `users` | `username`, `email`, `password_hash`, `role` (`admin`/`user`), `status`, `last_login` |
| `password_resets` | `user_id`, `token`, `expires_at` |
| `audit_log` | `user_id`, `action`, `details`, `timestamp` |
| `counters` | Auto-increment tracking per collection |

All numeric IDs use a `counters` collection pattern — a `findOneAndUpdate` with `$inc` generates the next integer `_id`. API responses map `_id` → `id`.

### API Endpoints

**Auth**
- `POST /api/auth/login` — Validates credentials, sets JWT cookie
- `GET /api/auth/me` — Returns current user from token
- `POST /api/auth/logout` — Clears JWT cookie
- `POST /api/auth/forgot-password` — Sends reset email
- `POST /api/auth/reset-password` — Consumes reset token, updates password
- `PUT /api/auth/password` — Change password while authenticated

**Users (admin only)**
- `GET /api/users`
- `POST /api/users`
- `PUT /api/users/:id`
- `DELETE /api/users/:id`
- `POST /api/admin/users/:id/reset-link`
- `GET /api/audit-log`

**Samples**
- `GET /api/samples` — List, searchable by `name`/`ref_no`
- `GET /api/samples/:id` — Full detail with results and images
- `POST /api/samples` — Create (auto-increments `_id`)
- `PUT /api/samples/:id` — Update metadata
- `PATCH /api/samples/:id/status` — Status transition
- `POST /api/samples/:id/duplicate` — Deep clone sample + results
- `DELETE /api/samples/:id` — Cascade delete results + images

**Results**
- `POST /api/samples/:id/results` — Upsert result by `time_point`
- `DELETE /api/results/:id`

**Images**
- `POST /api/samples/:id/images` — Upload via Multer (JPEG/PNG/GIF/WEBP/PDF, max 20 MB)
- `PUT /api/images/:id` — Update caption
- `DELETE /api/images/:id`

**Formulations**
- `GET /api/formulations`
- `POST /api/formulations`
- `PUT /api/formulations/:id`
- `DELETE /api/formulations/:id`
- `POST /api/formulations/:id/logo`
- `POST /api/formulations/:id/refimage`

**Backup (admin only)**
- `GET /api/backup/export` — ZIP containing all JSON collections + uploads
- `POST /api/backup/import` — Restore from ZIP or raw JSON (validates admin exists post-import)

### Image Storage Strategy

If all three `CLOUDINARY_*` environment variables are present, images are uploaded to Cloudinary (`formulabhub/` folder). Otherwise files are stored on disk in the `uploads/` directory using a random hex filename generated by Multer's `diskStorage`.

### Scheduled Email Reminders (node-cron)

- Cron schedule: `0 8 * * *` (8:00 AM server time, daily)
- Queries all active samples and computes expected measurement dates per time point (Initial=0d, 2 weeks=14d, 1 month=30d, 2 months=60d, 3 months=90d from `date_started`).
- Determines which time points have no result yet and are overdue (past due date) or due within 3 days.
- Sends one HTML email per active user (with a stored email address) summarising pending actions.
- Overdue items are highlighted in red in the email HTML template.

### Audit Logging

Every significant action (login, logout, login failure, user CRUD, password changes, backup restore) writes a record to the `audit_log` collection. The Admin Panel displays the last 200 entries with colour-coded action badges.

---

## 4. Frontend — React 18 + Vite

### Routing (`react-router-dom` v6)

| Path | Component | Notes |
|---|---|---|
| `/` | `Dashboard.jsx` | Requires auth |
| `/samples/:id` | `SampleDetail.jsx` | Requires auth |
| `/formulations` | `Formulations.jsx` | Requires auth |
| `/formulations/:id` | `FormulationSheet.jsx` | Requires auth |
| `/compare` | `ComparisonPage.jsx` | Requires auth |
| `/admin` | `AdminPanel.jsx` | Requires admin role |
| `/reset-password` | `ResetPasswordPage.jsx` | Public (no nav bar) |
| *(unauthenticated)* | `LoginPage.jsx` | Shown when no valid session |

### `App.jsx` — Global State & Notification System

- Calls `GET /api/auth/me` on load to restore session.
- Calculates alerts from all sample dates on every Dashboard render: iterates all active samples, computes expected time-point dates, flags those with no result as overdue (days < 0, red) or due-soon (0–7 days, amber).
- Notification bell badge updates reactively; clicking an alert navigates to that sample.

### Dashboard (`Dashboard.jsx`)

- Fetches and lists all samples.
- Each card shows: name, ref_no, status badge, progress bar (X/5 time points completed), and overdue/due-soon indicators.
- Inline actions: View, Duplicate, Delete (with confirmation).
- "+ New Sample" button opens a creation modal pre-filled with today's date.

### Sample Detail (`SampleDetail.jsx`)

- Full editable header: name, ref_no, date_started, remarks, status, spec limits (pH min/max, viscosity min/max).
- Temperature configuration panel: toggles for 25°C (always shown), 45°C, and 50°C, with per-temp N/A toggles per time point stored in `temp_config` JSON.
- Large results matrix: rows = time points, columns = measurements per temperature.
  - Cells colour-coded: grey for N/A, red if out of spec, green if within spec, white otherwise.
  - Click a cell to open `DataEntryModal.jsx` for inline editing.
- Organoleptic section: appearance, colour observation, odour, phase separation, microbial testing.
- Trend charts: `Charts.jsx` renders `<LineChart>` from Recharts for pH and viscosity over time.
- Image gallery: drag-and-drop or click-to-upload; supports captions; delete with confirmation.
- PDF export calls `generatePDF(sample)` from `pdfReport.js`.

### Formulation Sheet (`FormulationSheet.jsx`)

- Editable ingredient table with autocomplete powered by `ingredientDB.js`.
  - `searchIngredients(query)` searches by trade name and auto-populates INCI name, CAS number.
  - Columns: Part, Trade Name, Description, INCI, CAS, %, Bulk, Supplier, Function, Compliance.
  - Column reordering via drag handles.
- **QS Mode:** When enabled, calculates the "Quantity Sufficient" ingredient's percentage as `100 − sum(all other percentages)`.
- Bulk quantity: auto-calculated from `percent × bulk_size / 100`.
- Procedure steps and specifications are editable ordered lists.
- Company header (name, address, tel, fax) + logo upload + reference image upload.
- PDF export calls `generateFormulationPDF(formulation)` from `pdfReport.js`.

### Comparison Page (`ComparisonPage.jsx`)

- Multi-select of up to 6 samples.
- Renders separate `<LineChart>` for pH and viscosity per temperature.
- Each sample/temperature combination is plotted as a distinct coloured line.

### Admin Panel (`AdminPanel.jsx`)

- **User Management:** List, create, edit (role/status/password), delete, generate reset links, change own password.
- **Audit Log:** Last 200 entries with timestamp, username, action, and details.
- **Backup:** Export downloads a ZIP; import accepts ZIP or JSON file.

### HTTP Client (`api.js`)

- Single `axios` instance with `baseURL: '/api'` and `withCredentials: true`.
- All API calls are wrapped in named export functions (e.g., `getSamples()`, `createResult()`, `exportBackup()`).
- In development, Vite proxies `/api` → `http://localhost:3001`.

### PDF Generation (`pdfReport.js`)

- **`generatePDF(sample)`** — Stability test report
  - Landscape A4, generated with `jsPDF` + `jspdf-autotable`.
  - Header row: sample info.
  - Body: measurement table with time points × temperatures.
  - Cell fill colours: grey (N/A), red (out of spec), green (in spec).
  - Footer: generated timestamp.

- **`generateFormulationPDF(formulation)`** — Formulation sheet
  - Portrait A4.
  - Company header with embedded logo (base64).
  - Ingredients table with percent, bulk quantity, INCI, CAS.
  - Procedure and specifications sections.
  - Legal disclaimer footer.

### Ingredient Database (`ingredientDB.js`)

- ~300+ cosmetic raw materials covering: Water/Solvents, Humectants, Fatty Alcohols, Fatty Acids, Waxes, Esters/Emollients, Silicones, Thickeners, Preservatives, Actives, etc.
- Each record: `{ trade_name, inci, cas, supplier, function }`.
- `searchIngredients(query)` performs a case-insensitive substring match on `trade_name`.

### Styling

- **Tailwind CSS** v3 with a custom `brand` colour palette (blue, 50–900 scale).
- Custom utility classes defined in `index.css`: `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.card`, `.input`, `.label`.
- Print media query hides `.no-print` elements for clean PDF printing.

---

## 5. Libraries & Commands Reference

### Backend (`package.json`)

| Package | Version | Purpose |
|---|---|---|
| `express` | 4.18.2 | HTTP server & routing |
| `mongodb` | 6.21.0 | MongoDB driver |
| `bcryptjs` | 2.4.3 | Password hashing |
| `jsonwebtoken` | 9.0.2 | JWT sign/verify |
| `nodemailer` | 6.9.13 | SMTP email sending |
| `cloudinary` | 2.10.0 | Cloud image storage |
| `multer` | 1.4.5-lts.1 | Multipart file upload |
| `archiver` | 6.0.1 | ZIP creation for backup export |
| `adm-zip` | 0.5.10 | ZIP parsing for backup import |
| `node-cron` | 3.0.3 | Cron scheduler (daily reminders) |
| `cors` | 2.8.5 | CORS middleware |
| `cookie-parser` | 1.4.6 | Cookie parsing |
| `concurrently` | 8.2.2 | Run frontend + backend dev servers together |

### Frontend (`client/package.json`)

| Package | Version | Purpose |
|---|---|---|
| `react` | 18.2.0 | UI library |
| `react-dom` | 18.2.0 | DOM renderer |
| `react-router-dom` | 6.22.1 | Client-side routing |
| `axios` | 1.6.7 | HTTP client |
| `recharts` | 2.12.2 | SVG chart library |
| `jspdf` | 2.5.1 | PDF generation |
| `jspdf-autotable` | 3.8.2 | Table plugin for jsPDF |
| `tailwindcss` | 3.4.1 | Utility-first CSS |
| `vite` | 5.1.4 | Dev server & bundler |
| `postcss` | 8.4.35 | CSS processing |
| `autoprefixer` | 10.4.18 | CSS vendor prefixes |

### Key Commands

```bash
# Development (runs both servers concurrently)
npm run dev
# Equivalent: concurrently "node server.js" "vite --host" (from client/)

# Production build
npm run build --prefix client    # Vite builds React → client/dist/
node server.js                   # Serves API + static build

# Windows convenience scripts
dev.bat        # Installs deps + starts dev servers
start.bat      # Builds frontend + starts production server
deploy.bat     # Railway deployment (prompts for API token)
```

---

## 6. Environment Variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `MONGODB_URI` | Yes | `mongodb://localhost:27017/formulabhub` | MongoDB connection |
| `JWT_SECRET` | Yes | `stab-mgr-jwt-secret-change-in-prod` | JWT signing key |
| `SMTP_HOST` | Yes | `smtp.gmail.com` | SMTP server |
| `SMTP_PORT` | Yes | `587` | SMTP port |
| `SMTP_USER` | Yes | — | Email account username |
| `SMTP_PASS` | Yes | — | Email account password |
| `SMTP_FROM` | Yes | — | Sender address in emails |
| `SMTP_SECURE` | No | `false` | Use TLS (true for port 465) |
| `CLOUDINARY_CLOUD_NAME` | No | — | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | No | — | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | No | — | Cloudinary API secret |
| `APP_URL` | No | Derived from request | Base URL for reset links |
| `PORT` | No | `3001` | Server listen port |

---

## 7. Deployment Configurations

### Render (`render.yaml`)
- Runtime: Node.js
- Build: `npm install --include=dev && npm install --prefix client --include=dev && npm run build --prefix client`
- Start: `node server.js`
- Environment variables synced via Render dashboard

### Railway (`railway.json`)
- Builder: Nixpacks (config in `nixpacks.toml`)
- Start: `node server.js`
- Health check: `GET /api/samples` (30 s timeout, 3 retries)

### Nixpacks (`nixpacks.toml`)
- Node.js 20
- Install: `npm install && npm install --prefix client`
- Build: `npm run build --prefix client`
- Start: `node server.js`

### GitHub Push (`github_push.ps1`)
- PowerShell script that creates a GitHub repo and uploads source files via the GitHub REST API.
- Does not require `git` CLI to be installed.
- Dynamically includes built `client/dist/` files.

---

## 8. Security Notes

- JWT stored in **HTTP-only** cookies — not accessible via JavaScript.
- `SameSite=strict` on cookies — prevents CSRF.
- Login rate-limited: 10 attempts / 15 min / IP (in-memory map, resets on server restart).
- Password reset tokens: 32-byte cryptographically random hex, 1-hour TTL.
- bcryptjs with 10 rounds for all stored passwords.
- Role-based route protection: admin-only endpoints return `403` for non-admin users.
- All user actions written to `audit_log`.
- `.env` and `uploads/` are gitignored.

---

## 9. Stability Testing Domain Logic

- **Time Points:** Initial (day 0), 2 Weeks (day 14), 1 Month (day 30), 2 Months (day 60), 3 Months (day 90).
- **Temperatures:** 25°C (ambient/reference, always tracked), 45°C (accelerated), 50°C (stress). Initial measurements are N/A for 45°C and 50°C by convention.
- **Measurements per condition:** pH, Viscosity, Spindle, RPM, Specific Gravity (SG), Turbidity.
- **Organoleptics:** Appearance, Colour observation, Odour, Phase separation, Microbial.
- **Spec Limits:** Samples can optionally have min/max bounds on pH and viscosity. Cells render red if out of range, green if within range.
- **Progress:** Calculated as count of time points with at least one result / 5 total time points.
- **Duplication:** Cloning a sample copies all metadata and all existing results into new documents.
- **Email Alerts:** Lookahead of 3 days; anything past due date with no result is flagged as overdue.
