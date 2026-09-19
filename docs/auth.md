# Authentication

The app signs in at the platform's Keycloak realm with OpenID Connect:
authorization code flow with PKCE in the system browser sheet, as a public
client. There is no secret in the app, no password field in the app, and no
embedded web view. The same account works on bognerchess.com.

Code: `lib/core/auth/` (everything but the screen) and `lib/features/auth/`
(the sign-in screen). Tests: `test/core/auth/`, `test/features/auth/`.

## The pieces

| Piece | File | Role |
| --- | --- | --- |
| `AuthRepository` | `auth_repository.dart` | The interface the rest of the app sees: `state`, `states`, `restore()`, `signIn()`, `accessToken()`, `forceRefresh()`, `signOut()`. |
| `AppAuthRepository` | `app_auth_repository.dart` | The real one. All rules of this document live here. |
| `FakeAuthRepository` | `fake_auth_repository.dart` | `AUTH_MODE=fake`: signed in as `fake-user-1` with the token `fake-access-token`; `signOut()`/`signIn()` toggle. |
| `OidcClient` | `oidc_client.dart` | Three calls: `authorize`, `refresh`, `revoke`. Exists so that every branch of the repository is testable with a fake. |
| `AppAuthOidcClient` | `app_auth_oidc_client.dart` | `OidcClient` on `flutter_appauth` (AppAuth-iOS, `ASWebAuthenticationSession`), plus one `dart:io` HTTPS call for revocation, which AppAuth does not offer. The only importer of `flutter_appauth`. |
| `TokenStore` | `token_store.dart` | `SecureTokenStore` (Keychain through `flutter_secure_storage`) and `InMemoryTokenStore`. The only importer of `flutter_secure_storage`. |
| `InstallMarker` | `install_marker.dart` | "This installation has started before", in shared preferences. |
| `Tokens`, `IdTokenClaims` | `tokens.dart` | The stored token set; the claims read from the id token. |
| `AuthConfig` | `auth_config.dart` | Compile-time switches: scopes, session mode, registration mode, margins and time-outs. |
| `AuthState`, `authStateProvider` | `auth_state.dart` | `SignedOut` or `SignedIn(sub, email?, emailVerified?, name?)`; the provider mirrors the repository and drives the router's redirect. |
| Providers | `auth_providers.dart` | `authRepositoryProvider` (fake or real from `Env`), `oidcClientProvider`, `tokenStoreProvider`, `installMarkerProvider`. |

`main.dart` awaits `authRepositoryProvider.restore()` before `runApp`, so the
router's first redirect already knows who is signed in.

## Sign-in

`signIn({register, idpHint})` calls `authorizeAndExchangeCode` with

- client `OIDC_CLIENT_ID`, redirect `OIDC_REDIRECT`, issuer `OIDC_ISSUER`
  (OIDC discovery; the native library then validates issuer, audience, expiry
  and nonce of the id token);
- PKCE S256, `state` and `nonce`, all generated natively;
- scopes `openid profile email offline_access`;
- `prompt=create` for "Create account" (the standard parameter of "Initiating
  User Registration via OpenID Connect", which Keycloak supports from 26.1);
- `kc_idp_hint=apple` or `kc_idp_hint=google` for the provider buttons, which
  skips Keycloak's own login page.

When the user closes the sheet, `signIn` completes normally and nothing
changes: cancelling is not an error, and the screen shows nothing. Other
failures throw `AuthException(network | server)`, which the screen turns into
an inline message, never a snackbar. A second tap while the sheet is open joins
the first attempt.

The id token's payload is decoded **without verifying the signature**. The app
makes no security decision on it: `sub` scopes local data, e-mail and name are
shown to the user. Every request is authorised by the backend, which verifies
the access token.

### Registration and e-mail verification (risk 4)

Keycloak asks a new user to confirm the e-mail address. The link in that mail
opens in Safari or in the mail app's browser, not in the app's browser sheet,
so the sheet never completes: the user closes it and is back on the sign-in
screen, signed out. For that case the screen has an "E-mail not confirmed yet?"
help, which opens by itself after coming back from "Create account" without a
session and without an error (after an error no mail was sent). Its button
"I have confirmed it – sign in" is a plain `signIn()`.

A user who is signed in with `emailVerified == false` (possible if the realm
lets unverified users in) gets fresh claims with the next refresh:
`forceRefresh()` updates `SignedIn.emailVerified` when the new id token says
so. The API's `EmailNotVerified` result is handled where it occurs (WP-12,
WP-28), not here.

