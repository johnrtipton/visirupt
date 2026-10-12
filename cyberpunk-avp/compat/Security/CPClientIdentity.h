#import <Security/Security.h>

// Retained native import dictionaries; native OSStatus is preserved.
OSStatus CPImportPKCS12ToMemory(CFDataRef data, CFStringRef passphrase,
                               CFArrayRef *items);
// Match only caller-provided genuine identities, without a keychain search.
OSStatus CPIdentityCopyMatchingCertificate(CFArrayRef importedItems,
                                         SecCertificateRef certificate,
                                         SecIdentityRef *identity);
