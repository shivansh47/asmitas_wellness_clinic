
# AGENTS.md — Diet Cure

Project-level notes for AI agents working in this repo.
Read this first. Update it when you learn something that should outlive a single chat.

---

## 1. Callable Cloud Function — known gotchas

**Function:** `registerWithEmail` in `functions/src/index.ts` (deployed as
`onCall`, callable from Flutter via `cloud_functions: ^6.3.3`).

### Symptom that comes up repeatedly
- A new user is created in Firebase Auth (so `createUserWithEmailAndPassword` works).
- No document appears in `users/{uid}` in Firestore.
- `firebase functions:log --only registerWithEmail` shows:
  - `{"message":"Request body is missing data.", ...}`
  - `{"message":"Callable request verification passed","verifications":{"auth":"MISSING","app":"MISSING"}}`

### Root cause
The call is being made with raw `http.post` directly to the function URL, not
through the Firebase SDK. An `onCall` function requires a specific envelope:

1. The JSON body **must** be wrapped as `{ "data": { ... } }`. The framework
   reads `data` and passes it as the first argument to the handler. Without
   the wrapper, the function logs `Request body is missing data.`
2. The request **must** carry `Authorization: Bearer <firebaseIdToken>`. Without
   it, the function logs `verifications.auth == "MISSING"` and rejects the call.
3. CORS preflight must succeed (the SDK handles this; raw `http.post` from a
   Flutter client typically does not need a manual preflight, but the headers
   above are still required).

### Fix
**Always call `onCall` functions through the Firebase SDK.** Do not use `http.post`
for them. Use:

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

final user = FirebaseAuth.instance.currentUser!;
final idToken = await user.getIdToken(); // ensures fresh token

final result = await FirebaseFunctions.instance
    .httpsCallable('registerWithEmail')
    .call<Map<String, dynamic>>({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName,
    });

