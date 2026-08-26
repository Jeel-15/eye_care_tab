# Examinations Module — Tablet PRD (Phase 4b/4c)

> **Companion to:** `EYE_CARE_TAB_PRD.md` (master tracking doc) — this file is the deep-dive for Primary + Secondary Exam only, because those two screens are bigger and denser than everything else in the app combined.
> **Ground truth verified against:** current `eye_care_app` source — not just the mobile team's own historical planning docs (`EXAM_SECTIONS_PRD.md`, `EXAM_SECTIONS_PRD_STEPS_10_12.md`), which describe an earlier, partially-unbuilt state. Where those docs list a "gap," this PRD says explicitly whether the current code has since closed it.
> **Do not start coding from this doc alone** — it documents what exists and proposes a tablet layout; the layout proposal and the open decisions in §8 need your sign-off first.

---

## 1. Why This Needed Its Own Document

Every other tablet screen so far (Dashboard, Patients, Clinical Queue) was a rebuild of a few hundred to ~1,500 mobile lines. Primary Exam is **2,443 lines**, Secondary Exam is **3,035 lines** — and they're not verbose, they're *dense*: 9–12 clinical data-entry sections, each with its own bespoke picker widget (sign-toggle grids, searchable master-data sheets, live-calculated fields, inline conditional sub-forms). Porting that correctly requires understanding the *whole* data model and interaction pattern first, not section-by-section guessing.

---

## 2. Source Files Read (ground truth)

| File | Lines | Role |
|---|---|---|
| `eye_care_app/lib/screens/primary_exam_screen.dart` | 2,443 | Full source, read in full |
| `eye_care_app/lib/screens/secondary_exam_screen.dart` | 3,035 | Full source, read in full |
| `eye_care_app/lib/services/exam_service.dart` | 145 | Load/save API calls, `ExamFormData` |
| `eye_care_app/lib/services/exam_masters_service.dart` | 384 | 22-master fetch/cache, `ExamMastersData` |
| `eye_care_app/lib/models/medicine_models.dart` (partial) | — | `MedItem`, `MedMasterItem`, `MedGroup` shapes |
| `eye_care_app/EXAM_SECTIONS_PRD.md` | 791 | Mobile team's own historical spec — sections 1–8 (C/O → Fundus). **Cross-checked against current code; almost all listed "gaps" are now closed.** |
| `eye_care_app/EXAM_SECTIONS_PRD_STEPS_10_12.md` | 350 | Mobile team's own historical spec — sections 10–12 (Diagnosis/Medicine/Advice, secondary-only). **Mostly closed; two gaps remain open — see §7.10–7.11.** |
| `patients_screen.dart`, `doctor_dashboard_screen.dart` (relevant excerpts) | — | Dilation-lock/override cross-cutting behavior |

---

## 3. Shared Data Model

Both screens write to the **same `exam_data` JSON shape** (Primary writes a subset; Secondary writes everything Primary does *plus* Diagnosis/Medicine/Advice). This is the single source of truth for every field in both screens:

```jsonc
{
  "exam_data": {
    "history": "Diabetes, Hypertension",              // H/O — comma-joined string
    "co_rows": [{ "complaint": "", "since": "", "unit": "Days", "eye": "", "comment": "" }],
    "kco_rows": [{ "condition": "", "since": "", "unit": "Years", "comment": "" }],
    "vision": { "vn_re": "", "vn_le": "", "pnvn_re": "", "pnvn_le": "", "nrvn_re": "", "nrvn_le": "" },
    "pg": {
      "re": { "ds": "", "dc": "", "ax": "", "vn": "", "ns": "", "nc": "", "na": "", "near_vn": "" },
      "le": { /* same 8 keys */ }
    },
    "st": {
      "re": { "ds": "", "dc": "", "ax": "", "vn": "", "add": "", "ns": "", "nc": "", "na": "" },
      "le": { /* same 8 keys */ },
      "bifocal": false, "nd_separate": false, "progressive": false, "computer_uses": false
    },
    "nct": { "iop_re": "", "iop_le": "" },
    "oe": {
      "sac_re": "", "sac_le": "", "lid_re": "", "lid_le": "", "conj_re": "", "conj_le": "",
      "cornea_re": "", "cornea_le": "", "ac_re": "", "ac_le": "", "iris_re": "", "iris_le": "",
      "pupil_re": "", "pupil_le": "", "lens_re": "", "lens_le": "", "em_re": "", "em_le": "",
      "covertest_re": "", "covertest_le": "", "other_re": "", "other_le": "",
      "pseudophakia_re": { "operation_type": "Phaco", "operation_expense": "", "hospital_name": "" },
      "pseudophakia_le": { /* same 3 keys */ }
    },
    "fundus": { "disc_re": "", "disc_le": "", "fr_re": "", "fr_le": "", "comment_re": "", "comment_le": "" },
    "dilate": "No",

    // ── Secondary-only ──────────────────────────────────────────────
    "diagnoses": [12, 47],                              // array of diagnosis master IDs
    "advice": "",                                        // free text, max 2000
    "followup_date": "2026-08-15",                        // implemented on mobile; NOT in current web UI (mobile is ahead here)
    "followup_duration": "6 weeks",
    "special_advice": ""
  },
  "doctor_id": 5,
  "dilation_time": 40,                                   // top-level, only when step=Dilate and dilate="Yes"
  "medicines": [                                          // top-level (Secondary only), NOT inside exam_data
    { "medicine_id": 15, "name": "...", "dosage_id": 3, "route_id": 2, "duration": "7", "quantity": 1 }
  ]
}
```

