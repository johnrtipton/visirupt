#import <Security/Security.h>

// Own bounded subject-label implementation. Retained result; no trust decision.
CFStringRef CPCertificateCopySubjectLabel(SecCertificateRef certificate,
                                         CFErrorRef *error) CF_RETURNS_RETAINED;