print(result.data); // { success: true, clientID: 'AWC0001' }
```

The SDK wraps the body as `{ "data": {...} }` and attaches the ID token automatically.

If for any reason raw HTTP must be used, the client is responsible for BOTH:
- wrapping the body: `'data': { uid, email, displayName }`
- attaching the header: `Authorization: Bearer <idToken>`

### What an `onCall` function signature looks like on the server
```ts
export const registerWithEmail = functions.https.onCall(async (data) => {
  // data is whatever was under the "data" key in the request body
  const { uid, email, displayName } = data as RegisterUserData;
  // ...
});
```

`data` is the unwrapped payload, **not** the full request body.

### Common related issues (not the current bug, but seen nearby)
- Wrong region: if deployed with `.region('asia-south1')` etc., the client must
  call via `FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable(...)`.
  Default is `us-central1`.
- Spark plan: `onCall` requires Blaze. On Spark the call fails silently client-side.
- Deploy drift: after editing `functions/src/index.ts`, run `npm run build` inside
  `functions/` (or let the Firebase CLI build it) before `firebase deploy --only functions`.

---

## 2. Flutter desktop (Windows) + Firebase — known gotchas

`cloud_functions`, `firebase_auth`, `cloud_firestore` etc. are all supported
on Windows desktop in current FlutterFire. The platform is **not** the
problem if a call is failing.

Things that have historically been mistaken for "doesn't work on Windows":

1. **Missing `firebase_core` initialization for desktop.** Mobile picks up
   `google-services.json` / `GoogleService-Info.plist` automatically. On
   Windows you initialize explicitly:
   ```dart
   await Firebase.initializeApp(
     options: const FirebaseOptions(
       apiKey: '...',
       appId: '...',
       messagingSenderId: '...',
       projectId: '...',
       authDomain: '...',
       storageBucket: '...',
     ),
   );
   ```
   If this fails, every downstream call (including `httpsCallable`) fails too.
2. **C++ toolchain.** Windows builds need the Visual Studio C++ workload,
   CMake, and the right Flutter Windows toolchain. Build-time errors here
   look unrelated to Firebase but block the whole app.
3. **Region mismatch** (see section 1).
4. **Network/proxy on Windows.** Less common, but raw `http.post` to a
   Cloud Functions URL can be blocked where the SDK's native transport
   works, or vice versa. Another reason to prefer `httpsCallable`.

---

## 3. Project layout (quick reference)

- `lib/` — Flutter app source
- `functions/src/index.ts` — Cloud Functions (TypeScript source)
- `functions/lib/index.js` — compiled output (do not edit by hand; rebuild
  with `npm run build` inside `functions/`)
- `pubspec.yaml` — Flutter deps, includes:
  - `firebase_core: ^4.7.0`
  - `cloud_firestore: ^6.2.0`
  - `cloud_functions: ^6.3.3`
  - `firebase_auth: 6.5.3`
  - `http: ^1.2.0` (use only for non-callable HTTP; **not** for `onCall`)

---

## 4. Debugging a callable function

When `registerWithEmail` (or any `onCall`) misbehaves, run in order:

1. `firebase functions:log --only registerWithEmail` — see the server-side view.
2. Check for `"Request body is missing data."` -> payload shape is wrong (no
   `data` wrapper, or being sent as raw HTTP).
3. Check `verifications.auth` value. `"MISSING"` = no ID token attached.
   `"VALID"` = token attached and accepted.
4. Check region on both client and server match.
5. Confirm Blaze plan is active on the Firebase project.
6. Confirm the deployed function matches the source (rebuild + redeploy).

---

## 5. Conventions / style for this project

- Always use `httpsCallable` for `onCall` functions. Never use `http.post`
  to call them.
- When adding a new callable, name it `verbNoun` in camelCase on both sides
  (e.g. `registerWithEmail`, `createAppointment`).
- When in doubt about a Firebase error, check the function logs first, then
  the client console, then the rules.

---

## 6. Solution for establishing connection (post-`httpsCallable` registration stuck on login)

After switching from raw `http.post` to `FirebaseFunctions.instance.httpsCallable('registerWithEmail').call(...)` the 401 `UNAUTHENTICATED` error goes away, but a new symptom can show up: the user is created in Firebase Auth, the cloud function call appears to succeed, and yet the app stays on the `LoginScreen` and never routes into the role-specific screen (`ClientScreen` / `DietitianScreen` / `AdminScreen`). This section documents that failure mode in full so it can be dropped back into chat later.

### Symptom

- `createUserWithEmailAndPassword` returns normally; a UID is logged.
- The `httpsCallable('registerWithEmail')` call returns without throwing.
- `firebase functions:log --only registerWithEmail` shows a successful execution (or no new logs at all, depending on whether the function ever ran).
- The app remains on `LoginScreen` after the "Create Account" button finishes. No navigation happens. From the user's perspective, it looks like the connection was never established.
- The debug console from the first failed run additionally shows two `flutter/shell/common/shell.cc(1183)] ... non-platform thread` errors from `firebase_auth_plugin/auth-state/[DEFAULT]` and `firebase_auth_plugin/id-token/[DEFAULT]`.

### Root cause

There are actually three independent things going on, only one of which is the real cause of the "stuck on login" symptom. The other two are red herrings that look like the cause.

#### A. (Real cause, most likely) `AuthProvider` is racing the `authStateChanges` stream

In `lib/core/providers/auth_provider.dart`, the `registerWithEmail` method does this:

```dart
await _authService.registerWithEmail(...);
// nothing else — control returns to the caller
```

It never sets `_currentUser` or `_status = AuthStatus.authenticated` itself. It relies on `_init()`'s `authStateChanges.listen(...)` callback to pick up the new user, call `_userService.fetchByUid(uid)`, and set the state.

The race is:

1. `_auth.createUserWithEmailAndPassword(...)` resolves.
2. The `authStateChanges` stream fires with the new user.
3. The listener calls `_userService.fetchByUid(uid)`.
4. The cloud function (`httpsCallable('registerWithEmail')`) is still running server-side and has not yet written `users/{uid}` to Firestore.
5. `fetchByUid` returns `null`.
6. The listener hits the `if (appUser == null)` branch and calls `await _authService.signOut()`, setting `_status = AuthStatus.unauthenticated` and `_errorMessage = 'No Account found.'`.
7. The user is now signed out. The cloud function's `users/{uid}` write either never happens (because the function is rejected post-sign-out) or happens to a doc that no one will ever read.
8. `AuthWrapper` reads `authProvider.status == AuthStatus.unauthenticated` and renders `LoginScreen`.

The "trouble establishing connection" feeling the user reports is exactly this: the app silently signs them out immediately after they register.

#### B. (Real cause, second most likely) The cloud function is failing silently

If `httpsCallable` returns but the cloud function itself throws (Firestore rules reject the write, the function expects a `role` field the client didn't send, region mismatch, function not redeployed after a code change, etc.), the user is left signed in to Auth with no `users/{uid}` document. The `authStateChanges` listener then runs the same `fetchByUid → null → signOut` path as in scenario A, with the same end result.

This is why the fix in scenario A also surfaces scenario B: the explicit post-call `fetchByUid` will throw a clear error if the doc is missing, instead of silently signing the user out.

#### C. (Red herring, not the cause) The `flutter/shell/common/shell.cc(1183)]` non-platform-thread warnings

The two `[ERROR:flutter/shell/common/shell.cc(1183)] The 'firebase_auth_plugin/...'` warnings from `auth-state/[DEFAULT]` and `id-token/[DEFAULT]` are a known quirk in `firebase_auth: 6.5.3` on Flutter desktop (and some adjacent versions). The native side of the plugin dispatches these specific channel callbacks off the platform thread, and Flutter's engine logs a warning. They are not fatal, do not break authentication, and do **not** cause the 401 or the "stuck on login" symptom. They are noise from the plugin and can be ignored unless they are upgraded away by moving to a newer `firebase_auth` major version (which requires coordinated bumps across the rest of FlutterFire).

#### D. (Red herring, but worth removing) `FirebaseFirestore.instance.clearPersistence()` in `main.dart`

```dart
try {
  await FirebaseFirestore.instance.clearPersistence();
} catch (e) {
  print('Error clearing Firestore persistence: $e');
}
```

This call is unnecessary (Firestore persistence defaults are fine) and actively harmful in a dev loop: on Windows desktop it can clear an in-flight auth session on hot reload / restart, which then manifests as "user gets signed out for no reason." Delete it.

### Why the 401 was never the connection bug

The 401 `UNAUTHENTICATED` / "must be signed in" that the app used to throw was a separate, earlier bug: the call was being made with raw `http.post` directly to the function URL, which (a) requires the body to be wrapped as `{ "data": {...} }` and (b) requires an `Authorization: Bearer <idToken>` header. The body wrapper was being added manually but the auth header was not, so the function rejected the call. Switching to `FirebaseFunctions.instance.httpsCallable('registerWithEmail').call(...)` makes the SDK attach the ID token automatically and wrap the payload, fixing the 401. The "stuck on login" symptom is independent of the 401 and shows up after the 401 is fixed.

### The fix (in full, drop-in replacement)

Replace `AuthProvider.registerWithEmail` in `lib/core/providers/auth_provider.dart` with this:

```dart
Future<void> registerWithEmail({
  required String email,
  required String password,
  required String displayName,
  required UserRole role,
}) async {
  _status = AuthStatus.loading;
  _errorMessage = null;
  notifyListeners();

  try {
    print('registering with email in authprovider');
    await _authService.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );

    // Don't wait for authStateChanges to fire. The user is already signed in
    // (createUserWithEmailAndPassword returned). Fetch the profile we just
    // created via the cloud function and set state explicitly.
    final firebaseUser = await _authService.getCurrentAuthUser();
    if (firebaseUser == null) {
      throw StateError('Auth user missing immediately after registration');
    }
    final appUser = await _userService.fetchByUid(firebaseUser.uid);
    if (appUser == null) {
      // Cloud function didn't write the doc. Surface this loudly.
      throw StateError(
        'Registration succeeded in Auth but the user profile was not created. '
        'Check firebase functions:log --only registerWithEmail',
      );
    }
    _currentUser = appUser;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
  } catch (e) {
    _status = AuthStatus.unauthenticated;
    _errorMessage = 'Registration failed. Try Again';
    debugPrint('registerWithEmail failed: $e');
  } finally {
    notifyListeners();
  }
}
```

This:
- eliminates the race with the `authStateChanges` stream (the stream can still fire, but the UI state is already correct by the time it does);
- makes the failure mode visible — if the cloud function fails to write `users/{uid}`, the explicit `fetchByUid` returns `null` and throws a clear error message that points at the function logs;
- uses a `try/finally { notifyListeners() }` so the UI is always told the loading state is over, even on the error path.

The corresponding `AuthService.registerWithEmail` is fine as long as it is using `httpsCallable` and not `http.post` — the version in `lib/core/services/auth_service.dart` already is. The `user.displayName` field used in the payload should be the local `displayName` parameter (not `user.displayName`) to avoid a potential race where the in-memory `User` object hasn't yet reflected the `updateDisplayName` write:

```dart
final result = await _functions.httpsCallable('registerWithEmail').call<Map<String, dynamic>>({
  'uid': user.uid,
  'email': user.email,
  'displayName': displayName, // use the local parameter, not user.displayName
});
```

### Companion fixes

1. **Delete `FirebaseFirestore.instance.clearPersistence()` from `main.dart`.** It's unnecessary and can wipe an in-flight auth session on Windows desktop.

2. **Add a post-call sanity check in `AuthService.registerWithEmail`** if the explicit `fetchByUid` in the provider isn't surfacing enough detail:

   ```dart
   final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
   if (!doc.exists) {
     debugPrint('WARNING: registerWithEmail returned but no users/{uid} doc exists');
   }
   ```

   If this warning prints, the bug is in the cloud function (rules, role enforcement, region mismatch, redeploy drift) and the next step is `firebase functions:log --only registerWithEmail`.

3. **Do not bump `firebase_auth` just to silence the `non-platform thread` warnings.** The warnings are cosmetic and the major-version bump requires coordinated upgrades across the rest of FlutterFire. Leave them unless they are upgraded for an unrelated reason.

### Diagnostic order when this symptom returns

1. Check the debug console for `Registration succeeded in Auth but the user profile was not created.` — if present, the cloud function is the failure point; go to step 2. If absent, the auth flow is working and the issue is elsewhere (router, screen-level state, etc.).
2. `firebase functions:log --only registerWithEmail` — look for the most recent execution, the error code, and whether the function even started.
3. Check Firestore rules on `users/{uid}` — `request.auth.uid == userId` is required for the function's admin-context write, and a read of `users/{uid}` from the client requires the same.
4. Confirm the deployed function matches the local source (`npm run build` inside `functions/`, then `firebase deploy --only functions`).
5. Confirm region on both client and server match.

---

## 7. Potential issues (current debugging session — Windows `Unable to establish connection`)

### Root cause found

**Windows native plugin for `cloud_functions` is missing from the build.**

Concrete evidence:

1. `windows/flutter/generated_plugin_registrant.cc` registers only 3 plugins: `cloud_firestore`, `firebase_auth`, `firebase_core`. No `cloud_functions`.
2. `windows/flutter/generated_plugins.cmake` `FLUTTER_PLUGIN_LIST` same — no `cloud_functions`.
3. macOS registrant was updated (uncommitted): `FirebaseFunctionsPlugin.register(with:...)` is present. Windows equivalent was never regenerated.
4. Dart calls `_functions.httpsCallable(...)` which dispatches to `dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call` on a Pigeon channel. On Windows no plugin owns that channel — error: `Unable to establish connection on channel: "dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call"`.
5. macOS/iOS/Android work because their registrants include `FirebaseFunctionsPlugin`. Web works because `cloud_functions_web` handles it. Windows desktop has no implementation.
6. `firebase_auth` 6.5.6 + `cloud_functions` 6.3.5 are pinned together. Auth succeeds (user created in Firebase Auth) but the post-auth call to create the Firestore doc fails because the function call channel has no Windows handler.

Secondary issues spotted while mapping (not the blocker, but worth noting):

- `auth_provider.registerWithEmail` swallows the `FirebaseFunctionsException` and shows generic `'Registration failed. Try Again'` — you lose the real error. Debug logs survive, UI does not.
- `login_screen._submitEmail` `catch` block rarely fires because the provider already caught and converted the error to a status message.
- `FirebaseFunctions.instance` has no region set. Default is `us-central1`. If the function is deployed elsewhere the call will 404 even on platforms that work.
- `registerWithEmail` callable has a logic typo: `isRegisterData` returns false on missing fields, then the code throws `unauthenticated` instead of `invalid-argument`. Cosmetically wrong, not the blocker.
- The function requires `request.auth` to match `data.uid` — works only because the client passes its own freshly created `user.uid`.

### Fix paths (pick one)

| Option | What it does | Trade-off |
|---|---|---|
| **A. Regenerate Windows registrant** (likely fastest) | Run `flutter pub get` + `flutter create --platforms=windows .` (or `flutter clean` + `flutter pub get`) on a Windows host. The `generated_plugin_registrant.cc` and `generated_plugins.cmake` get rewritten to include `cloud_functions`. | Requires a real Windows shell with Flutter installed and a clean rebuild. If the plugin's native side has a Windows build script that errors, this won't work. |
| **B. Manually add `cloud_functions` to Windows registrant** | Edit `windows/flutter/generated_plugin_registrant.cc` and `windows/flutter/generated_plugins.cmake` to add the `cloud_functions` plugin entry (mirror the macOS change). | Risky. `generated_*` files are auto-rewritten; manual edits can be clobbered. May also need CMakeLists linkage for `firebase_core_cpp` if v2 SDK plugin requires it. |
| **C. Switch the client from `httpsCallable` to raw HTTPS** | `cloud_functions` 6.x has no Windows platform implementation regardless of registrant. A direct `https.post` to the function's HTTPS endpoint with the Firebase ID token bypasses the plugin entirely. | Changes `auth_service.dart` only. `http: ^1.2.0` is already in deps. Need to construct the request URL, attach `Authorization: Bearer <idToken>`, set CORS-friendly headers, and call `onRequest` semantics (note: callable onRequest is different from raw onRequest; or convert the function to a plain HTTPS handler). |
| **D. Move registration to an `onUserCreated` auth trigger** | Drop the callable. The trigger fires server-side whenever Firebase Auth creates a user, no client call needed. The client just signs up; the doc appears automatically. | Requires `functions/src/index.ts` rewrite + redeploy + remove the `httpsCallable` call from `auth_service.dart` + handle race where the client queries the doc before the trigger finishes (small delay, retry, or `onAuthStateChanged` waits). This is the same path hinted at in your `cloud-function-fix-version-2.md` memory. |

For the stated blocker (callable fails on Windows), the actual root cause is the missing Windows plugin. Option C or D sidestep the plugin entirely and are the durable fix — D is cleanest long-term. Option A is fastest if it can be verified to work on this machine.

Recommendation: **D** (onUserCreated trigger) because it removes the Windows problem at the source, kills the client/server race, and matches what's in the existing `cloud-function-fix-version-2.md` memory notes. **C** is the smallest client-side change if the callable contract must be kept.

---

## 9. beforeUserCreated solution cloud function

v2 is cleaner. `beforeUserCreated` is the real win — it runs BEFORE the user is created in Auth, so you can block invalid signups, set custom claims, or reject the user entirely.

- `onUserCreated` = runs after, can mutate the user.
- `beforeUserCreated` = runs before, can block creation or set custom claims that are available in the very next auth event.

**`functions/package.json` (must match the deployed v2 runtime):**

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^6.0.0"
  }
}
```

