# Security notes

LifeRoute is intentionally being prepared for calendar and scheduling providers before their credentials are added.

- Provider secrets must not be committed to the repository.
- App Store Connect credentials belong in GitHub Actions Secrets.
- Google Calendar should use read-only calendar permission unless the product scope changes.
- CentralReach schedule integration is intended to use GET/read operations only.
- CentralReach client secrets, API keys, JWTs, and schedule payloads should not be stored in WebView localStorage.
- Before CentralReach is activated, provider-fed schedule events should be kept ephemeral or moved to an approved encrypted/native persistence layer if offline caching is required.
- Avoid logging provider payloads that may contain private calendar or client information.
