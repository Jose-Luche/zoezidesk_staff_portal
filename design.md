# ZoeziDesk Staff — Design spec (Organic, "Shift home")

Source of truth for the staff app's look and flows. Derived from the prototype `Staff App Prototype.dc.html` (direction 1b) and the Organic design system. Replaces the visual rules in `design-system/zoezistaff/MASTER.md` (orange/dark, Barlow); the app structure, permissions and API behaviour stay as they are in code.

---

## 1. Principles

1. **The member at the counter comes first.** Every desk flow ends in "checked in" or "paid" in as few taps as possible, without leaving the current screen (sheets, not pushes).
2. **One home, shaped by role.** Home shows what *this* person must act on now; tabs stay few (max 3 in the bar).
3. **Warm, soft, calm.** Cream ground, terracotta + sage, over-rounded shapes, pills everywhere. No sharp corners, no hairline-only geometry, no grey-washed palettes.
4. **Left-aligned and airy.** Flush-left headings, content hugging the left edge, generous whitespace. Don't crowd the rounded shapes.
5. **The server decides; the UI explains.** Disabled actions say why ("Membership not active — take a payment first").

---

## 2. Tokens

### 2.1 Color

| Role | Token | Hex | Use |
|---|---|---|---|
| Ground | `bg` | `#F5EAD8` | Scaffold, sheets |
| Surface | `surface` | `#EBDDC5` | Cards, inputs, stat tiles |
| Text | `text` | `#201E1D` | Body, headings, dark nav pill, toast |
| Accent (terracotta) | `accent` | `#C67139` | Scan button, selected states, icons, large text |
| Accent 2 (sage) | `accent2` | `#7A8A5E` | Success, classes, "yours", second voice |
| Divider | `divider` | `text @ 16%` | Input / outline borders |

Ramps (100 → 900). Light steps (100–300) are for tinted fills; 500 is the base; 700–900 are for text on tints and pressed states.

| Step | Neutral | Accent | Accent 2 |
|---|---|---|---|
| 100 | `#F9F4ED` | `#FFF2EB` | `#F0FAE1` |
| 200 | `#EEE7DB` | `#FFE1D0` | `#E1EECC` |
| 300 | `#DCD3C4` | `#FFC6A5` | `#CCDBB2` |
| 400 | `#C0B6A5` | `#F6A06B` | `#AEBF92` |
| 500 | `#A19786` | `#D67F48` | `#8FA073` |
| 600 | `#82796A` | `#B2622D` | `#728157` |
| 700 | `#645C50` | `#8C491A` | `#56633F` |
| 800 | `#474238` | `#643312` | `#3D472B` |
| 900 | `#2E2B25` | `#402310` | `#272E1B` |

**Semantic mapping**

| Meaning | Fill | Text / icon |
|---|---|---|
| Success / active / came | `accent2-200` (banner), `accent2-100` (tag) | `accent2-800/900` |
| Warning / ending soon | `accent-100` | `accent-800` |
| Danger / expired / refused | `accent-200` | `accent-900` |
| Neutral / info | `neutral-100` or `surface` | `neutral-800` |
| Muted text | — | `neutral-700` (≥ 4.5:1 on bg and surface) |

**Contrast (keep `contrast_test.dart` green, 4.5:1):**
- `bg` text on `accent` is only **3.0:1**. That's fine for the Scan circle label and other headline-sized (≥ 18 px Caprasimo) text, but **not** for 14–16 px button labels. For standard filled buttons, use **`accent-700` fill + `bg` text (5.7:1)**, or `accent` fill + `text` label (4.6:1). Recommended: `accent-700` for `FilledButton`, with `accent` kept for the Scan circle, selection and icons.
- Sage fills under light text: use `accent2-700` (5.4:1), not `accent2-600` (3.5:1).
- `neutral-600` (3.6:1) is for placeholders/decoration only; never for meaningful text.
- Accent as paragraph text: use `accent-700`.

**Dark theme** (the app supports `themeMode`): ground `neutral-900`, surface `neutral-800`, text `neutral-100`, accent `accent-400`, sage `accent2-400`, tints become `*-800` fills with `*-200` text. Pressed = one step lighter (`accent-300`). Re-run the contrast test on every pair.

### 2.2 Typography

- **Display / headings:** Caprasimo 400 (the only display voice; no condensed or geometric faces).
- **Body / UI:** Figtree 400 / 600 / 700.
- Both are OFL on Google Fonts. Bundle them in `assets/fonts/` in place of Barlow.

