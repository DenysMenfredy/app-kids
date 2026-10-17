# ADR 0017 — Plan v2: store-only billing and explicit Firebase builds

Date: 2026-10-16. Status: accepted for product boundaries and local implementation;
real environment/store acceptance remains open.

## Context and precedence

`Lele_Plano_Execucao_MVP.md` version 2.0 replaces the external acquisition
channel in ADR 0007. The owner confirmed D01, D08 and D09 during execution.
Historical payment records are not evidence that there are no real customers.
ADR 0005's UID-only identity and explicit Apple linking requirements remain.

## Decisions D01–D09

- D01: launch without a trial promise. A future trial requires a configured and
  verified eligible native store offer; Firebase must not invent a parallel
  commercial trial. The previous Stripe seven-day proposal is superseded for
  acquisition. Do not cancel or rewrite an existing contract from this ADR.
- D02: retain the entire first introductory module as free. Version/access
  policy and book classification remain server-owned under ADRs 0007/0012/0014.
- D03: use native Google Play Billing and App Store/StoreKit 2 directly, through
  Flutter `in_app_purchase` and Firebase store verification. Native billing is
  required for commercial launch, not an optional future web alternative.
  A learning-only beta must keep acquisition disabled until verification works.
- D04–D06: retain online protected-content authorization/authoritative completion,
  minimal child fields (short name, avatar, age 3–7, no exact birth date), and
  seven modules/37 lessons/six comprehension stories/six library books.
- D07: still open. No retention matrix, legal consent copy, financial-record
  deletion period or analytics eligibility has been silently approved.
- D08: verified Premium belongs to the parent Firebase UID across Android/iOS.
  A known eligible subscription blocks another acquisition and identifies its
  store of origin. This policy still requires the F3 implementation and tests.
- D09: monthly, quarterly and annual plans with equal benefits. Initial UI must
  not change an in-force plan. Actual IDs/base plans await console confirmation;
  localized prices/periods must come from the platform catalog, never constants.

## Implemented boundaries

The app no longer calls or opens hosted checkout/portal, recognizes no
`ENABLE_WEB_CHECKOUT` switch and has no fixed founder-price catalog. Until native
store products and backend verification are configured, the paywall says
subscriptions are unavailable, shows no invented prices and offers no trial.
The URL-launcher dependency used only by checkout was removed. CI's Flutter
regressions reject reintroducing external acquisition symbols in app code.

The existing `createCheckoutSession` URL remains Auth/App Check protected but
always rejects new acquisition, without Stripe secrets or provider calls.
Installed older clients cannot enable it with a formerly approved web app ID.
Keep Stripe webhook verification/idempotency, existing-customer portal and
entitlement synchronization until remote customer inventory and native staging
validation authorize a controlled retirement. Nothing was remotely disabled,
deleted, canceled, migrated or deployed in this delivery.

Firebase configuration is explicit per build, selected via public JSON defines.
A shared validator enforces `APP_ENV` -> exact project mapping, sender/platform
app-ID shape, public API-key shape, bucket, current package/bundle ID, and native
file agreement. Release rejects demo auth, emulator and dev-project modes.
Android pre-build, Xcode pre-build and the Android release workflow use the same
validator; runtime repeats the applicable checks before Firebase initialization.
No real config values were invented. The example is deliberately rejected.
Existing package IDs remain unchanged; flavor registration/signing stays open.

App Check startup/enforcement and the emulator-only exemption remain unchanged.
The config validator does not substitute for release attestation or remote IAM.
Google Pub/Sub and Apple signed-server-event verification belong to F3 and must
not be protected by a client App Check requirement.

## Native plugin spike

Pinned: `in_app_purchase` 3.3.1, `in_app_purchase_android` 0.5.4,
`in_app_purchase_storekit` 0.4.13+3. Publisher: flutter.dev; BSD-3-Clause.
Local package inspection found BillingClient 8.0.0, Java 17/Kotlin 2.3.20 and
Flutter >=3.44/Dart >=3.12 requirements for the Android adapter. This repo uses
Flutter 3.47.4/Dart 3.13.3; Kotlin settings were migrated to compilerOptions.
Five billing-related packages were resolved and eight unused URL-launcher
packages removed. Native release size/security maintenance still need release
measurement; dependency resolution is not a store certification.

Capability tests compile Google opaque `applicationUserName` (mapped by the
adapter to obfuscated account ID) and offer-token parameters. StoreKit 2 maps
the same field to appAccountToken and exposes transaction ID, account token and
JWS evidence. The wrapper exposes original transaction ID and unfinished
transactions; `SK2PurchaseDetails` itself does not expose original ID. Restore
finalization must also account for the plugin's pendingCompletePurchase behavior
instead of assuming it finishes every restored transaction. The backend must
verify JWS/store state and resolve continuity, not trust these client fields.

No store purchase, restore, acknowledgement, Apple JWS verification or store
callback was executed. The spike is capability/compilation evidence, not F3.

## Remaining gates and rollback

F0/T01–T04 remain partial until real staging Firebase/OAuth/App Check and physical
Android/iOS tests pass. Product IDs, credentials/IAM/PubSub/APNs, Mac/signing,
store test accounts, native parental purchase gate, account-link generation,
store verification, event inbox/reconciliation/outbox, acknowledgement/finish and
cross-platform restore are required before enabling acquisition.

Do not deploy new rules or delete old functions as part of a configuration-only
rollout. First run the trust and old-client matrices in staging. Preserve
subscriptions/ownership maps and reconciliation; rollback must not resurrect
external acquisition. If necessary, disable new acquisition while retaining
valid server-owned entitlements and legacy callbacks. No data migration is
performed by changing public build config.
