# Eye-SaaS HMS — Tablet App (`eye_care_tab`) — Master PRD

> **Companion app to:** `eye_care_app` (phone-optimized Flutter app, already built)
> **This app:** Universal tablet app (Android tablets, all screen variants + iPad) for the **same** Eye-SaaS HMS product.
> **Backend:** Same Laravel API — `J:\laragon\www\eye-saas-hms` — **zero backend changes required**. Slug-based multi-tenant auth, identical endpoints.
> **Status legend:** `☐ Not started` · `◐ In progress` · `☑ Done` · `⏸ Deferred`
> **How to use this doc:** Each phase below is a self-contained work packet. Assign a phase, mark status inline, and this file stays the single source of truth for progress.

---

## Table of Contents

1. [Purpose & Ground Rules](#1-purpose--ground-rules)
2. [Code Reuse Strategy](#2-code-reuse-strategy)
3. [Design System](#3-design-system)
4. [Navigation Architecture](#4-navigation-architecture)
5. [Screen Pattern Matrix](#5-screen-pattern-matrix)
6. [Full Feature Inventory (source of truth)](#6-full-feature-inventory-source-of-truth)
7. [Phase-Wise Roadmap](#7-phase-wise-roadmap)
8. [Master Tracking Table](#8-master-tracking-table)
9. [Non-Functional Requirements](#9-non-functional-requirements)
10. [Out of Scope / Deferred](#10-out-of-scope--deferred)
11. [Open Risks & Decisions Log](#11-open-risks--decisions-log)

---

## 1. Purpose & Ground Rules

- `eye_care_app` (`J:\all_folder_of_C_drive\eye_care_whole\eye_care_app`) is the **feature source of truth**. Every screen, service, model, and permission that exists there must eventually exist in `eye_care_tab`, unless explicitly deferred (see §10).
- `eye_care_tab` is a **separate, independent Flutter project** — not a shared package, not a responsive breakpoint bolted onto the phone app. Own codebase, own release cycle.
- **Brand identity is locked**: same colors, same fonts, same corner-radius/shadow language as `eye_care_app`. A user switching from phone to tablet should recognize the product instantly — only density and layout adapt, not the visual language.
- **Tablet-only**: no phone breakpoint required (phone is already served by `eye_care_app`). Target width range ≈ 600dp (small Android tablet / iPad mini portrait) to ≈ 1366dp (large iPad Pro / Android tablet landscape).
- **Orientation**: landscape is the primary/designed-for orientation; portrait must remain fully usable (nav rail collapses, layouts reflow to single/stacked column where a 2-pane split no longer fits).
- No coding starts until a phase below is explicitly assigned.

---

## 2. Code Reuse Strategy

Verified by reading actual `eye_care_app` source: every file in `config/`, `constants/`, `models/`, `services/`, `utils/` uses **relative imports** (`../config/app_config.dart` style, not `package:eye_care_app/...`). This means these layers are **portable byte-for-byte** — copy the file, it compiles and behaves identically in `eye_care_tab`, because it talks to the exact same backend.

| Layer | Reuse approach | Risk |
|---|---|---|
| `lib/config/` (app_config.dart, client_theme.dart) | Copy as-is | None — same API base URL / slug logic |
| `lib/constants/` (colors, spacing, radius, text styles, permissions) | Copy as-is, **extend** spacing/radius with tablet-specific tokens (additive only, never edit existing values) | None |
| `lib/models/` (all `*_models.dart`) | Copy as-is | None — same JSON shape from same API |
| `lib/services/` (all `*_service.dart`, incl. `base_service.dart`, `cache_service.dart`, `permission_service.dart`) | Copy as-is | None — same endpoints, same token/session handling |
| `lib/utils/` (app_route.dart, phone_rules.dart, app_dialogs.dart, etc.) | Copy as-is, review `circular_reveal_route.dart` — may swap for tablet-appropriate transitions | Low |
| `lib/theme/app_theme.dart` | Copy as base, **extend** (not replace) with `NavigationRailThemeData`, `DataTableThemeData` tablet additions | Low |
| `lib/screens/` | **Rebuild per-screen** for tablet layout patterns (§5). Business logic (state, API calls, validation) ports directly; only the `build()` widget tree changes. | This is the actual work |
| `lib/widgets/` | Mix: some reusable as-is (badges, skeletons, stat cards), some need tablet variants (nav is the big one — no bottom nav / drawer, replaced by rail + split-view) | Medium |

**Net effect:** ~110 files of business logic (models+services+config+constants+utils) are a mechanical copy. The real engineering is the ~45 screens + a handful of new tablet-specific shell/layout widgets.

---

## 3. Design System

Reused verbatim from `eye_care_app/lib/constants/`:

| Token source | Values |
|---|---|
| **Primary** | `#1B4F72` (theme-overridable per-tenant via `ClientTheme`/`applyTheme()` — white-label support already exists, must be preserved) |
| **Secondary** | `#2E86C1` |
| **Background** | `#EBF5FB` |
| **Semantic** | green `#27AE60`, orange `#E67E22`, red `#DC3545`/`#C0392B`, teal `#1ABC9C`, purple `#8E44AD` |
| **Wait-time pills** | green `#16A34A` (≤30min) / orange `#EA580C` (30-60min) / red `#DC2626` (60-120min) |
| **Radius** | xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 28 · full 100 |
| **Spacing** | xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 |
| **Text styles** | headingLarge/Medium/Small, sectionLabel, bodyLarge/Medium/Small, labelMedium/Small, statNumber, cardTitle/Subtitle |

**New tablet-only additive tokens** (do not touch mobile file, define fresh in `eye_care_tab`):

```
AppSpacing (tablet additions):
  railWidthCollapsed = 76
  railWidthExpanded  = 240
  paneGapMin         = 24    // gap between master & detail pane
  pagePaddingWide    = EdgeInsets.symmetric(horizontal: 32, vertical: 24)

Breakpoints:
  compact  : < 720dp   → single column, rail collapsed to icon strip
  medium   : 720–1100dp → 2-pane split (list ~360dp fixed + detail flex)
  expanded : > 1100dp  → 2-pane split with wider detail, or 3-pane where applicable (e.g. Patients: list | detail | quick-actions)
```

Typography stays the same font family/weights — only container widths/columns change, never the type scale (per user requirement: "looks like mobile app case, end of the day its for same use but different device").

---

## 4. Navigation Architecture

**Shell replaces:** mobile's `bottom nav (5 items) + hamburger drawer (accordion sections)` combo — a phone pattern that doesn't belong on a tablet.

**Tablet shell = persistent `NavigationRail`**, mirroring the *combined* set of items currently split across mobile's bottom-nav + drawer:

```
┌───────────┬─────────────────────────────────────────┐
│           │                                          │
│  [Logo]   │                                          │
│           │                                          │
│  Home     │            Content Area                  │
│  Patients │      (single-pane OR list|detail split    │
│  Queue    │       depending on screen — see §5)       │
│  Reports  │                                          │
│  Medicines│                                          │
│  Masters  │                                          │
│  Users    │                                          │
│  ⋯        │                                          │
│           │                                          │
│  [Profile]│                                          │
│  [Logout] │                                          │
└───────────┴─────────────────────────────────────────┘
```

- **Expanded** (labels + icons) on `expanded` breakpoint, **compact** (icons only, tooltip on hover/long-press) on `medium`, **collapsible drawer-over-content** on `compact`/portrait.
- Rail sections mirror the drawer's permission-gated groups 1:1 (source: `app_drawer.dart` + `home_screen.dart`) — **all permission checks (`PermissionService.instance.can(...)`) port unchanged**:

| Rail Group | Items | Gate (from `Perm`) |
|---|---|---|
| Top-level | Dashboard | always |
| OPD | Patients, Share History | `opdPatientView` |
| OPD | FOC Requests | `opdFocCreate` \|\| `opdFocAccept` |
| Clinical | Queue Dashboard | `opdExamPrimary` \|\| `opdExamSecondary` |
| Department Hub (OT) | OT Bookings, Accountant/Billing, Ward Mgmt, Doctor Dashboard, Assistant Dashboard, Discharge & Invoices | various `ot.*` (⏸ see §10 — mobile itself has these as "Coming Soon" stubs) |
| Reports | Reports | `reportsView` (hidden for doctor role) |
| Medicines | Medicines, Medicine Types, Medicine Categories, Route of Admin, Dosages, Medicine Groups | `masterMedicines` |
| Config | Masters, Settings, Roles & Permissions, Users | `masterCaseTypes`/`masterEyeExam`/`masterLocations`, `settingsHospital`, `masterRoles`, `masterDoctors`/`masterReceptions`/`masterOtStaff` |
| Footer | My Profile, Logout | always (Profile hidden for hospital_admin, same as mobile) |

- **Doctor role** gets `DoctorDashboardScreen` as Home (same branch logic as `home_screen.dart` line `_isDoctorUser`), Reports hidden.
- **Silent session refresh** on resume (`AuthService.refreshSession()` + permission re-check) ports as-is from `home_screen.dart`.
- **Platform Super Admin** gets its own separate rail item-set entirely (own login flow, no tenant slug) — built in Phase 12 (done 2026-07-27).

---

## 5. Screen Pattern Matrix

| Pattern | Definition | Screens |
|---|---|---|
| **A — List + Detail split** | Master list (fixed ~360dp) left, detail/form pane right; selecting a row updates the right pane without route push | Patients, Masters (generic_master_screen), Users, Roles, Medicines + all medicine sub-masters, Share History, Case Types, Locations, Referrers, OT Slots/Charges/Surgery Types |
| **B — Grid/Card dashboard** | Stat cards + charts in responsive grid, no split | Dashboard (admin), Doctor Dashboard |
| **C — Multi-column data-entry form** | 2-column field grid instead of mobile's stacked single column | Primary Exam, Secondary Exam (all sections visible, no accordion — confirmed decision), Patient Form, Patient Check-in, User Form, Settings, Profile |
| **D — Table-first list** | Real `DataTable`/`PaginatedDataTable` instead of mobile's card-list | Reports, Patients (table view within the list pane of pattern A), Users list |
| **E — Full-bleed utility** | Splash, Login (centered card on branded background — tablet has room for a proper split-screen login: branding left, form right) | Splash, Login |
| **F — Document/preview** | PDF preview + print/share, mostly unchanged from mobile since it's already a document viewer | Prescription Print, OPD Bill |
| **G — Timeline/history** | Chronological record view, can use 2-column card grid instead of mobile's vertical list | Patient History, Clinical Queue (queue is real-time list — stays list-like but wider with more columns of info per row) |

---

## 6. Full Feature Inventory (source of truth)

Extracted directly from current `eye_care_app/lib/` (verified by directory listing, not from stale notes).

### 6.1 Services (35) → all Phase 0 copy, zero UI work
`auth_service · base_service · cache_service · case_type_service · clinical_queue_service · dashboard_service · doctor_dashboard_service · exam_masters_service · exam_service · foc_service · location_service · masters_service · medicine_service · ot_charge_head_service · ot_slot_service · ot_surgery_type_service · patient_history_service · patient_service · permission_service · prescription_service · profile_service · referrer_service · report_service · roles_service · settings_service · share_history_service · simple_master_service · user_service` — plus **Platform** (☑ Phase 12): `platform_audit_log_service · platform_auth_service · platform_dashboard_service · platform_location_master_service · platform_medicine_master_service · platform_notification_service · platform_payment_service · platform_plan_service · platform_profile_service · platform_settings_service · platform_subscription_service · platform_tenant_service`

### 6.2 Models (18) → Phase 0 copy
`auth_models · clinical_queue_models · dashboard_models · doctor_dashboard_models · foc_models · medicine_models · patient_history_models · patient_models · report_models · role_models · share_history_models` — plus **Platform** (☑ Phase 12): `platform_admin_models · platform_audit_log_models · platform_dashboard_models · platform_location_master_models · platform_medicine_master_models · platform_notification_models · platform_payment_models · platform_plan_models · platform_settings_models · platform_subscription_models · platform_tenant_models`

### 6.3 Screens (45) — mapped to phases below
Hospital-side (31): `splash · login · home(→ tablet shell) · dashboard · doctor_dashboard · patients · patient_form · patient_checkin · patient_history · clinical_queue · primary_exam · secondary_exam · masters · generic_master · case_type_master · location_master · referrer_master · ot_slot_master · ot_charge_head_master · ot_surgery_type_master · medicines · medicine_group_detail · medicine_group_form · users · user_form · roles · foc · reports · share_history · settings · profile · prescription_print · opd_bill`

Platform (14, ☑ Phase 12 — done 2026-07-27): `platform_login · platform_home · platform_dashboard · platform_hospitals · platform_hospital_detail · platform_hospital_form · platform_plans · platform_billing · platform_location_master · platform_medicine_master · platform_notifications · platform_audit_logs · platform_settings · platform_profile`

---

## 7. Phase-Wise Roadmap

### Phase 0 — Foundation & Logic Layer
**Goal:** eye_care_tab compiles, runs, has all business logic, zero screens.
- Copy `pubspec.yaml` deps (http, shared_preferences, google_fonts, path_provider, open_filex, image_picker, fl_chart, pdf, printing)
- Copy `config/`, `constants/`, `models/`, `services/`, `utils/` wholesale
- Copy `theme/app_theme.dart` as base; add tablet breakpoint/rail tokens
- `flutter pub get` + `flutter analyze` clean
**Depends on:** nothing. **Status:** ☑ Done

### Phase 1 — Auth & App Shell
**Goal:** Splash → Login → tablet shell (NavigationRail) → empty Dashboard placeholder, permission-gated rail items working.
- Splash screen (Pattern E)
- Login screen — split-screen branding+form (Pattern E), reuses `auth_service` + hospital slug discovery
- Tablet shell widget (new): `TabletScaffold` with NavigationRail, breakpoint-aware collapse, session refresh on resume
**Depends on:** Phase 0. **Status:** ☑ Done

### Phase 2 — Dashboard
**Goal:** Admin dashboard + Doctor dashboard, Pattern B (stat grid + charts, `fl_chart` reused).
**Depends on:** Phase 1. **Status:** ☑ Done (no `fl_chart` usage yet — dashboard API has no time-series data, only today/month/year snapshots; revisit if/when backend adds trend endpoints)

### Phase 3 — Patients Module
**Goal:** Patients list+detail (Pattern A+D), Patient Form, Check-in, Patient History (Pattern G).
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-24 — `flutter analyze` clean throughout.
- Patients list+detail split (search, stat chips, Today/All toggle, pagination, delete)
- Patient Form embedded in detail pane (add walk-in/phone/edit, 2-column Pattern C, contact-suggestion lookup, add-city dialog)
- Patient Check-in as a dialog (not a full route — short discrete action), full field parity with mobile
- Patient History embedded in detail pane (Pattern G): status badge, info grid, clinical timeline with expandable exam cards (refraction/O-E/fundus tables ported verbatim), partner-hospital history sections
- Stubs carried forward at the time (all since resolved): Primary/Secondary Exam (done in Phase 4), Print Bill / Print Rx / Check-in's post-submit bill print (done in Phase 11)

### Phase 4 — Clinical Queue + Exam
**Goal:** Queue Dashboard (Pattern G, wide row layout), Primary Exam + Secondary Exam (Pattern C — 2-column grid, all sections visible, no accordion).
**Depends on:** Phase 3 (patient context). **Status:** ◐ In progress
- **4a — Clinical Queue: ☑ Done 2026-07-24.** `flutter analyze` clean. Rebuilt as 3 simultaneous columns (Primary / Dilation / Secondary) on wide layouts instead of mobile's tab-switch — the single biggest tablet-specific win in this phase, since reception/doctors see the whole queue at once. Falls back to tabs under the medium breakpoint. Doctor-assignment strip, wait-pill thresholds, live dilation countdown all ported unchanged.
- **4b — Primary Exam: ☑ Done 2026-07-24.** `flutter analyze` clean. Built per `EXAMINATIONS_MODULE_PRD.md`: shared widgets (`widgets/exam/anchored_popover.dart`, `master_list_popover.dart`, `sign_grid_popover.dart`, `exam_field_widgets.dart`) + `primary_exam_screen.dart` — 2-column grid, all 9 sections visible (no accordion), per-section Save buttons (locked decision), anchored-popover pickers for SPH/CYL + Axis/VN/Vision/NCT/O-E/Fundus. Full-screen route (rail hidden) pushed from Clinical Queue's "Start Primary" and Patients detail pane's "Primary Exam" button. One deliberate correction vs mobile: K/C/O+H/O card now saves `history` together with `kco_rows` (mobile's step-1 save only sent `kco_rows`, silently depending on the C/O step having already persisted history — noted in code comment).
- **4c — Secondary Exam: ☑ Done 2026-07-24.** `flutter analyze` clean. Reuses all of 4b's shared widgets/exam/* pickers + adds Diagnosis (fav-sorted multi-select pill grid), Medicine/Rx (group batch-loader + live medicine-name autocomplete), Advice (favourite quick-add pills + searchable "More" dialog with inline create-new) — all per-section save, matching 4b. Primary-exam prefill-fallback banner shown when no Secondary record exists yet. Dilation-lock cross-cutting rule (`widgets/exam/dilation_lock.dart`) now wired into both Clinical Queue's and Patients' "Start/Open Secondary" entry points — confirms via dialog before opening if the patient is still within its dilation window.
- Clinical Queue's "Start Primary"/"Start Secondary" buttons and the Patients detail pane's Exam buttons are wired to a "not built yet" stub until 4b/4c land — intentionally, not silently dropped.

### Phase 5 — Masters Module
**Goal:** Masters hub + generic_master_screen (Pattern A) covering: Case Types, Locations, Referrers, OT Slots, OT Charge Heads, OT Surgery Types, and all `masters/detail/{type}` eye-exam masters (22 types).
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-24. `flutter analyze` clean (0 errors). Hub (`masters_screen.dart`) is list+detail: left pane groups master types (Basic/OT/Eye Exam, permission-gated same as mobile), right pane embeds the selected type's editor. `generic_master_screen.dart` covers all ~26 simple {value, favourite, seeded} masters in one reusable screen. 6 custom-field masters built individually (Case Types name+fee, Locations read-only, Referrers name+contact, OT Slots name+times, OT Charge Heads name+%+active, OT Surgery Types type-dropdown+name) — add/edit via dialog rather than mobile's bottom sheet (forms are 1-3 fields, don't need a 3rd pane). Durations/Lens Options/OT Types fall through to the generic handler (`masters/detail/{slug}`), same as mobile.

### Phase 6 — Medicines Module
**Goal:** Medicines, Medicine Groups (list+detail+form), Medicine Types/Categories/Routes/Dosages — all Pattern A.
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-24. `flutter analyze` clean (0 new errors/warnings — only pre-existing info-lints elsewhere in the project). Single `medicines_screen.dart` hub with a top TabBar (6 tabs: Dosages/Med. Types/Categories/Route of Admin./Medicines/Med. Groups) — deliberately a flat TabBar rather than Masters' left-nav-list, since Medicines only has 6 sibling areas vs Masters' 20+ grouped items. Dosages/Types/Categories/Routes share one generic `_SimpleMedMasterTab` (grid list + add/edit via dialog + delete-confirm, matching Phase 5's dialog convention). Medicines catalog tab: search+debounce+pagination+dialog form (type/dosage dropdowns, duration/qty/company/composition/price). Medicine Groups tab: Pattern A list+detail — left list of groups, right an always-editable repeater-form pane (header fields + per-row medicine/dosage/duration/route/qty, medicine-select auto-fills dosage+duration via `MedGroupFormData.autoFillFor`). Deliberate consolidation vs mobile: mobile's separate `medicine_group_detail_screen.dart` (read-only view) is folded into the same form pane here — one surface serves both view and edit, since the detail pane already has room for the full form. All six Medicines rail entries (`medicines`, `medicine_groups`, `medicine_types`, `medicine_categories`, `route_admin`, `dosages`) wired in `tablet_shell.dart` to open `MedicinesScreen(initialTab: ...)` using the same `MedicinesTab` index constants mobile uses, landing directly on the relevant tab.

### Phase 7 — Reports
**Goal:** Reports screen, Pattern D (real DataTable), filter panel, Excel/PDF export (reuses `report_service` download logic).
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-27. `flutter analyze` clean (0 new errors/warnings). `reports_screen.dart`: left `_FilterPanel` (320dp fixed) + right content column (green collection banner, then a card with header row/DataTable/pagination). Deliberate tablet win vs mobile: the filter panel stays permanently open on wide layouts instead of mobile's expand/collapse accordion — falls back to a collapsible header (same `isOpen` toggle mobile uses) only when stacked under the medium breakpoint. Patient list rendered as a real `DataTable` (Code/Name/Date/Age/Type/Doctor/Case Type/Receptionist/Location/Fee columns, horizontally + vertically scrollable) instead of mobile's card list — the actual Pattern D payoff, since tablet width fits every column without truncation. All business logic (filter/apply/clear/date-range picker/export/pagination) ported unchanged from `ReportService`/`ReportFilter`. Wired to the existing `reports` rail entry in `tablet_shell.dart`.

### Phase 8 — Users, Roles & Permissions
**Goal:** Users list+form (Pattern A/C), Roles & Permissions management (Pattern A — role list left, permission-matrix editor right, which tablet width handles far better than mobile ever could).
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-27. `flutter analyze` clean (0 new errors/warnings). `users_screen.dart` — Pattern A list+detail (search + paginated list left, selected user's profile or `user_form_pane.dart` right). `user_form_pane.dart` — embeddable 2-column Pattern C form (Basic Info / Role & Status / Security / conditional Doctor Details with image upload), ported unchanged from mobile's `user_form_screen.dart`; role picker is a centered search dialog instead of mobile's bottom sheet, matching the tablet dialog convention from Phases 5–6. `roles_screen.dart` — Pattern A list+detail; the actual tablet payoff is the permission editor: instead of mobile's `ExpansionTile` accordion (tap to expand each module one at a time), every module renders as an always-open card in a responsive 2-column grid, each with its own granted-count badge and All/None toggle — the whole permission set is visible and editable at a glance. Wired to the existing `users` and `roles` rail entries in `tablet_shell.dart`.

### Phase 9 — FOC (Free of Charge)
**Goal:** FOC list + create + accept/reject flow, Pattern A.
**Depends on:** Phase 3. **Status:** ☑ Done 2026-07-27. `flutter analyze` clean (0 new errors/warnings). `foc_screen.dart` — Pattern A list+detail. Deliberate tablet split vs mobile's inline-action card list: the list pane stays scannable (patient, fee, status badge only) while the detail pane on the right shows the full record (reason, requested-by, rejection note or accepted-by/at) plus the Accept/Reject buttons, so actions live in one consistent place instead of being crammed into every card. Create-request and Reject dialogs ported unchanged (small 1–3 field forms — a dialog remains the right call here, not an embedded pane). Wired to the existing `foc` rail entry in `tablet_shell.dart`.

### Phase 10 — Settings, Profile, Share History
**Goal:** Settings (hospital config, logo upload, password change, location cascade), Profile, Share History (Pattern A).
**Depends on:** Phase 1. **Status:** ☑ Done 2026-07-27. `flutter analyze` clean (0 new errors/warnings). `settings_screen.dart` — single scrollable form with a persistent header row (logo + Save button) replacing mobile's AppBar+footer sandwich; 2-column field pairs within each section card; location cascade + timezone use a search dialog instead of a bottom sheet; wait thresholds render as 3 side-by-side R/D/ND groups on wide layouts instead of stacked — the whole picture visible at once. `profile_screen.dart` — centered max-width form (personal settings don't need full rail width), Change Password as a dialog. Fixed a latent bug while porting: mobile's `ProfileService.updateProfile` always sends `name`/`email` in its payload, so the tablet's separate password-change dialog passes through the server-confirmed `profile.name`/`profile.email` rather than empty strings, to avoid silently blanking the account on a password-only change. `share_history_screen.dart` — top TabBar (3 tabs, matches Medicines' flat-area convention); both tabs' lists render as a real `DataTable` (Pattern D) instead of mobile's card stacks; filters sit in a persistent horizontal bar instead of an expand/collapse card; Requests tab cards flow into a 2-column `Wrap` on wide layouts. Added `widgets/app_error_state.dart` (was missing from the Phase 0 copy) since these screens are the first tablet screens to need it. Wired to the existing `settings`/`profile`/`share_history` rail entries in `tablet_shell.dart`.

### Phase 11 — Prescription Print & Billing Docs
**Goal:** Prescription PDF preview/print/share, OPD Bill screen — Pattern F, reuses `pdf`/`printing` packages as-is.
**Depends on:** Phase 4. **Status:** ☑ Done 2026-07-27. `flutter analyze` clean (0 new errors/warnings). `prescription_print_screen.dart` — unchanged from mobile (`PdfPreview` already centers/scales cleanly on wide screens; no tablet-specific layout needed). `opd_bill_screen.dart` — same PDF generation, only change is centering the receipt card at a fixed max width (560dp, matching its A5 proportions) instead of stretching it edge-to-edge. Wired all three real entry points that were stubbed since Phase 3/4: Patients detail pane's "Print Bill" → `OpdBillScreen`; Patient History's "Print Rx" → `PrescriptionPrintScreen` (using the already-fetched `ExamHistoryData.patient` summary); Check-in's `onDone` callback now pushes `OpdBillScreen` with the updated patient instead of showing a "lands in a later phase" snackbar.
- **Note for a future phase:** `doctor_dashboard_screen.dart`'s "Examine" and "History" quick-action buttons on the primary/secondary queue cards still show generic "not built yet" snackbars referencing Phase 3/4 — those phases are done now (Primary/Secondary Exam, Patient History all exist) but the doctor dashboard was never updated to wire them in. Not in scope for Phase 11; flagging so it isn't missed before release.

### Phase 12 — Platform Super Admin Module
**Goal:** Full second app-within-app for platform/tenant management — own login, own rail, 14 screens (§6.3).
**Depends on:** Phase 1 shell pattern proven out. **Status:** ☑ Done 2026-07-27 — deferral lifted, all 14 screens built, `flutter analyze` clean (0 errors, same 23 pre-existing info-level lints as before Platform work began).
- **12a — Foundation, Login, Shell, Dashboard.** All 11 platform models + 12 platform services + `widgets/status_badge.dart` copied verbatim (pure Dart/relative imports, no refactor needed — mirrors the Phase 0 hospital-side copy). Entry point ported exactly as mobile has it: a **hidden 5-tap-in-2s gesture on the login screen's logo** (not a visible button/link — platform access is deliberately not discoverable from the hospital-staff login) pushes `platform_login_screen.dart`, a tablet split-layout (branding left / form right, reusing `LoginScreen`'s visual language) rebuild of mobile's single-card login. On success it opens `platform_shell.dart` — a new, independent NavigationRail shell mirroring `TabletShell`'s `_TabletRail` pattern (own private rail implementation, not shared, since `PlatformAdmin` auth has nothing in common with hospital `UserInfo`/`HospitalInfo` and there's no permission-gating: every super admin sees every destination, matching mobile's own ungated drawer). Rail groups: Dashboard · Tenants (Hospitals, Billing) · Oversight (Audit Logs, Notifications) · Platform Masters (Plans, Location Master, Medicine Master) · System (Settings) + a footer Profile tile/Logout. `platform_dashboard_screen.dart` — Pattern B, 2-column on wide (stat grid + fl_chart revenue/registrations charts left, subscription-cycles + recent-hospitals right) vs mobile's single scrolling column — business logic and charts ported unchanged.
- **12b — Hospitals module.** `platform_hospitals_screen.dart` — Pattern A list+detail consolidating mobile's 3 separate screens (list/detail/form) into one hub. `_HospitalDetailPane` fetches full tenant detail and exposes quick actions (Activate/Suspend/Reactivate/Extend Grace/Re-seed Masters/Archive), each behind a confirm dialog. `platform_hospital_form_screen.dart` — embeddable Pattern C form (create vs edit field differences preserved). Also exposed a public `PlatformHospitalDetailRoute` wrapper (its own `_editMode` state) so Billing can deep-link into a hospital's detail pane cross-screen. Copied `app_pagination_bar.dart`/`app_search_bar.dart` verbatim (needed here, unused until now).
- **12c — Plans & Billing.** `platform_plans_screen.dart` (embedded list + `_EditPlanDialog`) and `platform_billing_screen.dart` (segmented Payments/Subscriptions tabs, `_RecordPaymentDialog`, subscription cards deep-link to `PlatformHospitalDetailRoute`) — mobile's bottom-sheet/draggable-sheet forms converted to `Dialog`, the established tablet convention since Phase 5.
- **12d — Location & Medicine Masters.** `platform_location_master_screen.dart` (TabBar: Countries/States/Districts/Cities, cascading filters preserved) and `platform_medicine_master_screen.dart` (TabBar: Dosages/Types/Categories/Routes/Medicines, shared generic `_SimpleMasterTabState` base class for the 4 simple masters, `_MedicineFormDialog` for the one complex one).
- **12e — Audit Logs, Notifications, Settings, Profile.** `platform_audit_logs_screen.dart` — persistent left filter panel (300dp: action/hospital/date-range) replacing mobile's filter bottom sheet, matching the Reports screen's established convention. `platform_notifications_screen.dart` — segmented Compose/History tabs, History uses a responsive 1–2 col `GridView` instead of mobile's single list. `platform_settings_screen.dart` — persistent header-row Save button (matches hospital-side Settings), masked-secret fields that only submit if retyped. `platform_profile_screen.dart` — centered max-width form matching hospital-side Profile screen's convention.
- **Post-completion audit (2026-07-27):** a full mechanical diff of `lib/screens`, `lib/services`, `lib/models`, `lib/widgets`, `lib/utils`, `lib/constants`, `pubspec.yaml`, and `assets/` against mobile found exactly one real gap — the `widgets/skeleton.dart` shimmer-loading widget had never been ported, so several existing tablet screens were using a plain `CircularProgressIndicator` instead of mobile's skeleton placeholders. Fixed by porting `skeleton.dart` and wiring `AppSkeletonList`/skeleton boxes into the affected screens (now used across both hospital-side and Platform screens). Everything else (services, models, permissions, dependencies, assets) was already 100% at parity — confirmed no other silent gaps between mobile and tablet.
- **Second, deeper parity audit (2026-07-28):** filename/directory diffs only prove a screen *exists*, not that it does the same things — so this pass extracted every `XxxService.instance.method(` call site from every mobile screen and diffed it against its tablet counterpart (45 screens, all mapped through the file-consolidation rules above), plus a byte-for-byte diff of every copied `services/`, `models/`, `constants/`, `utils/` file, `pubspec.yaml` deps, `assets/`, and `main.dart`. Two real gaps found and fixed:
  - `referrer_master_screen.dart` never called `MastersService.instance.clearCache()` after create/update/delete, unlike mobile — meaning an edited/added/deleted referrer wouldn't show up in the Patient Form's referrer dropdown (which reads from `MastersService`'s cache) until the cache expired or the app restarted. Fixed by adding the same `clearCache()` calls mobile has, in the same two spots.
  - `main.dart` never called `SystemChrome.setSystemUIOverlayStyle` (transparent status bar, light icons) the way mobile's does. Fixed by porting the same call.
  - Everything else flagged by the mechanical diff turned out to be a false positive on closer inspection (verified, not just assumed): dead/unused code in mobile itself (`_MedicineSearchField` defined-but-unused in `primary_exam_screen.dart` — the real, used copy is in `secondary_exam_screen.dart` and matches on both sides), mobile's own line-wrapped method calls that a naive regex missed, and mobile's medicine-master tabs passing service methods as callback tear-offs (`onCreate: MedicineService.instance.createDosage`) rather than direct calls — all confirmed present and wired correctly on the tablet side after manual inspection. All 35 services and 18 models copied in Phase 0/12a are still byte-identical to mobile — zero drift since copy.

### Phase 13 — Polish, QA, Release Prep
**Goal:** Orientation-change stress test (rotate mid-flow on every screen), tablet-size matrix testing (7" / 8" / 10" / 12.9" + Android split-screen/multi-window), performance pass (list virtualization, image caching), app icons/splash assets for tablet, store listing assets.
**Depends on:** Phases 1–11. **Status:** ◐ Partial — code-level polish done 2026-07-27, `flutter analyze` clean; the rest of this phase is manual device/asset work outside what static code changes can verify or produce (see breakdown below).
- **Code-level polish (done):**
  - Fixed a real gap found during the sweep: `doctor_dashboard_screen.dart`'s "Examine" and "History" queue-row actions were still stubbed with "not built yet" snackbars from Phase 2, even though Primary/Secondary Exam and Patient History have existed since Phase 4. Wired them to push the real screens — `PrimaryExamScreen`/`SecondaryExamScreen` (with the dilation-lock check for Secondary, matching Patients' own entry point) and a new `PatientHistoryRoute` full-screen wrapper. Queue-row DTOs (`PrimaryPatient`/`SecondaryPatient`) don't carry a full `Patient`, so a minimal one is constructed from them — verified safe by auditing every field the exam screens actually read off `widget.patient` (`id`, `doctor?.id`, `fullName`, `patientCode` only).
  - Extracted the full-screen "view patient history from outside the Patients pane" wrapper (previously private to `share_history_screen.dart`) into a shared `lib/screens/patient_history_route.dart` (`PatientHistoryRoute`), now reused by both Share History and the Doctor Dashboard fix above instead of being duplicated.
  - Orientation audit: `main.dart` already restricts to `landscapeLeft`/`landscapeRight`/`portraitUp` (portraitUp allowed, upside-down excluded) — matches the Phase 0 locked decision, no lock/bug found.
  - Performance audit: every data-heavy list in the app (Patients, Users, Masters, Medicines, Roles, FOC, Reports/Share-History `DataTable`s) already uses `ListView.builder`/`.separated` or server-side pagination — no unvirtualized long lists found. One small popover list (`master_list_popover.dart`) uses a plain `ListView` to interleave Favourites/All section headers with items, but master lists are small (dozens, not thousands) so this isn't a real performance issue.
  - Rail-stub sweep: the only rail entries still hitting `ComingSoonPane` are the 6 OT (Operation Theatre) workflow screens (`ot_bookings`, `ot_billing`, `ot_ward`, `ot_doctor`, `ot_assistant`, `ot_discharge`). Confirmed this is **not a tablet gap** — mobile itself has never built these either (`dashboard_screen.dart`'s "OT Booking" quick action calls its own `_comingSoon()`); only the OT *masters* (Slot/Charge Head/Surgery Type) exist in mobile and were already ported in Phase 5. Nothing to port here yet.
- **Outside what I can do from here (needs the user):** physical/emulator device rotation testing across the actual tablet-size matrix (7"–12.9") and Android split-screen/multi-window — this sandbox has no device or screenshot tooling available (see Phase 1's note); app icon and splash-screen image assets — design deliverables, not something to fabricate; store listing copy/screenshots — marketing content requiring the actual visual product.

> **OT operational workflow note** (Bookings/Ward/Surgery Record/Lens/Discharge beyond the masters): in `eye_care_app` itself these are still "Coming Soon" stubs (drawer items exist, screens don't) and backend `OtApiController` returns `501`. Tablet will **mirror mobile's current state exactly** — rail items present but stubbed — until mobile ships them first. Not a tablet-specific gap.

---

## 8. Master Tracking Table

| # | Phase | Modules | Status | Assigned To | Notes |
|---|---|---|---|---|---|
| 0 | Foundation & Logic Layer | config/constants/models/services/utils | ☑ | | Done 2026-07-24. `flutter analyze` clean (0 errors). Platform-admin models/services intentionally skipped, added in Phase 12. |
| 1 | Auth & App Shell | Splash, Login, TabletScaffold+Rail | ☑ | | Done 2026-07-24. `flutter analyze` clean. Visual/UI not verified in this environment (no browser/screenshot tooling available) — please run `flutter run -d windows` and confirm it looks right. |
| 2 | Dashboard | Admin Dashboard, Doctor Dashboard | ☑ | | Done 2026-07-24. `flutter analyze` clean. Doctor dashboard's secondary-exam dilation-lock override UI simplified to a placeholder tap until Phase 4 (Exam screens) exists — restore full lock/override behavior then. Quick actions route via rail `onNavigate`, not `Navigator.push`. |
| 3 | Patients | List, Form, Check-in, History | ☑ | | Done |
| 4 | Clinical Queue + Exam | Queue, Primary Exam, Secondary Exam | ☑ | | Done — 4a Queue, 4b Primary Exam, 4c Secondary Exam all complete |
| 5 | Masters | Case Types, Locations, Referrers, OT masters, Eye-exam masters | ☑ | | Done |
| 6 | Medicines | Medicines, Groups, Types, Categories, Routes, Dosages | ☑ | | Done — single tabbed hub, Groups detail folded into always-editable form pane |
| 7 | Reports | Reports + export | ☑ | | Done — persistent filter panel + real DataTable (Pattern D) |
| 8 | Users, Roles & Permissions | Users, Roles | ☑ | | Done — permission editor is always-open module grid, not accordion |
| 9 | FOC | FOC list/create/accept | ☑ | | Done — list stays scannable, actions/full record moved to detail pane |
| 10 | Settings, Profile, Share History | Settings, Profile, Share History | ☑ | | Done — DataTable share history, side-by-side wait thresholds, fixed a password-change-blanks-name/email edge case |
| 11 | Prescription & Billing Docs | Prescription print, OPD Bill | ☑ | | Done — also wired the Print Bill/Print Rx/Check-in stubs left since Phase 3/4 |
| 12 | Platform Super Admin | 14 platform screens | ☑ | | Done 2026-07-27 — all 14 screens built; post-completion audit found and fixed one gap (skeleton-loading widget) |
| 13 | Polish & Release | QA matrix, performance, assets | ◐ | | Code-level polish done (fixed doctor-dashboard stubs, audited orientation/perf/stubs); device testing + design assets need the user |

---

## 9. Non-Functional Requirements

- **Performance:** list virtualization for Patients/Reports/Masters tables (`ListView.builder`/`DataTable` with pagination, never render full dataset), image caching for profile photos/logos reused from mobile's approach.
- **Offline resilience:** `CacheService` (SharedPreferences-backed) ports as-is — dashboard/patients/masters cached-then-refresh pattern from mobile stays identical.
- **Multi-tenant white-labeling:** `ClientTheme`/`AppColors.applyTheme()` dynamic color override (set at login per-tenant) **must be preserved** — tablet is not exempt from white-label support.
- **Accessibility:** rail items need tooltips in collapsed state; touch targets ≥ 44dp even though tablet has more room (not phone-cramped, but still touch-first, not mouse-first).
- **Orientation:** every screen must be verified in both orientations, not just designed for landscape and "hoped" to work in portrait.
- **Device matrix:** Android tablets (7"–12"+, various aspect ratios) + iPad (mini/Air/Pro, all with iPadOS multitasking/Split View potential — layouts must not assume full-width).

---

## 10. Out of Scope / Deferred

- ~~Platform Super Admin module — Phase 12, explicitly deferred until core Hospital-side phases (1–11) are done.~~ Deferral lifted 2026-07-27 — completed same day, all 14 screens, see §7 Phase 12.
- **Full OT surgical workflow** (Bookings/Ward/Surgery Record/Lens/Discharge/Billing beyond static masters) — not yet built in `eye_care_app` either; tablet mirrors that gap, will pick it up alongside or after mobile.
- **Dark mode** — mobile doesn't support it (web doesn't either), so tablet skips it for parity, same as mobile's own PRD precedent.
- **Phone breakpoint inside eye_care_tab** — not needed, `eye_care_app` already owns phone.

---

## 11. Open Risks & Decisions Log

| Date | Decision | Rationale |
|---|---|---|
| 2026-07-24 | Independent codebase, not a shared package | User: keep it simple, reuse only where it doesn't cost performance/maintainability; logic layer is safely copy-able since imports are relative and backend is identical |
| 2026-07-24 | Side nav rail + master-detail over bottom-nav-scaled-up | Tablet screen real estate demands it; matches Apple HIG (iPad sidebar/split-view) and Material 3 adaptive guidance |
| 2026-07-24 | Landscape primary, portrait supported (not locked) | Clinic staff may hand-hold tablet occasionally, not purely desk-mounted |
| 2026-07-24 | Exam screens: 2-column grid, all sections visible, no accordion | Biggest single UX win over mobile — doctors want full context without scrolling/expanding during live exams |
| 2026-07-24 | Platform Super Admin deferred to Phase 12 | Prioritize core hospital-staff daily-use flows first |
| — | Same colors/fonts/radius as mobile, only spacing/layout adapts | User: "end of the day its for same use but for different device" — brand continuity across devices |

---

*This document is the tracking source for `eye_care_tab`. Update the status column in §8 as work progresses. No implementation begins on a phase until it's explicitly assigned.*