| Style | Font | Size / line | Use |
|---|---|---|---|
| `displayLarge` | Caprasimo | 40 / 1.04 | Home greeting ("Morning,\nMary.") |
| `displayMedium` | Caprasimo | 36 / 1.05 | Owner home title (gym name) |
| `headlineLarge` | Caprasimo | 32 / 1.1 | Tab titles (Members, Classes) |
| `headlineMedium` | Caprasimo | 24 / 1.15 | Sheet titles, member name, KPI values |
| `titleLarge` | Caprasimo | 19–21 / 1.2 | Section headings ("Needs you now"), scan result |
| `titleMedium` | Caprasimo | 16–18 / 1.2 | Sub-sections (Plan, Paid by), primary button labels |
| `bodyLarge` | Figtree 600 | 15 / 1.4 | List titles |
| `bodyMedium` | Figtree 400 | 13.5–14 / 1.5 | Body, descriptions |
| `bodySmall` | Figtree 400 | 12–12.5 / 1.4 | Subtitles, helper text (muted) |
| `labelSmall` | Figtree 400 | 11 / 1.2 | Tags, stat captions |
| `labelMedium` | Figtree 600 | 12.5–13 | Chips, segmented, nav |

Headings use letter-spacing −0.015em. Use sentence case everywhere; no all-caps except tiny kickers.

### 2.3 Spacing, radius, elevation

- Spacing scale (density 1.1×): `4.4, 8.8, 13.2, 17.6, 26.4, 35.2`. In practice: 4 / 8 / 12 / 16 / 20–22 / 26 / 36.
- Screen gutters: **22 px** for headings, **16 px** for card stacks, **12 px** for list rows (rows have their own 10 px inner padding).
- Radius: `sm 8`, `md 16`, `lg 28`. Cards and tiles **22–28**, list-row hover **22**, sheets **34 (top corners)**, and **999 (pill)** for every button, input, chip, tag, segmented control and nav bar. Avatars and the Scan button are circles.
- Shadows: `sm 0 1 2 / 14%`, `md 0 3 10 / 16%`, `lg 0 12 32 / 22%`, all tinted `#2E2B25`. Use `lg` for the nav pill, Scan button, sheets and toast, and `sm` for the role switcher. Cards are flat (surface fill, no shadow).

### 2.4 Iconography

Lucide icons at **stroke 2.75**, 16–20 px inline and 36–38 px in the Scan circle. Use `lucide_icons` (or `flutter_lucide`) in place of Material rounded icons. Never use emoji as icons.

### 2.5 Motion

| What | Duration | Curve |
|---|---|---|
| Sheet / scan overlay in and out | 340 ms | `Cubic(0.2, 0.8, 0.2, 1)` |
| Backdrop fade (to 50% `neutral-900`) | 300 ms | ease |
| Selection fills (chips, seg, nav, toggles) | 200 ms | ease |
| Toast in / out | 250 ms, auto-hide 2.4 s | ease |
| M-Pesa waiting pulse | 1.4 s loop, scale 0.6 → 1.6, fade | ease-out |

Respect reduced motion: drop the pulse and make the transitions 0 ms.

---

## 3. Components

