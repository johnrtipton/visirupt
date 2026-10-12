#import <Security/Security.h>
CF_ASSUME_NONNULL_BEGIN
// Copies OpenSSL public-key SPKI bytes for the actual native SecKey object.
// This is an own bounded adapter, not a replacement for SecItemExport's full API.
CFDataRef _Nullable CPKeyCopyDesktopOpenSSLRepresentation(SecKeyRef _Nullable key, CFErrorRef _Nullable * _Nullable error) CF_RETURNS_RETAINED;
CF_ASSUME_NONNULL_END
