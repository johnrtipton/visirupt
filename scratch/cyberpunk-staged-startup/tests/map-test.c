#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <string.h>
#include "FileTrace.h"
int main(int argc,char **argv){
 if(argc!=3||!CPFileTraceBegin(argv[2])||!CPFileTraceMapData("/never-existing-game/Data",argv[1]))return 1;
 int f=open("/never-existing-game/Data/read.bin",O_RDONLY);char b[3];if(f<0||read(f,b,3)!=3||memcmp(b,"abc",3))return 2;close(f);
 struct stat s;if(stat("/never-existing-game/Data/read.bin",&s)||s.st_size!=3)return 3;
 if(access("/never-existing-game/Data/read.bin",R_OK))return 4;
 DIR *d=opendir("/never-existing-game/Data");if(!d)return 5;closedir(d);
 if(open("/never-existing-game/Data/missing",O_RDONLY)!=-1||errno!=ENOENT)return 6;
 if(open("/never-existing-game/Data2/read.bin",O_RDONLY)!=-1||errno!=ENOENT)return 7;
 if(open((const char *)1,O_RDONLY)!=-1||errno!=EFAULT)return 8;
 puts("PASS mapped original bytes, stat/access/directory, missing paths, prefix boundary and invalid pointer");return 0;
}
