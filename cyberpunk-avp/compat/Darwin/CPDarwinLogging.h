#include <syslog.h>

#ifdef __cplusplus
extern "C" {
#endif
// A real variadic forwarding entry; no original service behavior is implemented.
void CPDarwinSyslog(int priority, const char *format, ...) __attribute__((format(printf, 2, 3)));
#ifdef __cplusplus
}
#endif