**Critical backend behavior:** saving is **per-step partial-merge**, not whole-form. `POST /exams/primary/{id}` and `POST /exams/secondary/{id}` each accept `{ doctor_id, exam_data: {...only this step's keys...} }`, and the backend does `array_merge(existing, new)` — sending Vision doesn't wipe PG, ST, etc. This is *why* mobile has a separate "Save {step}" button per step. **This matters directly for the tablet layout decision in §8.**

---

## 4. API Contract

| Endpoint | Method | Notes |
|---|---|---|
| `GET /exams/primary/{patientId}` | — | Returns `null` data if no primary exam exists yet |
| `POST /exams/primary/{patientId}` | `{doctor_id, exam_data, dilation_time?}` | Per-step partial merge |
| `GET /exams/secondary/{patientId}` | — | Returns `null` if none exists |
| `POST /exams/secondary/{patientId}` | `{doctor_id, exam_data, dilation_time?, medicines?}` | Per-step partial merge; `medicines` only sent on Medicine step |
| `GET /masters/detail/{type}` | — | 22 types, fetched in parallel, response `{id, value, is_favourite}` |
| `POST /masters/detail/{type}/{id}/toggle-favourite` | — | Returns new `is_favourite` |
| `POST /masters/detail/advices` | `{value}` | Create new advice master item inline (Advice step only) |
| `GET /medicine-groups?per_page=200` | — | For the Medicine step's group batch-loader |
| `GET /medicines?search=&per_page=20` | — | Medicine name autocomplete |

**Secondary-specific business rule — prefill fallback:** if no Secondary exam exists yet, Secondary Exam screen loads and **prefills from the Primary exam** instead (same `exam_data` shape works for both), and shows an informational banner ("Data pre-filled from Primary Exam") so the doctor knows they're looking at carried-over data, not a blank form. `_prefillSource` tracks `'none' | 'primary' | 'secondary'`.

**22 master types** (all fetched in parallel on screen open, 30-min in-memory cache + disk cache so re-opening is instant): `vn, pnvn, nrvn, nct, sph_cyl, axis, sac, lid, conj, cornea, ac, iris, pupil, lens(→lens_master), em, covertest, disc, fr, chief-complaints(→complaints), kcos, hno, diagnoses, advices`.

---

## 5. Cross-Cutting Business Rule: Dilation Lock

This affects **when the Secondary Exam screen is even reachable**, so it has to be designed alongside the screen itself, not bolted on after:

1. Primary Exam's Dilate step: doctor sets `dilate = Yes/No` + `dilation_time` (minutes, default 40).
2. If `dilate = Yes`: patient enters a **timed lock** — `unlock_time_ms = primary_done_at + dilation_time`. Backend returns this on the patient/queue records.
3. While locked, mobile's "Start Secondary" button is **replaced by a live countdown** (`_DilationTimer`, ticks every second) — tapping does nothing.
4. **Double-tap override**: mobile lets staff double-tap the locked button to force-open Secondary Exam early, via a confirmation dialog ("X is currently dilating. Override and examine now?").
5. Once unlocked (naturally or via override), the button becomes the normal "Start Secondary" / examine action.

This exists today in mobile's `patients_screen.dart` (`_DilationTimer` + `_ActionBtn`) and `doctor_dashboard_screen.dart` (`_secondaryActionBtn` + `_showOverrideDialog`). **Tablet's Clinical Queue and Patients screens currently have this stubbed to a flat "not built yet" snackbar** (Phase 4a/3) — when 4b/4c land, this lock/override logic needs to be restored on both entry points, not just inside the exam screen itself.

