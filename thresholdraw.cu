#include "project.h"

char *programName;

__device__
unsigned long deviceGetIntensity(Volume *volume, int x, int y, int z)
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

__device__
void deviceSetIntensity(Volume *volume, int x, int y, int z, unsigned long intensity)
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

__global__
void cudaThreshold(Volume *vol1, Volume *vol2, int n, unsigned long threshold, unsigned long low, unsigned long high)
{
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = gridDim.x * blockDim.x;
  for (int i = index; i < n; i += stride)
  /*
  int voxelsPerThread = (n + blockDim.x * gridDim.x - 1) / (blockDim.x * gridDim.x);
  int index = (blockIdx.x * blockDim.x + threadIdx.x) * voxelsPerThread;
  int endIndex = min(index + voxelsPerThread, n);
  for (int i = index; i < endIndex; i++)
  */
  {
    if (deviceGetIntensity(vol1, i, 0, 0) < threshold)
    {
      deviceSetIntensity(vol2, i, 0, 0, low);
    } else
    {
      deviceSetIntensity(vol2, i, 0, 0, high);
    }
  }
}

int main(int argc, char *argv[])
{
  programName = argv[0];
  if (argc < 4)
  {
    printf("Usage:\n");
    printf("    %s rawInput rawOutput threshold\n", programName);
    exit(0);
  }
  unsigned long threshold = atol(argv[3]);
  if (threshold == 0)
  {
    fprintf(stderr, "%s: invalid threshold: %s\n", programName, argv[3]);
    exit(0);
  }
  Volume *volume;
  cudaMallocManaged(&volume, sizeof(Volume));
  if (readRaw(volume, argv[1]) == -1)
  {
    exit(0);
  }
  Volume *tVol;
  cudaMallocManaged(&tVol, sizeof(Volume));
  tVol->width = volume->width;
  tVol->height = volume->height;
  tVol->depth = volume->depth;
  tVol->bytesPerPixel = 1;
  cudaMallocManagedVolume(tVol);
  struct cudaDeviceProp prop;
  int device, deviceCount;
  cudaGetDeviceCount(&deviceCount);
  printf("device count: %d\n", deviceCount);
  for (device = 0; device < deviceCount; device++)
  {
    //cudaGetDevice(&device);
    cudaGetDeviceProperties(&prop, device);
    printf("DEVICE NO. %d:\n", device);
    printf("    Name: %s, supports compute capability %d.%d.\n", prop.name, prop.major, prop.minor);
    printf("    This device can support %d threads per block, and it has %d multiprocessors.\n", prop.maxThreadsPerBlock, prop.multiProcessorCount);
  }
  cudaGetDevice(&device);
  cudaGetDeviceProperties(&prop, device);
  int numVoxels = volume->width * volume->height * volume->depth;
  int threadsPerBlock = prop.maxThreadsPerBlock;
  int numBlocks = (numVoxels + threadsPerBlock - 1) / threadsPerBlock;
  numBlocks = 24; // empirically found to be the best. I wonder why?
  printf("We will be using device number %d. We will be using %d blocks of %d threads each for a total of %d threads to threshold %d voxels\n", device, numBlocks, threadsPerBlock, numBlocks * threadsPerBlock, numVoxels);
  printf("Each thread will threshold at most %d voxels.\n", (numVoxels + numBlocks * threadsPerBlock - 1) / (numBlocks * threadsPerBlock));
  cudaThreshold<<<numBlocks, threadsPerBlock>>>(volume, tVol, numVoxels, threshold, 0, 255);
  cudaDeviceSynchronize();
  writeRaw(tVol, argv[2]);
  printf("wrote to raw file %s\n", argv[2]);
  cudaFree(volume->data);
  cudaFree(tVol->data);
  cudaFree(volume);
  cudaFree(tVol);
}