### Provider buttons

Default: Apple and Google, Apple first. The optional dart-define `AUTH_IDPS`
narrows the list, e.g. `"AUTH_IDPS": "google"` in `config/<env>.json` until
the Apple identity provider exists at the server (human gate H6), or `""` for
none. The names are the identity provider aliases in the realm. The Google
button shows a plain "G", not Google's logo, which is not ours to bundle.

## Token storage

One Keychain item, `auth.tokens.v1`, holds the whole set as JSON (access,
refresh and id token, expiry, time of arrival), so that a write is atomic.
Accessibility is `first_unlock_this_device`: readable in the background after
the first unlock, never in a backup, never on another device. Content the app
cannot read counts as absent and is deleted.

**Reinstall rule.** iOS keeps Keychain items when an app is deleted, but
deletes its preferences. On a start without the marker `auth.install_marker`
in shared preferences, `restore()` clears the token store and sets the marker.
Whoever installs the app again starts signed out.

`restore()` makes no network request. Stored tokens mean signed in, even
offline and even with an expired access token; the first `accessToken()` call
renews it. `restore()` never throws: if the Keychain cannot be read, the app
starts signed out.

Tokens, subjects, e-mail addresses and server error descriptions are never
logged; `toString()` of the token classes prints `***`. A test reads every log
line of a full session to make sure.

## Refresh rules

- `accessToken()` returns the cached token while it has **more than 30 s**
  left. Otherwise it awaits the refresh.
- **Single flight.** Keycloak rotates refresh tokens: of two concurrent
  refreshes with the same token, the second gets `invalid_grant`. The
  repository keeps one `Future<Tokens?>? _inFlight`; every caller that needs a
  new token awaits that one future. Ten concurrent `accessToken()` calls make
  one request (tested).
- `forceRefresh({rejectedToken})` is for the API layer after a 401. With the
  refused token passed in, it returns the current token without a request if
  somebody else has refreshed since.
- **`invalid_grant`** (or `invalid_token`): the session is over. Tokens are
  cleared, the state becomes `SignedOut`, the call returns `null`, the router
  shows the sign-in screen. Drafts and cached data stay; nothing is revoked.
- **Transport errors, time-outs, 5xx, anything else**: tokens are **kept**,
  the call throws `AuthException`. Offline is not signed out.
- **Time-out.** A caller waits 20 s at most. The request itself is not
  cancelled: if the answer still arrives, the rotated tokens are stored.
  Dropping them would end the session at the next refresh, because the old
  refresh token is used up by then.
- **Clocks.** The expiry is computed natively from `expires_in` and the device
  clock at arrival, so a difference between server and device clock does not
  matter. If the device clock is set back by more than a minute, the token
  counts as expired. If the server considers a token expired that the device
  still trusts, the 401 and `forceRefresh` handle it. A response without an
  expiry is treated as expired at once.
- A refresh response without a refresh token or id token keeps the old one. A
  new id token updates the claims in `SignedIn`.
- A refresh that finishes after a sign-out is discarded, and the refresh token
  it brought is revoked.
- Refresh and revocation use endpoints derived from the issuer
  (`<issuer>/protocol/openid-connect/{token,revoke}`) instead of discovery:
  `flutter_appauth` would otherwise fetch the discovery document before every
  refresh. The paths were checked against the discovery document of the
  production realm.

## Sign-out

`signOut()` never throws and works offline:

