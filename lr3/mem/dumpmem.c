#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>

const char mem_path[] = "/proc/2027/mem";
const char maps_path[] = "/proc/2027/maps";
const char namel_path[] = "/proc/2027/exe";

void read_region(int fd, uint64_t off_s, uint64_t off_e, char *wr_buf)
{
	if (lseek(fd, off_s, SEEK_SET) == -1) {
		fprintf(stderr, "[-] seek mem: %s\n", strerror(errno));
		exit(1);
	}

	if (read(fd, wr_buf, off_e - off_s) != off_e - off_s) {
		fprintf(stderr, "[-] read mem: %s\n", strerror(errno));
		exit(1);
	}

}

int main(int argc, char *argv[])
{
	char mapsbuf[1000];
	char full_name[PATH_MAX];
	char mem_path[PATH_MAX];
	char maps_path[PATH_MAX];
	char namel_path[PATH_MAX];
	int fd_mem, status;
	uint64_t off_beg, off_end, fbegrel = 0;
	FILE *fmaps, *fdump;

	if (argc < 2) {
		fprintf(stderr, "executable pid required\n");
		exit(1);
	}

	if (strlen(argv[1]) > 10) {
		puts("invalid pid");
		exit(1);
	}

	// fill path pattern with provided pid
	sprintf(mem_path, "/proc/%s/mem", argv[1]);
	sprintf(maps_path, "/proc/%s/maps", argv[1]);
	sprintf(namel_path, "/proc/%s/exe", argv[1]);



	// get executable name
	if (realpath(namel_path, full_name) == NULL) {
		fprintf(stderr, "[-] get exec name\n");
		exit(1);
	}

	fd_mem = open(mem_path, O_RDWR);
	if (fd_mem == -1) {
		fprintf(stderr, "[-] open mem: %s\n", strerror(errno));
		exit(1);
	}


	// dump all segments, that belongs to file
	fmaps = fopen(maps_path, "r");
	fdump = fopen("dump.bin", "wb");
	while (fgets(mapsbuf, 1000, fmaps) > 0) {
		// does this segment contain exec file name
		if (strstr(mapsbuf, full_name)) {
			sscanf(mapsbuf, "%lx-%lx", &off_beg, &off_end);
			uint64_t seg_sz = off_end - off_beg;

			if (fbegrel == 0)
				fbegrel = off_beg;

			char *mem_block = (char *)malloc(seg_sz);
			read_region(fd_mem, off_beg, off_end, mem_block);	
			if (fseek(fdump, off_beg - fbegrel, SEEK_SET) != 0) {
				fprintf(stderr, "[-] seek dump.bin: %s\n", strerror(errno));
				continue;
			}

			if (fwrite(mem_block, sizeof(char), seg_sz, fdump) != seg_sz) {
				fprintf(stderr, "[-] write dump: %s\n", strerror(errno));
				continue;
			}
				printf("DUMPED: %s", mapsbuf);
		}

	}

	fclose(fdump);
	fclose(fmaps);
	close(fd_mem);
	exit(0);

}