v6 = v2 API. Run `npm install` after editing.

**`functions/src/index.ts` — full rewrite in v2:**

```ts
import { onUserCreated, beforeUserCreated } from 'firebase-functions/v2/identity';
import * as admin from 'firebase-admin';

admin.initializeApp();

interface UserDoc {
  uid: string;
  email: string;
  displayName: string;
  role: 'client' | 'dietitian' | 'admin';
  clientID: string;
  createdAt: admin.firestore.Timestamp;
}

const PENDING_COLLECTION = 'pendingUsers';
const COUNTER_DOC = admin.firestore().collection('counters').doc('users');
const USERS_COLLECTION = 'users';

function generateClientID(): Promise<string> {
  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(COUNTER_DOC);
    const next = (snap.data()?.seq ?? 0) + 1;
    tx.set(COUNTER_DOC, { seq: next });
    return `AWC${String(next).padStart(4, '0')}`;
  });
}

// Runs BEFORE the user is created in Auth.
// Reads the pending doc (role, displayName) the client wrote pre-signup,
// sets custom claims so they're available immediately after signup.
// Throws HttpsError to block creation if the pending doc is missing/invalid.
export const beforeSignup = beforeUserCreated((event) => {
  const { uid } = event.data!;
  // Note: beforeUserCreated has NO async DB access (must respond fast).
  // You can only inspect event.data (UserRecord) here.
  // Role is passed via custom claims set by a separate callable OR
  // via the user's displayName/email trick OR via a pending doc read
  // in a follow-up onUserCreated. beforeUserCreated is best used for
  // blocking bad signups + setting initial claims.
  return {};
});

// Runs AFTER the user is created in Auth.
// Reads pending doc, writes the full user profile to Firestore.
export const onSignupComplete = onUserCreated(async (event) => {
  const user = event.data!;
  const { uid, email, displayName } = user;

  console.log(`onUserCreated: ${uid} (${email})`);

  // Read the pending doc the client wrote before signup
  const pendingRef = admin.firestore().collection(PENDING_COLLECTION).doc(uid);
  const pendingSnap = await pendingRef.get();

  const role: UserDoc['role'] =
    (pendingSnap.data()?.role as UserDoc['role']) ?? 'client';

  const clientID = await generateClientID();
  console.log(`Generated clientID: ${clientID} for ${uid}`);

  const doc: UserDoc = {
    uid,
    email: email ?? '',
    displayName: displayName ?? '',
    role,
    clientID,
    createdAt: admin.firestore.Timestamp.now(),
  };

  await admin.firestore().collection(USERS_COLLECTION).doc(uid).set(doc);

  // Cleanup pending doc
  await pendingRef.delete().catch(() => {});

  // Set role as custom claim so the client can read it via ID token
  // without an extra Firestore round-trip
  await admin.auth().setCustomUserClaims(uid, { role });
});
```