---

## 6. Master-Data Picker Patterns (used throughout)

Every section leans on 3–4 reusable interaction patterns. Get these right once as shared tablet widgets and every section composes from them — this is the leverage point that keeps 4b/4c from being 5,000 lines of one-off code.

| Pattern | Where used | Mobile implementation | Tablet redesign direction |
|---|---|---|---|
| **Favourite chip row** | C/O, K/C/O, H/O | Amber pills above a search field, tap-to-add, ★ to unfavourite | Same concept, sits inline in the section card — no reason to change |
| **Sign-toggle grid picker** (SPH/CYL) | PG, ST distance & near | Full-screen `Dialog.fullscreen` with −/+ tabs, 8-col grid, Custom+Apply, Clear | **Becomes an inline popover/anchored dropdown** — tablet has room to show the grid next to the field instead of taking over the whole screen |
| **Searchable master list sheet** | Vision, Axis, VN, NCT, O/E (10 fields), Fundus (Disc/FR), Advice "More" | `showModalBottomSheet` / `DraggableScrollableSheet`, search bar + Favourites/All split + ☆ toggle | **Becomes an inline dropdown/popover anchored to the field** — bottom sheets are a phone pattern; tablet has cursor-precision and screen space for a proper anchored menu |
| **Multi-select pill grid** | Diagnosis | `Wrap` of toggle pills with search, fav-first sort, ☆ toggle, selected-count badge | Same concept, just gets more horizontal room |
| **Readonly mirror field** | ST near CYL/Axis (`nc`=`dc`, `na`=`ax`) | Greyed, non-interactive, "= Distance" sub-label | Same — it's a display-only derived value, not a UX pattern needing rethinking |
| **Conditional inline sub-form** | O/E LENS → Pseudophakia panel | Expands below the LENS row when value contains "Pseudophakia" | Same concept; with all sections visible at once on tablet, this just expands in place without disrupting anything else on screen |

---

## 7. Section-by-Section Spec

Each section below: mobile behavior (verified current, not aspirational) → tablet treatment.

