# ZoeziDesk Staff

The Android app for gym staff: the front desk, trainers, managers and owners.
Each person sees what their roles allow, the same as on the web.

- **Front desk** (receptionists, and anyone who can check in): scan member QR codes one
  after another, find a member by name, phone or number, check them in, register new
  members (with a duplicate check) and take payments by cash, bank or M-Pesa. *My shift*
  is the end-of-shift cash-up.
- **Members**: every member for owners, managers and receptionists. Trainers get
  **My clients** instead: their assigned members, who needs attention, training and notes.
- **Classes**: the day's classes; instructors and the front desk see who is booked.
- **Today** (owners and managers): the day's figures and period totals, the same numbers
  as the web reports.

Package `com.zoezidesk.staff`. Backend: the `zoezi_erp` Laravel app; the API is described
in its `STAFF_APP_API.md`.

## Run

```sh
cp env/example.json env/dev.json   # then set API_BASE_URL
flutter run --dart-define-from-file=env/dev.json
```

`env/*.json` (except the example) are gitignored. On the Android emulator the host's
XAMPP is `http://10.0.2.2/...`.

### Notifications

The app is a second Android app (`com.zoezidesk.staff`) in the members app's Firebase
project, `zoezidesk-member`, so the backend's existing `FIREBASE_CREDENTIALS` sends to
both. Fill the `FIREBASE_*` values in `env/dev.json` from that project's
`google-services.json` (the `com.zoezidesk.staff` client): `api_key`, `mobilesdk_app_id`,
`project_number` (sender ID) and `project_id`. Without them the app runs without
notifications.

Only personal sign-ins register for notifications, never the front-desk device. Staff
turn them off under More → App notifications. What is sent, and to whom, is listed in the
backend's `STAFF_APP_API.md` (late class bookings to the trainer, the owners' evening
summary, PIN lockouts).

## Offline check-ins

The front-desk device (and staff who may browse all members) keeps a list of members with
a current membership, refreshed every half hour; QR codes are saved only as hashes. With no
connection, a scan is matched against it and the member is let in; a code that isn't on the
list can still be let in with *Let in and record*. The check-ins wait in the outbox (below;
they survive the device locking) and are sent with the time the member came as soon as the
server answers. The desk shows how many are waiting, and any the server refused once sent.
Signing out on a personal phone sends what it can, then deletes the list and the queue. A
front-desk device deletes them when it stops being the front desk: *Stop using as front desk*
(which warns about unsent check-ins), or as soon as it finds it was removed on the web, so a lost
or retired tablet doesn't keep the gym's member list.

## Saved screens

Screens open with what they showed last time and refresh in the background
(`lib/data/repositories/read_cache.dart`). Each read in `StaffReads` is kept in an
encrypted SQLite database (Drift on SQLite3MultipleCiphers, key in secure storage) as the
server sent it, and parsed the same way as a live answer. Offline, a screen keeps its saved
data with "Offline · updated 5 min ago", and a warning once it is more than a day old.
Searches, payments and plans are never saved. On the front-desk device the saved screens
are shared by everyone who signs in there; on a personal phone they belong to that person
and are deleted when they sign out, as is everything when a phone stops being the front
desk. Rows not refreshed for 14 days are dropped. After changing the tables, run
`dart run build_runner build`.

## Actions done offline

Check-ins, class bookings, cancelling a booking, ticking off who came, and trainer notes go
through an outbox (`lib/data/repositories/outbox.dart`, kinds in
`lib/features/sync/queued_actions.dart`). Each is saved in the encrypted database with an
idempotency key and sent at once; with no connection it stays *pending*, shown on the roster,
the member's notes and Home, and is sent in order, oldest first, when the server answers again:
on every new action, every half minute (backing off from 5 seconds to 5 minutes), and when the
phone's connection comes back (`connectivity_plus`, a hint only). A refusal (4xx) is shown with
the server's reason until dismissed; offline, timeouts, 5xx, 409 and 429 are tried again later.
Only the person who did it (or the desk) sends it. Payments, registering members, converting
enquiries and enquiry follow-ups stay online only; follow-ups can be queued once the backend
adds its idempotency middleware to `POST /staff/leads/{id}/follow-up`.

## Signing in

- **Own phone:** email and password, as on the web. Tokens are short-lived and
  refreshed automatically; the refresh also brings role changes made on the web.
- **Front-desk device:** on the sign-in screen choose *Set up as the front desk device*
  and enter the code a manager shows on the web (Staff → Front Desk Devices → Enrol a
  device). From then on the device shows a lock screen: staff tap their name and enter
  their PIN (set under More → Front-desk PIN, or on the web under Staff App PIN).
  Front-desk work only, whatever the person's roles, and the app locks itself after
  three minutes untouched. Revoking the device on the web signs everyone out of it.

## How it is built

- `lib/core` was copied from the members app (`zoezidesk_member` at commit `14b291e`,
  2026-10-30) and trimmed to what staff need: network (auth and retry interceptors),
  secure storage, theme, errors, formatters. When you fix something there, check
  whether the members app needs the same fix; the files kept their names and places.
- Design tokens follow the web design system, as the members app does: see
  `design-system/zoezistaff/MASTER.md`, `lib/core/theme/app_tokens.dart`, and the
  design gallery (debug builds: More → Design gallery). `test/core/theme/contrast_test.dart`
  checks every text/background pair for 4.5:1.
- Tabs and buttons come from the permissions the server sends at sign-in
  (`lib/core/router/routes.dart`, `tabsFor`). The server checks every request anyway.
- Every write that could be repeated on a bad connection (check-ins, registrations,
  payments, notes) sends a fresh `Idempotency-Key`, so retries never take a payment twice.

## Test

```sh
flutter analyze
flutter test
```

## Build a release

`env/prod.json` holds `API_BASE_URL` (`https://gym.zoezidesk.com/api`: it must be HTTPS) and
the `FIREBASE_*` values (see *Notifications*). Then:

```sh
flutter build apk --release --dart-define-from-file=env/prod.json
```

Raise `version:` in `pubspec.yaml` (both parts, e.g. `1.0.1+2`) for every build you hand out:
Android only installs an update with a higher version code. Share the one universal
`app-release.apk` (not `--split-per-abi` APKs, whose version codes would block later universal
ones), with its SHA-256 checksum so the gym can tell it is yours. Staff get updates only when
you send them a new APK.

### Signing

As in the members app: release builds are signed with the key in `android/key.properties`
(gitignored, as are `*.jks` files), and fall back to the debug key with a Gradle warning when
it's missing. Use a key of its own for this app, made once and kept safe (a password manager
plus an offline backup): every update must be signed with the same key, or staff have to
uninstall the app to install the new one, losing any unsent offline check-ins.

```sh
keytool -genkeypair -v -keystore ~/zoezidesk-staff-upload.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties`:

```properties
storeFile=C:/Users/you/zoezidesk-staff-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Deploying the backend for the app (migrations, roles, scheduler, Firebase) is in the backend's
`STAFF_APP_DEPLOY.md`.

## Not done yet

- Launcher icons: `python tool/make_icons.py` draws them from the logo mark, as in the
  members app (consider a "Staff" variant so the two apps are easy to tell apart).
