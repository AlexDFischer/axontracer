#include "project.h"

unsigned long getIntensity(Volume *volume, int x, int y, int z)
{
  size_t index = z * volume->width * volume->height + y * volume->width + x;
  unsigned long result = 0;
  switch (volume->bytesPerPixel)
  {
    case 1:
      return ((uint8_t *) (volume->data))[index];
    case 2:
      return ((uint16_t *) (volume->data))[index];
    case 4:
      return ((uint32_t *) (volume->data))[index];
    case 8:
      return ((uint64_t *) (volume->data))[index];
  }
  return result;
}

void setIntensity(Volume *volume, int x, int y, int z, unsigned long intensity)
{
  size_t index = z * volume->width * volume->height + y * volume->width + x;
  switch (volume->bytesPerPixel)
  {
    case 1:
      ((uint8_t *) (volume->data))[index] = intensity;
      break;
    case 2:
      ((uint16_t *) (volume->data))[index] = intensity;
      break;
    case 4:
      ((uint32_t *) (volume->data))[index] = intensity;
      break;
    case 8:
      ((uint64_t *) (volume->data))[index] = intensity;
      break;
  }
}

void cudaMallocManagedVolume(Volume *volume)
{
  cudaMallocManaged(&(volume->data), volume->width * volume->height * volume->depth * volume->bytesPerPixel);
}

void _TIFFMallocVolume(Volume *volume)
{
  volume->data = (char *) _TIFFmalloc(volume->width * volume->height * volume->depth * volume->bytesPerPixel);
}

void mallocVolume(Volume *volume)
{
  volume->data = (char *) malloc(volume->width * volume->height * volume->depth * volume->bytesPerPixel);
}

unsigned long maxIntensity(Volume *volume)
{
  int x, y, z;
  unsigned long max = getIntensity(volume, 0, 0, 0);
  for (z = 0; z < volume->depth; z++)
  {
    for (y = 0; y < volume->height; y++)
    {
      for (x = 0; x < volume->width; x++)
      {
        unsigned long val = getIntensity(volume, x, y, z);
        if (val > max)
        {
          max = val;
        }
      }
    }
  }
  return max;
}

unsigned long minIntensity(Volume *volume)
{
  int x, y, z;
  unsigned long min = getIntensity(volume, 0, 0, 0);
  for (z = 0; z < volume->depth; z++)
  {
    for (y = 0; y < volume->height; y++)
    {
      for (x = 0; x < volume->width; x++)
      {
        unsigned long val = getIntensity(volume, x, y, z);
        if (val < min)
        {
          min = val;
        }
      }
    }
  }
  return min;
}

void printVolume(Volume *volume)
{
  int x, y, z;
  for (z = 0; z < volume->depth; z++)
  {
    printf("SLICE %d\n", z);
    for (y = 0; y < volume->height; y++)
    {
      for (x = 0; x < volume->width; x++)
      {
        printf("%02lx ", getIntensity(volume, x, y, z));
      }
      printf("\n");
    }
  }
}

/**
 * Reads the given RAW file into the given volume. volume->data is
 * cudaMallocManaged and should be cudaFreed when done. fileName should not have
 * an extension, as the RAW and TXT extensions will be added onto it.
 */
int readRaw(Volume *volume, char *fileName)
{
  int len = strlen(fileName);
  char *fileNameExt = (char *) malloc(len + 5);
  strcpy(fileNameExt, fileName);
  strcpy(fileNameExt + len, ".txt");
  FILE *f = fopen(fileNameExt, "r");
  if (f == NULL)
  {
    fprintf(stderr, "%s: unable to open file %s: %s\n", programName, fileNameExt, strerror(errno));
    return -1;
  }
  if (fscanf(f, "%dx%dx%d\n", &(volume->width), &(volume->height), &(volume->depth)) != 3)
  {
    fprintf(stderr, "%s: invalid first line of %s\n", programName, fileNameExt);
    return -1;
  }
  if (fscanf(f, "%d\n", &(volume->bytesPerPixel)) != 1)
  {
    fprintf(stderr, "%s: invalid second line of %s\n", programName, fileNameExt);
    return -1;
  }
  int scaleX, scaleY, scaleZ;
  if (fscanf(f, "scale: %d:%d:%d", &scaleX, &scaleY, &scaleZ) != 3)
  {
    fprintf(stderr, "%s: invalid third line of %s\n", programName, fileNameExt);
    return -1;
  }
  if (fclose(f))
  {
    fprintf(stderr, "%s: unable to close file %s: %s\n", programName, fileNameExt, strerror(errno));
    return -1;
  }
  cudaMallocManagedVolume(volume);
  strcpy(fileNameExt + len, ".raw");
  f = fopen(fileNameExt, "r");
  fread(volume->data, volume->bytesPerPixel, volume->width * volume->height * volume->depth, f);
  if (ferror(f))
  {
    fprintf(stderr, "%s: error reading from file %s: %s\n", programName, fileNameExt, strerror(ferror(f)));
    return -1;
  }
  free(fileNameExt);
  return 0;
}

/**
 * Writes the given volume to the given RAW file. fileName should not have an
 * extension, as the RAW and TXT extensions will be added onto it.
 */
int writeRaw(Volume *volume, char *fileName)
{
  int len = strlen(fileName);
  char *fileNameExt = (char *) malloc(len + 5);
  strcpy(fileNameExt, fileName);
  strcpy(fileNameExt + len, ".txt");
  FILE *f = fopen(fileNameExt, "w");
  if (f == NULL)
  {
    fprintf(stderr, "%s: unable to open file %s: %s\n", programName, fileNameExt, strerror(errno));
    return -1;
  }
  fprintf(f, "%dx%dx%d\n", volume->width, volume->height, volume->depth);
  fprintf(f, "%d\n", volume->bytesPerPixel);
  fprintf(f, "scale: 1:1:1\n");
  if (ferror(f))
  {
    fprintf(stderr, "%s: error writing to file %s: %s\n", programName, fileNameExt, strerror(ferror(f)));
    return -1;
  }
  fclose(f);
  strcpy(fileNameExt + len, ".raw");
  f = fopen(fileNameExt, "w");
  if (f == NULL)
  {
    fprintf(stderr, "%s: unable to open file %s: %s\n", programName, fileNameExt, strerror(errno));
    return -1;
  }
  fwrite(volume->data, volume->bytesPerPixel, volume->width * volume->height * volume->depth, f);
  if (ferror(f))
  {
    fprintf(stderr, "%s: error writing to file %s: %s\n", programName, fileNameExt, strerror(ferror(f)));
    return -1;
  }
  fclose(f);
  free(fileNameExt);
  return 0;
}
