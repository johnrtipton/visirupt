#import <Security/Security.h>
#include <stdint.h>
typedef struct {
    uint32_t version, flags;
    CFTypeRef passphrase;
    CFStringRef alertTitle, alertPrompt;
    CFTypeRef accessRef;
    CFArrayRef keyUsage, keyAttributes;
} CPDesktopKeyParameters;
OSStatus CPDesktopItemImport(CFDataRef, CFStringRef, uint32_t *, uint32_t *, uint32_t,
                            const CPDesktopKeyParameters *, CFTypeRef, CFArrayRef *);
OSStatus CPDesktopItemExport(CFTypeRef, uint32_t, uint32_t,
                            const CPDesktopKeyParameters *, CFDataRef *);
OSStatus CPDesktopIdentityCreateWithCertificate(CFTypeRef, SecCertificateRef, SecIdentityRef *);
CFStringRef CPDesktopCertificateCopyLongDescription(CFAllocatorRef, SecCertificateRef,
                                                  CFErrorRef *) CF_RETURNS_RETAINED;