| Component | Spec |
|---|---|
| **Primary button** | Pill, height 52–56, Caprasimo 16–18, fill per §2.1 contrast note. Hover/pressed = one ramp step darker. Disabled = 45% opacity. Full width inside sheets. |
| **Secondary button** | Pill, transparent, 1 px `divider` border, `text` label. Hover = text @ 7%, pressed = text @ 14%. |
| **Ghost button** | `accent-700` Figtree 600 text, no border, tinted hover. Used for "+ Add", "See all", "Cancel request". |
| **Scan button** | 138 px circle, `accent` fill, 10 px `accent-200` halo + `shadow-lg`, Lucide `scan-line` 38 px over "Scan" (Caprasimo 18). |
| **Quick action** | Pill, height 46, `surface` fill, 16 px icon + Figtree 600 14 ("Find", "Register"). |
| **Input** | Pill, height 50, `surface` fill, 1 px `divider` border, 18 px horizontal padding, Figtree 15. Focus = 2 px `accent` ring. The label sits above (12 px, `neutral-800`) and helper text below (12 px, muted, 8 px inset). Textarea uses radius 26. |
| **Search field** | Input with a leading `search` icon. Filters from 2 characters (name, phone digits, member number). |
| **Segmented control** | Pill container with a 1 px divider border; equal-width options. Selected = `text` fill + `bg` label (or `accent` for report periods). |
| **Filter / type chips** | Pill, 7 × 14 padding, Figtree 600 12.5. Off = transparent + divider border; on = `text` (filters) or `accent2-700` (note types). |
| **Role switcher** | Pill track in `neutral-100` with `shadow-sm`; segments are 7 × 14 pills, selected = `text` fill. |
| **Tag** | Pill, 3 × 10, 11 px, semantic tint (§2.1). Status tags: plan name (active), "Ends {date}" (ending), "Expired", "No plan". |
| **Avatar** | Circle 42 (lists), 48 (pay header), 60 (scan), 74 (member sheet). Initials in Figtree 700, or Caprasimo at ≥ 60 px. Tone per member: sage / terra / sand tints with 800 text. |
| **Member row** | Avatar 42–44, name (Figtree 600 15), subtitle (`HH:mm · QR/By hand` if in today, else `#number · phone`), trailing status tag. Row radius 22 with a `neutral-100` hover. |
| **Action card ("Needs you now")** | Radius 26, padding 12, tinted by meaning, badge circle 42 (initials / count / time), title + subtitle, optional trailing small pill button (36 high). |
| **Stat tile** | Radius 22–28, `surface`, value in Caprasimo 21–24, caption 11–12 muted. Tappable tiles use the warning tint with a "See who →" link. |
| **Bar chart** | Pill-shaped bars in `accent2-300`, with today's bar in `accent`. Value above and day label below, in a 28-radius surface card. |
| **Radio row (plans)** | Pill row. Selected = 2 px `accent` border + `accent-100` fill, with a dot in `accent` and a 4 px inset ring. Name 600 · duration muted · price 700 on the right. |
| **Switch** | 46 × 28 pill. On = `accent2-600` track; off = `neutral-400`. White-sand knob with `shadow-sm`. |
| **Check toggle (roster)** | 44 px circle. Off = 1.5 px `neutral-400` ring; on = `accent2-600` fill with a check. |
| **Bottom sheet** | Radius 34 top, `bg` fill, sticky drag handle (44 × 5, `neutral-400`), max height 92%, scrollable, backdrop 50% `neutral-900`. Tapping the backdrop or handle closes it. |
| **Bottom nav** | Floating pill 16 px from the edges and 24 px from the bottom. Fill `text`, 6 px padding, `shadow-lg`. Three 46 px pill items; the selected item fills with `accent`, labels in `bg` Figtree 600 13. No icons are needed with three labelled items. |
| **Toast** | Top, centered pill, `text` fill, `bg` text 13.5/600, `shadow-lg`. Replaces SnackBar. |
| **Decoration** | One soft circle (250 px, `accent2-200`) bleeding off the top-right of Home. Don't add more than one per screen. |

Touch targets are ≥ 44 px. Focus is a 2 px `accent` ring with 2 px offset, never the default.

---

## 4. Navigation and roles

