#include "CPDarwinLogging.h"
#include <stdarg.h>

void CPDarwinSyslog(int priority, const char *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    vsyslog(priority, format, arguments);
    va_end(arguments);
}
