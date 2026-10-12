#import "CPDesktopSecurity.h"
#import "CPClientIdentity.h"
#import "CPPublicKeyExport.h"
#import "CPCertificateLabel.h"
#import <Foundation/Foundation.h>
#include <stddef.h>
_Static_assert(sizeof(CPDesktopKeyParameters) == 56, "desktop ARM64 key parameters size");
_Static_assert(offsetof(CPDesktopKeyParameters, passphrase) == 8, "passphrase offset");

OSStatus CPDesktopItemImport(CFDataRef data, CFStringRef filename, uint32_t *format,
                            uint32_t *type, uint32_t flags, const CPDesktopKeyParameters *params,
                            CFTypeRef keychain, CFArrayRef *items) {
    if (items) *items = NULL;
    if (!items) return errSecParam;
    if (filename || !format || *format != 12 || !type || *type != 4 || flags || keychain ||
        (params && (params->version || params->flags || params->alertTitle || params->alertPrompt ||
                    params->accessRef || params->keyUsage || params->keyAttributes))) return errSecUnimplemented;
    return CPImportPKCS12ToMemory(data, params ? (CFStringRef)params->passphrase : NULL, items);
}
OSStatus CPDesktopItemExport(CFTypeRef key, uint32_t format, uint32_t flags,
                            const CPDesktopKeyParameters *params, CFDataRef *data) {
    if (data) *data = NULL;
    if (!data) return errSecParam;
    if (format != 1 || flags || params) return errSecUnimplemented;
    CFErrorRef error = NULL;
    CFDataRef result = CPKeyCopyDesktopOpenSSLRepresentation((SecKeyRef)key, &error);
    OSStatus status = result ? errSecSuccess : error ? (OSStatus)CFErrorGetCode(error) : errSecDecode;
    if (error) CFRelease(error);
    *data = result;
    return status;
}
OSStatus CPDesktopIdentityCreateWithCertificate(CFTypeRef searchList, SecCertificateRef certificate,
                                               SecIdentityRef *identity) {
    if (identity) *identity = NULL;
    if (!identity || !certificate || CFGetTypeID(certificate) != SecCertificateGetTypeID()) return errSecParam;
    if (searchList) return errSecUnimplemented;
    // Real read-only lookup is limited to this application's native keychain scope.
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassIdentity,
                            (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitAll,
                            (__bridge id)kSecReturnRef:@YES};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess) {
        if (result && CFGetTypeID(result) == CFArrayGetTypeID())
            status = CPIdentityCopyMatchingCertificate((CFArrayRef)result, certificate, identity);
        else status = errSecDecode;
    }
    if (result) CFRelease(result);
    return status;
}
CFStringRef CPDesktopCertificateCopyLongDescription(CFAllocatorRef allocator,
                                                   SecCertificateRef certificate, CFErrorRef *error) {
    if (allocator) {
        if (error) *error = CFErrorCreate(NULL, kCFErrorDomainOSStatus, errSecUnimplemented, NULL);
        return NULL;
    }
    return CPCertificateCopySubjectLabel(certificate, error);
}