Bottom bar: **Home · Members (or "My clients" for trainers who can't browse all members) · Classes**. Everything else (My shift, Follow-ups, Enquiries, PIN, notifications, design gallery) lives under a **More** entry reached from the Home header (avatar or menu button). This stays at 3 tabs instead of 5.

Home adapts to permissions (same logic as `tabsFor`):

| Who | Home variant | Shown when |
|---|---|---|
| Front desk | **Desk** | `checkin.scan` (always on a shared front-desk device) |
| Trainer | **Training** | `members.view_assigned` and not `browseAllMembers` |
| Owner / manager | **Owner** | `reports.view` and not a shared device |

When someone holds more than one role, show the **role switcher** at the top of Home and remember the last choice per user. On the shared front-desk device, only Desk exists, so hide the switcher.

---

## 5. Screens

### 5.1 Home — Desk
1. Greeting: "Morning/Afternoon/Evening, {first name}." (display), then "{n} in so far · busiest at {hour}".
2. Row: **Scan** circle + a column of **Find** (→ Members tab) and **Register** (→ register sheet).
3. **Needs you now** (action cards, in this order):
    - Each member checked in today whose membership is ending or expired: "{first} is in", "{plan} ends {date}", with a **Renew** button (→ pay sheet).
    - Offline queue: "{n} check-ins waiting · Saved offline at {time}", **Send** → "Sending…" → toast "{n} check-ins sent".
    - Refused offline check-ins (danger tint) with **Dismiss**.
    - Full classes today: "{class} with {coach} · full", "{booked}/{cap} booked" → roster.
    - Empty: "All clear. Nothing waiting on you."
4. **Latest in**: the last 3 check-ins, plus "See all {n}".

### 5.2 Home — Training
Greeting, then "{n} clients · {m} in today", followed by:
- **Needs attention**: clients with declining/stalled muscles, or not training for more than 7 days (subtitle e.g. "Legs declining · trained 2d ago"). Rows open the member sheet.
- **Your classes today**: sage cards with the start time in a circle, "{booked}/{cap} booked · {n} ticked off" and "Roster".
- **Your recent notes**: three note cards, each opening its member.

### 5.3 Home — Owner
Gym name, then "{weekday date} · {n} in so far", followed by:
- A 2-column grid of stat tiles: Revenue today (KES), Check-ins today, Active members, Joined this month, then **Expiring in 7 days** and **Lapsed (30 days)** in the warning tint → follow-ups sheet.
- Check-ins for the last 7 days (bar chart).
- Period segmented control (Week / Month / Last month) above a revenue card: total, "{count} payments · {±%} vs the period before", a per-method breakdown with colored dots (M-Pesa sage, Cash terracotta, Bank sand), and an attendance line. Tables and exports stay on the web.

### 5.4 Members / My clients
Headline, a search pill, then filter chips **All · In today · Ending soon · Expired**, then member rows (with no query, people who are in sort first). Empty state: "No match" / "Try part of the name, or the phone number." Trainers only see their assigned clients.

### 5.5 Classes
Headline, then a day switcher (circular chevron buttons with "Today" or "Fri 30 Oct" in the middle), then class cards: time circle, name, "{time} · {coach}", a "{booked}/{cap}" tag (warning tint when full), and a "Yours" sage tag. Tapping a card opens the **roster sheet**.

### 5.6 Scan (full-screen overlay, slides up)
- Camera fills the top; there's a 200 px rounded (44) frame and a 35% scrim outside it. The frame color reflects the last result: sand (idle), sage (ok), neutral (duplicate), terracotta (refused).
- Top bar: close (circle, 16% sand on dark) and "Scan to check in". Torch and camera switch go top-right.
- Bottom panel (radius 34, min height 300) shows the result card. It stays until the next scan, so the next scan can happen right away.

| Result | Card | Title / subtitle | Action |
|---|---|---|---|
| Active | sage-200 | "Welcome, {first}" / "{plan} · until {date} · visit {n}" | — |
| Ending soon | sage-200 | "Welcome, {first}" / "{plan} ends {date} — offer a renewal" | **Renew now** |
| Already in | surface | "{first} is already in" / "Checked in at {time}. Not counted twice." | — |
| Expired / no plan | accent-200 | "{full name}" / "{plan} ended {n} days ago" | **Take payment to let in** |
| Offline, not on list | accent-100 | "Not on the saved list" / "You're offline and this code isn't on the saved member list." | **Let in and record** |

Haptics: medium for success, heavy for refusal (as now). The result is a live region.

### 5.7 Member sheet
Avatar 74, name, "#{number} · {phone}", status tag and "In at {time}" tag. Then two buttons: **Take payment / Renew** (primary) and **Check in** (secondary, which reads "In at {time}" once in; dimmed when the membership isn't active, and tapping it explains why). Below that, three stat tiles: visits this month · active until/ended {date} · joined {month year}.
Only for trainers, managers and owners on their own phone: **Training** ("Last workout {n}d ago · {n} in 4 weeks", plus attention tags) and **Trainer notes** (+ Add, note cards "{type} · {date} · {trainer}"). The desk sees the line "Training and notes are shown to the member's trainer, managers and owners."

### 5.8 Take payment sheet
Header: avatar, "Take payment", "{name} · {status}".
1. **Plan**: radio rows, preselected with the member's last plan.
2. **Paid by**: segmented M-Pesa · Cash · Bank (M-Pesa only if the gym has it enabled; it's the default when on).
3. M-Pesa: phone pill, prefilled, with the helper "A payment request goes to this phone; the member enters their PIN." Cash/Bank: "Amount received (KES)", prefilled with the plan price, plus "Bank reference" for bank and a WhatsApp confirmation switch.
4. Inline error card (warning tint) for validation ("Enter a Safaricom number, like 0712 345 678." / "Enter the amount received.").
5. CTA: "Send KES 4,000 request" or "Record KES 4,000".

States:
- **Waiting** (M-Pesa): pulsing sage phone circle, "Waiting for {first}", "KES {amount} request sent to {phone}. They enter their M-Pesa PIN to finish.", and "Cancel request".
- **Done**: sage check circle with a halo, "KES {amount} received", "{first}'s {plan} membership is active until {date}.", then **Send receipt** (secondary) and **Check in & done** (primary; reads "Done" if they're already in).

When this flow started from Scan, finishing it checks the member in and the scan card switches to "Welcome".

### 5.9 Note sheet
"New note · {first}", then type chips Session · Progress · Health · General. Health shows "Health notes are only seen by trainers, managers and owners." Below that: a textarea (placeholder "What did you work on? What's next?", at least 5 characters, max 1000), then **Save note**. Saving returns to the member sheet and shows the toast "Note saved".

### 5.10 Register sheet
Full name and phone. A **duplicate check runs as they type** (last 9 digits): a warning card reads "{name} has this number" with "#{number} · {status}" and an **Open** button. CTA: **Register & take payment** (→ pay sheet for the new member). Errors: "Enter first and last name." / "Enter a 10-digit phone number." / "That number belongs to someone already…".

### 5.11 Roster sheet
Class name, then "{time} · {coach} · {booked}/{cap} booked". A sage summary pill reads "{n} of {m} ticked off". Rows: avatar, name, then "Came", "In the building since {time}" or "Booked", and a 44 px check toggle. Footer: "+ {n} more booked from the members app". Keep **Book someone** (for walk-ins) and **Cancel booking** from the current app as a pill button and a row menu.

### 5.12 Follow-ups sheet
"Follow-ups" / "Ending in 7 days or lapsed. A reminder goes by WhatsApp." Each row: member, status in `accent-800`, and **Remind**, which turns into a dimmed "Sent" with the toast "Reminder sent to {first}".

### 5.13 Not yet designed (keep the current behaviour, apply the tokens)
Sign-in, front-desk enroll and the PIN lock screen (a name grid of avatars and a pill PIN pad), My shift cash-up, Enquiries, More, and the payment detail/void flow.

---

## 6. Copy

- Plain, short, human. Use first names in feedback ("Brian is checked in").
- Money: "KES 4,000" with a thousands separator; "KES" may be omitted inside the plan list.
- Times are 24 h ("07:42"). Dates are "28 Nov" or "Thu 29 Oct". Relative times: "2d ago", "today".
- Phone numbers use local format: "0712 345 678".
- Put the outcome on the button ("Send KES 4,000 request", "Check in & done"), never "Submit" or "OK".

---

## 7. Flutter mapping

```dart
// lib/core/theme/app_tokens.dart (excerpt)
abstract final class Organic {
  static const bg = Color(0xFFF5EAD8);
  static const surface = Color(0xFFEBDDC5);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFFC67139);
  static const accent100 = Color(0xFFFFF2EB), accent200 = Color(0xFFFFE1D0),
      accent700 = Color(0xFF8C491A), accent800 = Color(0xFF643312), accent900 = Color(0xFF402310);
  static const sage100 = Color(0xFFF0FAE1), sage200 = Color(0xFFE1EECC), sage300 = Color(0xFFCCDBB2),
      sage600 = Color(0xFF728157), sage700 = Color(0xFF56633F), sage800 = Color(0xFF3D472B);
  static const n100 = Color(0xFFF9F4ED), n300 = Color(0xFFDCD3C4), n400 = Color(0xFFC0B6A5),
      n700 = Color(0xFF645C50), n800 = Color(0xFF474238), n900 = Color(0xFF2E2B25);
  static final divider = text.withValues(alpha: .16);
}

abstract final class AppRadius { static const sm = 8.0, md = 16.0, card = 26.0, lg = 28.0, sheet = 34.0, pill = 999.0; }
abstract final class AppMotion {
  static const sheet = Duration(milliseconds: 340), fast = Duration(milliseconds: 200);
  static const curve = Cubic(0.2, 0.8, 0.2, 1);
}
```

ThemeData notes:
- `ColorScheme.light(primary: Organic.accent700, onPrimary: Organic.bg, secondary: Organic.sage700, surface: Organic.bg, surfaceContainer: Organic.surface, onSurface: Organic.text, outline: Organic.divider)`.
- `FilledButton`, `OutlinedButton` and `TextField` (`OutlineInputBorder` with radius 999, filled `surface`) use `StadiumBorder`.
- `CardTheme`: elevation 0, color `surface`, radius 26.
- `BottomSheetTheme`: background `bg`, top radius 34, drag handle `n400`, barrier `n900 @ 50%`.
- `SegmentedButton` / `ChoiceChip`: stadium shape, with selected = `text` fill.
- Replace `NavigationBar` with a custom floating pill (§3).
- Replace SnackBar with an overlay toast at the top (§3).
- Fonts: `fontFamily: 'Figtree'`; display/headline/title styles use `'Caprasimo'`.
