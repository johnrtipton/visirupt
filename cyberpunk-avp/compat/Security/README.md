# Native Security components

`CPPublicKeyExport` is an own bounded public-key export adapter. It calls real native SecKey APIs, obtains the real public-key bytes, and constructs standard DER SubjectPublicKeyInfo for RSA and P-256/P-384/P-521. It does not evaluate trust, compare a configured pin, change authentication, import a private key, or alter a game library. It has no original SecItemExport compatibility alias and is not in any original loader.

Independent Mac Security `SecItemExport(..., kSecFormatOpenSSL, 0, NULL, ...)` reference bytes were generated from temporary in-memory keys. Only public bytes were saved. Six cases (RSA1024/2048/4096 and EC256/384/521) match the own encoder byte for byte on Mac and actual visionOS27 simulator Security. Each runtime passes20 checks: native public-key import, exact SPKI bytes, matching hash/changed-byte hash mismatch, NULL and incorrect object type errors. Native device compilation passes; physical execution is pending. Hash checks are fixtures, not original Galaxy pinning or a live TLS handshake.

RSA native raw data is PKCS#1; EC raw data is the X9.63 point. Returning those raw bytes directly would change the original Galaxy pin input. The encoder emits the current desktop SPKI form:162/294/550 bytes for tested RSA sizes and91/120/158 for tested EC sizes. Galaxy's existing handling of older raw RSA270/526-byte exports remains unchanged because no Galaxy instructions are modified.

The adapter accepts public SecKey objects only. Unsupported algorithms/curves fail explicitly with errSecUnimplemented; invalid inputs fail with errSecParam; native export errors are retained. Full SecItemExport formats, flags, private keys, memory-failure behavior and other algorithms are not claimed. Normal native ownership requires CFRelease on a successful returned CFData or error.

Fixtures and reproducible build scripts are in `scratch/cyberpunk-native-security-fixture/`. Client identity import/lookup and certificate description remain separate contracts under investigation. No four-provider Galaxy map or load is approved by this component's test result alone.

Own subject-label and client-identity components now exist separately. See research/certificate-label-adapter-2026-10-11.md and research/client-identity-adapter-2026-10-11.md for bounded runtime coverage and remaining integration limits. Neither provides original desktop aliases or loads Galaxy yet.
