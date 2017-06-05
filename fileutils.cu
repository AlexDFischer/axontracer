#include "project.h"

int tiffSelector(const struct dirent *file)
{
  int len = strlen(file->d_name);
  return (strcmp(file->d_name + len - 4, ".tif") == 0) || ((strcmp(file->d_name + len - 5, ".tiff") == 0));
}
