/// THE INVESTOR DEMO BUILD (owner, 2026-11-15). This file exists only on
/// the `demo` branch: the client shows the app to investors, so every
/// professional assistant (doctor, advocate, business) is on Home without
/// choosing a profession, and the profession step is skipped at sign-up.
///
/// Opening an assistant switches the account's profession to it first, so
/// the server's per-profession checks pass on the same production backend.
const bool kDemoApp = true;
