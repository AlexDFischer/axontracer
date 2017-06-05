#include "project.h"

char *programName;

int main(int argc, char *argv[])
{
  programName = argv[0];
  if (argc < 4)
  {
    printf("Usage:\n");
    printf("    %s tiffDirectory threshold outputFile\n", programName);
    exit(0);
  }
  char *dirName = argv[1];
  unsigned long threshold = atol(argv[2]);
  if (threshold == 0)
  {
    fprintf(stderr, "%s: invalid threshold %s\n", programName, argv[2]);
    exit(0);
  }
  struct dirent **fileList;
  int numFiles = scandir(dirName, &fileList, tiffSelector, alphasort);
  if (numFiles == -1)
  {
    fprintf(stderr, "%s: unable to open directory %s\n", programName, dirName);
    exit(1);
  } else if (numFiles == 0)
  {
    fprintf(stderr, "%s: no TIFF files found in %s\n", programName, dirName);
    exit(2);
  }
  printf("found %d files\n", numFiles);

  // change working directory to directory of TIFF files
  char oldWorkingDirectory[1024];
  getcwd(oldWorkingDirectory, sizeof(oldWorkingDirectory));
  chdir(dirName);

  Volume volume;
  TIFF *slice = TIFFOpen(fileList[0]->d_name, "r");
  if (slice == NULL)
  {
    fprintf(stderr, "%s: unable to open TIFF file %s\n", programName, fileList[0]->d_name);
    exit(3);
  }
  TIFFGetField(slice, TIFFTAG_IMAGEWIDTH, &(volume.width));
  TIFFGetField(slice, TIFFTAG_IMAGELENGTH, &(volume.height));
  volume.depth = numFiles;
  if (!TIFFGetField(slice, TIFFTAG_SAMPLEFORMAT, &(volume.pixelFormat)))
  {
    volume.pixelFormat = SAMPLEFORMAT_UINT;
  }
  int bitsPerSample = 0;
  TIFFGetField(slice, TIFFTAG_BITSPERSAMPLE, &bitsPerSample);
  volume.bytesPerPixel = bitsPerSample / 8;
  mallocVolume(&volume);
  TIFFClose(slice);
  printf("we are dealing with a %dx%dx%d volume with %d bytes per pixel\n", volume.width, volume.height, volume.depth, volume.bytesPerPixel);

  // now read each slice
  int z;
  char *buf = volume.data;
  for (z = 0; z < numFiles; z++)
  {
    slice = TIFFOpen(fileList[z]->d_name, "r");
    if (slice == NULL)
    {
      fprintf(stderr, "%s: unable to open TIFF file %s\n", programName, fileList[z]->d_name);
      exit(3);
    }
    int numStrips = TIFFNumberOfStrips(slice);
    int strip;
    int bytesRead;
    for (strip = 0; strip < numStrips; strip++)
    {
      bytesRead = TIFFReadEncodedStrip(slice, strip, buf, (tsize_t)-1);
      if (bytesRead == -1)
      {
        fprintf(stderr, "%s: error reading tiff file %s\n", programName, fileList[z]->d_name);
        exit(3);
      }
      buf += bytesRead;
    }
    TIFFClose(slice);
  }
  chdir(oldWorkingDirectory);
  printf("loaded images successfully\n");
  // compute some statistics about the volume
  printf("min: %lu; max: %lu\n", minIntensity(&volume), maxIntensity(&volume));

  // compute the thresholded volume
  Volume tVol;
  tVol.width = volume.width;
  tVol.height = volume.height;
  tVol.depth = volume.depth;
  tVol.bytesPerPixel = 1;
  mallocVolume(&tVol);
  int x, y;
  for (z = 0; z < volume.depth; z++)
  {
    for (y = 0; y < volume.height; y++)
    {
      for (x = 0; x < volume.width; x++)
      {
        setIntensity(&tVol, x, y, z, getIntensity(&volume, x, y, z) >= threshold ? 255 : 0);
      }
    }
  }
  printf("min: %lu; max: %lu\n", minIntensity(&tVol), maxIntensity(&tVol));
  writeRaw(&tVol, argv[3]);

  free(fileList);
  _TIFFfree(volume.data);
}