### 7.1 C/O — Chief Complaints
Repeatable rows: complaint (autocomplete from `complaints` master) · since (0–10 or blank) · unit (Days/Weeks/Months/Years/Longtime) · eye (–/RE/LE/Both/OU) · comment · delete. Favourite pills add a row pre-filled. **Tablet:** table-style rows (5 columns fit comfortably at tablet width vs. mobile's cramped 2-row-per-card layout) inside a card; favourites row stays above.

### 7.2 K/C/O & H/O — Known Conditions & History
K/C/O: same row pattern as C/O, no eye column, default unit **Years**. H/O: chip-based (not rows) — search/select from `hno` master, chips join to a single comma string on save. **Tablet:** two side-by-side cards (K/C/O left, H/O right) since they're independent sub-sections that currently force a scroll on mobile.

### 7.3 Vision — Visual Acuity
2 rows (RE/LE) × 3 columns (VN / PnVN / NrVN), each cell free-text + dropdown from respective master. **Tablet:** unchanged structure, just wider — this table already reads fine at any width.

### 7.4 PG — Prescription Glasses
2 rows (DIST/NEAR) × 4 columns (SPH/CYL/Axis/VN) × 2 eyes = one of the two biggest tables. SPH/CYL via sign-grid picker; Axis disabled until CYL is set; VN/near-VN each from their own master. **Tablet:** RE and LE tables side-by-side (currently stacked vertically on mobile — a real tablet win, cuts vertical scroll roughly in half).

### 7.5 ST — Subjective Test
Same shape as PG plus: NEAR row's CYL/Axis are **readonly mirrors** of DIST's (not independently editable), NEAR SPH shows a calculated "ADD: X" hint (`NS = DS + ADD`, live-recalculated), 4 checkboxes below (Bifocal, N&D Separate, Progressive, Computer Use). **Tablet:** same RE/LE-side-by-side treatment as PG.

### 7.6 NCT — Non-Contact Tonometry
Single IOP row × 2 eyes, grid-picker from `nct` master, live color-coded border (green 10–21 / amber 22–24 / red ≥25), static legend below. **Tablet:** unchanged, already compact.

### 7.7 O/E — On Examination
11 rows (10 dropdown fields + free-text "Other") × 2 eyes. Each dropdown field: searchable sheet with Favourites/All split. **LENS field special case:** selecting "Pseudophakia" expands an inline sub-panel (Operation Type Block/Phaco toggle, Expense, Hospital name) per eye. **Tablet:** this is the tallest table (11 rows) — keeping label|RE|LE columns as-is but full tablet width gives each dropdown field room to show its selected value without truncation, which mobile currently fights.

### 7.8 Fundus
2 eye-cards (RE, LE), each: Disc (dropdown+search) · FR (dropdown+search) · Comment (multi-line free text). **Tablet:** RE/LE cards side-by-side instead of stacked.

### 7.9 Dilate
Yes/No choice chips; if Yes, a minutes field (default 40) appears inline. Trivial section, already compact on mobile.

### 7.10 Diagnosis (Secondary only)
Search + multi-select pill grid from `diagnoses` master, fav-first sorted, ☆ toggle per pill, selected-count badge + Clear all. **Current gap (open, confirmed in code):** no linked-groups/linked-advices auto-suggestion when a diagnosis is picked — the historical doc flagged this and it's still true today. **Not required for tablet parity** — mobile doesn't have it either; flag as a shared future enhancement, not a tablet-specific gap.

### 7.11 Medicine / Rx (Secondary only)
Toolbar: "+ Add" blank row, and a **medicine-group batch-loader dropdown** (this one, unlike Diagnosis-linking, **is implemented** — selecting a group from `medGroups` inserts all its items as rows). Each row: medicine name (live search autocomplete against `/medicines?search=`, auto-fills dosage/duration on pick) · dosage dropdown · route dropdown · duration (days) · quantity · delete. **Tablet:** row fields get breathing room; the group-loader dropdown and medicine autocomplete both translate directly (no bottom-sheet involved here even on mobile — already field-inline).

### 7.12 Advice / Follow-up (Secondary only)
Quick-add favourite pills (amber, from `advices` master) → tap appends to textarea (`\n`-joined). "More" button opens searchable all-advices sheet with ☆ toggle + inline "create new advice" dialog. Textarea itself: 2000-char max with live counter. Plus 3 fields the **web doesn't even have yet** (mobile is ahead): follow-up date (picker), follow-up duration (text), special advice (text, 500 max). **Tablet:** Quick-add pills + textarea + follow-up fields as a 2-column layout (pills/quick-add left, textarea+followup right), "More" sheet → becomes the same anchored-popover pattern as §6.

---

## 8. Decisions (locked 2026-07-24)

### 8.1 Save pattern — **per-section Save buttons, kept** (like mobile)
**Decision:** every section card keeps its own "Save {Section}" button, same as mobile — a single "Save Exam" button was considered and rejected.
**Why:** if there were one combined save and the user backs out of the exam mid-way (accidental nav, interruption, app switch) before hitting it, every section they'd already filled in is lost — there's no partial-save safety net. Per-section save means each section is durable the moment its button is tapped, regardless of what happens afterward. This was a direct call-out from the user based on a real failure mode, not a style preference.
**How to apply:** each section card in the tablet layout gets its own "Save {Section}" button (mirroring `_buildStepPayload(step)` per section from mobile), even though all sections are visible simultaneously (no accordion/stepper). More buttons on screen than a single-save design, but that's the accepted tradeoff for data safety.

### 8.2 Picker style — **anchored popover**
Sign-toggle SPH/CYL grids and searchable master-list pickers (Vision/Axis/NCT/O-E/Fundus/Advice-More) open as a **popover anchored to their field**, not a centered dialog or bottom sheet. Matches tablet's precision-input expectations (Apple HIG / Material popover patterns) and keeps the surrounding form visible for context while picking a value.

### 8.3 Build order — **Primary Exam first, then Secondary**
Build the shared section widgets once (C/O, K/C/O, H/O, Vision, PG, ST, NCT, O/E, Fundus, Dilate + the §6 picker patterns), assemble **Primary Exam** from them first to prove the pattern end-to-end, then build **Secondary** as Primary's widgets + the 3 extra sections (Diagnosis, Medicine, Advice) + the prefill-fallback banner + dilation-lock wiring.

---

## 9. Out of Scope for This PRD

- **Diagnosis→linked-groups/linked-advices auto-suggestions** (§7.10, §7.11 gap) — not present in mobile today either; a shared future enhancement across both platforms, not something tablet needs to invent first.
- **Prescription printing** — separate Phase 11 (Prescription Print) in the master PRD.
- **OT-side examination flows** — out of scope entirely (Phase 12+, deferred).

---

*Update this document if the mobile app's exam behavior changes before 4b/4c ships — it should stay a snapshot of current reality, not drift into aspiration like its mobile-team predecessor docs did.*