1. forget the tokens in memory and in the Keychain, publish `SignedOut`;
2. `AppDatabase.wipeOwner(sub, keepDrafts: true)`: cached games, analyses,
   jobs and per-user settings go, drafts stay;
3. revoke the refresh token at the revocation endpoint (RFC 7009, public
   client: `client_id`, `token`, `token_type_hint=refresh_token`), without a
   browser, waiting 8 s at most. A failure is logged and ignored. The token is
   gone from the device then; its session at the server ends by time-out or
   from the account console.

There is no end-session browser round trip. With the ephemeral session mode
there is no browser session to end.

## Session mode (decision for a human)

`ASWebAuthenticationSession` can run shared (default of iOS) or ephemeral
(`prefersEphemeralWebBrowserSession`; in `flutter_appauth` 12 this is
`externalUserAgent: ExternalUserAgent.ephemeralAsWebAuthenticationSession`,
the older `preferEphemeralSession` flag is gone). The switch is
`AuthConfig.preferEphemeralSession`.

| | Shared | Ephemeral |
| --- | --- | --- |
| System alert "“Bogner Chess” wants to use “bognerchess.com” to sign in" | Yes, before every sheet | No |
| Single sign-on with Safari (already signed in on the website) | Yes | No, credentials are typed every time |
| Google session from Safari reused | Yes | No |
| Sign in with Apple in the sheet | Web flow; an Apple ID cookie from Safari may shorten it | Web flow; Apple ID typed or passkey |
| After sign-out | **Sticky**: Keycloak's cookie survives, the next "Sign in" silently returns the same account; switching accounts needs `prompt=login` or an end-session round trip | Clean: the next sign-in asks who you are |
| Shared device (club, family) | The previous user's browser session stays behind | Nothing stays behind |
| Password manager autofill | Works | Works |

**Recommendation: ephemeral (the default set in code).** Sign-in is rare here,
because offline tokens keep the session for a long time; so the cost (typing
credentials, no SSO) is paid seldom, while the benefits apply every time: no
alert that many users read as a warning, a sign-out that really signs out
without a browser round trip, and no leftovers on shared devices. It is also
the only mode in which "revocation without a browser" is a complete sign-out.

If a human decides for shared after trying both (checklist below), two changes
are needed besides the switch: send `prompt=login` with the first sign-in
after an explicit sign-out, and expect the alert in the UX copy.

What could not be decided without a real login, and is on the checklist:
whether Sign in with Apple shows the native sheet or the web form in either
mode (design risk 2), and how Google behaves in the ephemeral sheet.

## Fake auth

`AUTH_MODE=fake` selects `FakeAuthRepository`. Three guards keep it out of a
release: `Env.fromEnvironment` throws for fake auth in a release build,
`authRepositoryProvider` throws for fake auth in a release build or with
`ENV_NAME=prod`, and the constructor asserts `!kReleaseMode`.

To look at the sign-in screen without an identity provider:

    flutter run -t lib/features/auth/dev/sign_in_demo.dart \
      --dart-define-from-file=config/fake.json
    # optional: --dart-define=SIGN_IN_DEMO=offline   (or =error)
    # optional: --dart-define=SIGN_IN_DEMO_TAP=signin-verify-toggle,signin-register

## Keycloak client requirements

Already seeded by the infrastructure; listed here so that a new realm can be
checked against it.

- Client `bognerchess-mobile`: OpenID Connect, **public** (no client
  authentication), standard flow only; no implicit flow, no direct access
  grants.
- Valid redirect URI `com.bognerchess.mobile:/oauthredirect` (exactly; the
  scheme is registered in `ios/Runner/Info.plist`).