### beforeUserCreated caveat — important

It has a hard 1-second timeout and no async DB access. You can only inspect `event.data` (the UserRecord being created). So it can't read `pendingUsers/{uid}`.

Patterns for "role before signup":

| Pattern | How | Trade-off |
|---|---|---|
| A. custom claims set by client | client calls `getIdToken()` → small callable `setPendingSignup` that writes a temporary custom claim → `createUserWithEmailAndPassword` → trigger reads claim | 2 round-trips. Slightly clunky. |
| B. pending doc read in `onUserCreated` | client writes `pendingUsers/{uid}` pre-signup → `onUserCreated` reads it | 1 extra doc write client-side. **Simplest.** |
| C. block + write only in `onUserCreated` | `beforeUserCreated` returns `{}` (just lets signup through), `onUserCreated` does all the work using pending doc | What the snippet above does. **Recommended.** |

Use C. `beforeUserCreated` is mostly there to **block** bad signups, not carry data.

### `auth_service.dart` — drop the callable, add pending doc write

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String role, // 'client' | 'dietitian' | 'admin'
  }) async {
    // 1. Create the Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName);

    // 2. Write pending doc so the trigger can pick up the role
    await _db.collection('pendingUsers').doc(user.uid).set({
      'role': role,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  Future<User?> getCurrentAuthUser() => _auth.currentUser;
}
```

### `auth_provider.dart` — poll for profile

```dart
Future<void> registerWithEmail({
  required String email,
  required String password,
  required String displayName,
  required UserRole role,
}) async {
  _status = AuthStatus.loading;
  _errorMessage = null;
  notifyListeners();

  try {
    await _authService.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: role.name,
    );

    final firebaseUser = await _authService.getCurrentAuthUser();
    if (firebaseUser == null) {
      throw StateError('Auth user missing after registration');
    }

    // Poll for the profile (trigger takes ~100-500ms)
    AppUser? appUser;
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      appUser = await _userService.fetchByUid(firebaseUser.uid);
      if (appUser != null) break;
    }

    if (appUser == null) {
      throw StateError(
        'Profile not created in time. Check firebase functions:log',
      );
    }

    _currentUser = appUser;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
  } catch (e) {
    _status = AuthStatus.unauthenticated;
    _errorMessage = 'Registration failed. Try Again';
    debugPrint('registerWithEmail failed: $e');
  } finally {
    notifyListeners();
  }
}
```

### `firestore.rules` — add for pending doc

```
match /pendingUsers/{uid} {
  allow create: if request.auth == null && request.resource.data.role is string;
  allow read, update, delete: if false; // server-only
}
```

### Deploy

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

After deploy, console should show two new functions: `beforeSignup` (v2, identity trigger) and `onSignupComplete` (v2, identity trigger). No more `onCall`, no more Windows plugin dependency, no more client/server race.

---

## 8. Old cloud function (reference — kept for diff context, do NOT redeploy)

The `https.onCall` implementation that was replaced by the `onUserCreated` trigger (see §7). Kept here so the diff and the contract (payload shape, `clientID` format) stay auditable.

```ts
interface RegisterUserData {
  uid: string;
  email: string;
  displayName: string;
  role: 'client' | 'dietitian' | 'admin';
  clientID: string;
  createdAt: admin.firestore.Timestamp;
}

