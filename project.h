#include <tiffio.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

extern char *programName;

int tiffSelector(const struct dirent *);

struct Volume
{
  int width, height, depth, pixelFormat, bytesPerPixel;
  char *data;
};

typedef struct Volume Volume;

#ifdef __CUDACC__
__device__
unsigned long deviceGetIntensity(Volume *volume, int x, int y, int z);
#endif
unsigned long getIntensity(Volume *volume, int x, int y, int z);

#ifdef __CUDACC__
__device__
void deviceSetIntensity(Volume *volume, int x, int y, int z, unsigned long intensity);
#endif
void setIntensity(Volume *volume, int x, int y, int z, unsigned long intensity);

void cudaMallocManagedVolume(Volume *volume);

void _TIFFMallocVolume(Volume *volume);

void mallocVolume(Volume *volume);

unsigned long maxIntensity(Volume *volume);

unsigned long minIntensity(Volume *volume);

void printVolume(Volume *volume);

int readRaw(Volume *volume, char *fileName);

int writeRaw(Volume *volume, char *fileName);
