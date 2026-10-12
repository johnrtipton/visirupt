#define _DARWIN_C_SOURCE 1
#include "MemoryTrace.h"
#include <dlfcn.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <stdatomic.h>

static void *(*nativeMap)(void *,size_t,int,int,int,off_t);
static int (*nativeAdvice)(void *,size_t,int);
static int traceFD=-1;
static _Atomic int phase;
static unsigned long long sequence;
static pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;

static void Write(const char *line, size_t size) {
    if(traceFD<0)return;
    while(size) {
        ssize_t count=write(traceFD,line,size);
        if(count<0 && errno==EINTR)continue;
        if(count<=0)break;
        line+=count;size-=(size_t)count;
    }
}
void CPMemoryTracePhase(int value) {
    int saved=errno;
    atomic_store(&phase,value);
    errno=saved;
}
int CPMemoryTraceBegin(const char *path) {
    int saved=errno;
    void *system=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW|RTLD_LOCAL);
    if(!system)return 0;
    nativeMap=(void *(*)(void *,size_t,int,int,int,off_t))dlsym(system,"mmap");
    nativeAdvice=(int (*)(void *,size_t,int))dlsym(system,"madvise");
    Dl_info mapInfo={0}, adviceInfo={0};
    if(!nativeMap || !nativeAdvice || !dladdr((void *)nativeMap,&mapInfo) || !dladdr((void *)nativeAdvice,&adviceInfo) || !mapInfo.dli_fname || !adviceInfo.dli_fname || strncmp(mapInfo.dli_fname,"/usr/lib/",9) || strncmp(adviceInfo.dli_fname,"/usr/lib/",9))return 0;
    traceFD=open(path,O_CREAT|O_TRUNC|O_WRONLY,0600);
    if(traceFD<0)return 0;
    char line[1024];
    int length=snprintf(line,sizeof(line),"{\"event\":\"native_providers\",\"mmap_image\":\"%s\",\"madvise_image\":\"%s\",\"arguments_and_native_results_preserved\":true}\n",mapInfo.dli_fname,adviceInfo.dli_fname);
    if(length<=0 || (size_t)length>=sizeof(line)){close(traceFD);traceFD=-1;return 0;}
    Write(line,(size_t)length);errno=saved;return 1;
}

void *CPObservedMmap(void *,size_t,int,int,int,off_t) __asm__("_mmap");
void *CPObservedMmap(void *address,size_t length,int protection,int flags,int fd,off_t offset) {
    if(!nativeMap){errno=ENOSYS;return MAP_FAILED;}
    void *result=nativeMap(address,length,protection,flags,fd,offset);
    int nativeErrno=errno;
    if(length>=((size_t)1<<30) || result==MAP_FAILED || phase==0) {
        char line[512];
        pthread_mutex_lock(&lock);
        int count=snprintf(line,sizeof(line),"{\"event\":\"mmap\",\"sequence\":%llu,\"phase\":%d,\"requested_address\":\"0x%llx\",\"length\":%llu,\"protection\":%d,\"flags\":%d,\"fd\":%d,\"offset\":%lld,\"result\":\"0x%llx\",\"failed\":%s,\"errno_after_native_call\":%d}\n",++sequence,phase,(unsigned long long)(uintptr_t)address,(unsigned long long)length,protection,flags,fd,(long long)offset,(unsigned long long)(uintptr_t)result,result==MAP_FAILED?"true":"false",nativeErrno);
        if(count>0 && (size_t)count<sizeof(line))Write(line,(size_t)count);
        pthread_mutex_unlock(&lock);
    }
    errno=nativeErrno;return result;
}
int CPObservedMadvise(void *,size_t,int) __asm__("_madvise");
int CPObservedMadvise(void *address,size_t length,int advice) {
    if(!nativeAdvice){errno=ENOSYS;return -1;}
    int result=nativeAdvice(address,length,advice);
    int nativeErrno=errno;
    if(result || length>=65536 || phase==0) {
        char line[384];
        pthread_mutex_lock(&lock);
        int count=snprintf(line,sizeof(line),"{\"event\":\"madvise\",\"sequence\":%llu,\"phase\":%d,\"address\":\"0x%llx\",\"length\":%llu,\"advice\":%d,\"result\":%d,\"errno_after_native_call\":%d}\n",++sequence,phase,(unsigned long long)(uintptr_t)address,(unsigned long long)length,advice,result,nativeErrno);
        if(count>0 && (size_t)count<sizeof(line))Write(line,(size_t)count);
        pthread_mutex_unlock(&lock);
    }
    errno=nativeErrno;return result;
}
int CPMemoryTraceControls(void) {
    size_t page=(size_t)sysconf(_SC_PAGESIZE), length=(size_t)8<<20;
    errno=EDOM;
    void *direct=nativeMap(NULL,length,PROT_READ|PROT_WRITE,MAP_ANON|MAP_PRIVATE,-1,0);
    int directError=errno;
    errno=EDOM;
    void *observed=CPObservedMmap(NULL,length,PROT_READ|PROT_WRITE,MAP_ANON|MAP_PRIVATE,-1,0);
    int observedError=errno;
    int ok=direct!=MAP_FAILED && observed!=MAP_FAILED && directError==observedError;
    if(direct!=MAP_FAILED)munmap(direct,length);
    if(observed!=MAP_FAILED) {
        volatile unsigned char *byte=observed;*byte=0x5a;ok=ok && *byte==0x5a;
        errno=EDOM;int a=nativeAdvice(observed,page,MADV_FREE_REUSE), ae=errno;
        errno=EDOM;int b=CPObservedMadvise(observed,page,MADV_FREE_REUSE), be=errno;
        ok=ok && a==0 && a==b && ae==be;
        munmap(observed,length);
    }
    errno=EDOM;int a=nativeAdvice(MAP_FAILED,page,MADV_FREE_REUSE), ae=errno;
    errno=EDOM;int b=CPObservedMadvise(MAP_FAILED,page,MADV_FREE_REUSE), be=errno;
    ok=ok && a==-1 && a==b && ae==be;
    char line[192];int count=snprintf(line,sizeof(line),"{\"event\":\"controls\",\"passed\":%s,\"native_invalid_advice_result\":%d,\"native_invalid_advice_errno\":%d}\n",ok?"true":"false",a,ae);
    Write(line,(size_t)count);
    return ok;
}