/**
 * Checks if the object is in RegisterUserData format.
 * @param {unkown} x The value to validate.
 * @return {boolean} True if c is a valid RegisterUserData object.
 */
function isRegisterData(x: unknown): x is RegisterUserData {
  if (typeof x !== "object" || x === null) return false;
  const o = x as Record<string, unknown>;
  return typeof o.uid === "string" &&
      typeof o.email === "string" &&
      typeof o.displayName === "string";
}

export const registerWithEmail = functions.https.onCall(
  async (request: functions.https.CallableRequest<RegisterUserData>) => {
    if (!isRegisterData(request.data)) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be signed in to register."
      );
    }

    const {uid, email, displayName} = request.data;

    console.log("uid:", uid, "email:", email, "displayName", displayName);
    if (!uid || !email || !displayName) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Missing required fields"
      );
    }

    const auth = request.auth;
    if (auth && auth.uid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied", "invalid login"
      );
    } if (!auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "must be signed in"
      );
    }

    const clientID = await generateClientID();
    console.log("client ID: ", clientID);

    await db.collection("users").doc(uid).set({
      uid: uid,
      email: email,
      displayName: displayName,
      role: "client",
      clientID: clientID,
    });

    return {success: true, clientID};
  });


/**
 * Generates a unique client ID in the format AWC0001, AWC0002, etc.
 * Uses a Firestore transaction to prevent race conditions.
 */
async function generateClientID(): Promise<string> {
  const counterRef = db.collection("counters").doc("clientIDCounter");

  return await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(counterRef);
    const lastNumber = doc.exists ? (doc.data()?.lastNumber || 0) : 0;
    const newNumber = lastNumber + 1;

    transaction.set(counterRef, {lastNumber: newNumber});

    return "AWC" + newNumber.toString().padStart(4, "0");
  });
```
