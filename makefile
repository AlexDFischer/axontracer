CC=nvcc
CFLAGS=-I/home/afis/lib/libtiff/include
LIBTIFFFLAGS=-L/home/afis/lib/libtiff/lib -ltiff
DEPS = project.h
OBJ = fileutils.o volume.o

%.o: %.cu $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

tiffloader: tiffloader.cu $(OBJ)
	$(CC) -o tiffloader $^ $(CFLAGS) $(LIBTIFFFLAGS)

tifftoraw: tifftoraw.cu $(OBJ)
	$(CC) -o tifftoraw $^ $(CFLAGS) $(LIBTIFFFLAGS)

thresholdraw: thresholdraw.cu $(OBJ)
	$(CC) -o thresholdraw $^ $(CFLAGS) $(LIBTIFFFLAGS)

clean:
	rm $(OBJ)
