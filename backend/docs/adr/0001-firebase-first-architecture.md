# ADR 0001 — Firebase-first backend, no NestJS for the MVP

Date: 2026-08-18 · Status: accepted

## Context

The Letrando MVP needs auth, a child-safe data model, payments, push and
analytics for a small team shipping fast in Brazil. A separate NestJS (or
any custom) backend adds infrastructure, DevOps, code, cost and attack
surface before the product has users.

## Decision

Use Firebase as the primary backend platform (spec §1): Firebase Auth,
Cloud Firestore, Cloud Functions, Cloud Storage, FCM, App Check,
Analytics + BigQuery, Crashlytics, Remote Config, Secret Manager. All
privileged operations run in small, domain-focused Cloud Functions in
`southamerica-east1`.

## Consequences

- The mobile client is untrusted; Firestore Security Rules + Cloud
  Functions form the trust boundary.
- Introducing NestJS (or any additional backend) requires a new ADR
  documenting the concrete need (CLAUDE.md constraint 13).
- Vendor lock-in is accepted for the MVP; the payment provider abstraction
  and the entitlement indirection keep the most volatile domain portable.
