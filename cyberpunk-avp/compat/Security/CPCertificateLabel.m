#import "CPCertificateLabel.h"
#import <Foundation/Foundation.h>

typedef struct { const uint8_t *p; size_t n; } CPSpan;
// Consume one definite, minimally encoded DER TLV without reading past its span.
static BOOL Take(CPSpan *input, uint8_t *tag, CPSpan *value) {
    if (input->n < 2) return NO;
    const uint8_t *p = input->p;
    *tag = p[0];
    if ((*tag & 31) == 31) return NO;
    size_t header = 2, length = p[1];
    if (length & 128) {
        size_t count = length & 127;
        if (!count || count > sizeof(size_t) || count > input->n - 2 || !p[2]) return NO;
        length = 0;
        for (size_t i = 0; i < count; i++) {
            if (length > (SIZE_MAX >> 8)) return NO;
            length = (length << 8) | p[2+i];
        }
        if (length < 128) return NO;
        header += count;
    }
    if (length > input->n - header) return NO;
    *value = (CPSpan){p + header, length};
    input->p += header + length; input->n -= header + length;
    return YES;
}
static NSString *Text(uint8_t tag, CPSpan value) {
    NSStringEncoding encoding;
    switch (tag) {
        case 12: encoding = NSUTF8StringEncoding; break;
        case 19: case 22: case 18: encoding = NSASCIIStringEncoding; break;
        case 20: encoding = NSISOLatin1StringEncoding; break;
        case 30: encoding = NSUTF16BigEndianStringEncoding; break;
        case 28: encoding = NSUTF32BigEndianStringEncoding; break;
        default: return nil;
    }
    if (tag != 20 && tag != 30 && tag != 28 && value.n && value.p[value.n-1] == 0) value.n--;
    NSString *s = [[NSString alloc] initWithBytes:value.p length:value.n encoding:tag == 20 ? NSUTF8StringEncoding : encoding];
    if (!s && tag == 20) s = [[NSString alloc] initWithBytes:value.p length:value.n encoding:encoding];
    return s;
}
CFStringRef CPCertificateCopySubjectLabel(SecCertificateRef certificate, CFErrorRef *error) {
    if (error) *error = NULL;
    OSStatus status = errSecParam;
    if (!certificate || CFGetTypeID(certificate) != SecCertificateGetTypeID()) goto fail;
    {
        CFDataRef data = SecCertificateCopyData(certificate);
        if (!data) { status = errSecDecode; goto fail; }
        NSData *bytes = CFBridgingRelease(data);
        CPSpan input = {(const uint8_t *)bytes.bytes, bytes.length}, outer, tbs, field;
        uint8_t tag;
        status = errSecDecode;
        if (!Take(&input, &tag, &outer) || tag != 48 || input.n || !Take(&outer, &tag, &tbs) || tag != 48) goto fail;
        if (!Take(&tbs, &tag, &field)) goto fail;
        if (tag == 160 && !Take(&tbs, &tag, &field)) goto fail;
        if (tag != 2) goto fail; // serial, signature algorithm, issuer, validity, subject
        for (int i = 0; i < 4; i++) if (!Take(&tbs, &tag, &field) || tag != 48) goto fail;
        NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary new];
        NSString *first = nil;
        while (field.n) {
            CPSpan set;
            if (!Take(&field, &tag, &set) || tag != 49) goto fail;
            while (set.n) {
                CPSpan pair, oid, value;
                if (!Take(&set, &tag, &pair) || tag != 48 || !Take(&pair, &tag, &oid) || tag != 6 || !Take(&pair, &tag, &value) || pair.n) goto fail;
                NSString *text = Text(tag, value);
                if (!text) continue;
                if (!first) first = text;
                NSString *key = nil;
                if (oid.n == 3 && oid.p[0] == 85 && oid.p[1] == 4) key = [NSString stringWithFormat:@"%u", oid.p[2]];
                static const uint8_t emailOID[] = {42,134,72,134,247,13,1,9,1};
                if (oid.n == sizeof(emailOID) && !memcmp(oid.p,emailOID,sizeof(emailOID))) key = @"email";
                if (key && !names[key]) names[key] = text;
            }
        }
        NSString *label = names[@"3"] ?: names[@"11"] ?: names[@"10"] ?: names[@"email"] ?: first ?: @"X509 Certificate";
        if ([label isEqualToString:@"Thawte Freemail Member"]) { status = errSecUnimplemented; goto fail; }
        if (names[@"3"] && names[@"13"].length) label = [NSString stringWithFormat:@"%@ (%@)", label, names[@"13"]];
        return CFBridgingRetain(label);
    }
fail:
    if (error) *error = CFErrorCreate(NULL, kCFErrorDomainOSStatus, status, NULL);
    return NULL;
}