- PKCE code challenge method `S256` required.
- `offline_access` as a default or optional client scope, and the role
  `offline_access` for users (Keycloak's default), so that the refresh token
  is an offline token.
- Refresh token rotation on ("Revoke Refresh Token", reuse 0). The app
  assumes it.
- `email`, `profile` scopes: the id token carries `email`, `email_verified`,
  `name` or `preferred_username`.
- Registration allowed in the realm, with e-mail verification.
  **Keycloak 26.1 or newer for `prompt=create`.** On 2026-09-19 the public
  discovery document of the production realm did not list
  `prompt_values_supported`, so this could not be confirmed from outside. If
  "Create account" opens the login page instead of the registration page, set
  `AuthConfig.useLegacyRegistrationEndpoint = true` (Keycloak's deprecated
  `/protocol/openid-connect/registrations` endpoint) until the server is
  upgraded.
- Identity providers with the aliases `apple` and `google` (H6 for Apple).
- The revocation endpoint accepts public clients (Keycloak does: `client_id`
  in the form body).
- Access token lifetime: the usual 5 minutes works well with the 30 s margin.

## Manual checklist for the human gate (H2, H10)

No agent may do this: it needs real credentials. Use a staging or dev build
with `AUTH_MODE=real` on a device, or on a simulator for everything but Apple.
Tick each line; note the iOS version and the session mode.

**Sign in**

- [ ] "Sign in" opens the sheet with the Keycloak login page. In ephemeral
      mode there is no system alert first.
- [ ] After the login the sheet closes by itself and the app shows the library
      (or the location it was sent to sign-in from, e.g. a deep link).
- [ ] Closing the sheet with "Cancel" returns to the sign-in screen without
      any message.
- [ ] Airplane mode, then "Sign in": the inline "No connection" message, no
      crash. Back online, the next tap works and the message is gone.
- [ ] Kill and restart the app: still signed in, no sheet. Same in airplane
      mode.

**Register and verify the e-mail address**

- [ ] "Create account" opens the **registration** page, not the login page
      (see `prompt=create` above if not).
- [ ] After submitting, Keycloak asks to confirm the address. Switch to Mail,
      open the link (Safari). Return to the app, close the sheet: the help
      card "Confirm your e-mail address" is open.
- [ ] "I have confirmed it – sign in" signs in with the new account.
- [ ] If the realm lets an unverified user in: the account screen shows the
      address as unverified; after confirming and about five minutes (or the
      next 401) it shows as verified without signing in again.

**Apple** (after H6)

- [ ] "Continue with Apple" goes straight to Apple, not to Keycloak's page.
- [ ] Note: native sheet or web form? With Face ID or typed password? Try both
      session modes and record the difference (design risk 2).
- [ ] With "Hide My E-Mail": the app signs in, and the relay address arrives
      in the account screen.
- [ ] Until H6 is done: set `"AUTH_IDPS": "google"` so that the button is not
      shown.

**Google**

- [ ] "Continue with Google" goes straight to Google and back into the app.
- [ ] Google does not refuse the sheet ("browser not secure" is a web-view
      problem and should not occur in `ASWebAuthenticationSession`).

**Token refresh**

- [ ] Stay signed in, leave the app open or in the background for more than
      five minutes (longer than the access token lives), then load the
      library: it loads, no sign-in screen, no error.
- [ ] In the Keycloak admin console the client session shows one offline
      session per device, and no `invalid_grant`/`REFRESH_TOKEN_ERROR` events
      while several requests start at once (pull to refresh right after the
      five minutes).
- [ ] Remove the offline session in the admin console, wait for the access
      token to expire, use the app: it goes to the sign-in screen, and drafts
      are still there after signing in again.

**Sign out**

- [ ] Sign out (account screen): the sign-in screen appears at once.
- [ ] The offline session is gone in the admin console (revocation worked).
- [ ] "Sign in" again: ephemeral mode asks for credentials; shared mode does
      not (that is the stickiness described above).
- [ ] Sign out in airplane mode: works locally. Note that the session stays
      at the server.
- [ ] Sign in as a different user: none of the first user's games appear; the
      first user's drafts are not shown to the second one and are back when
      the first one returns.

**Reinstall**

- [ ] Signed in, delete the app, install it again, start: the sign-in screen,
      not the old session.
