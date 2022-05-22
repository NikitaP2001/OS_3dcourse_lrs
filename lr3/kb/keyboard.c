#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <linux/input.h>
#include <linux/uinput.h>

#include "table.h"


const char input_path[] = "/dev/input/event1";

int ev_write(void);

int main()
{
	int fd, status;
	struct input_event kb_ev;

	fd = open(input_path, O_RDWR);
	if (fd == -1) {
		fprintf(stderr, "[-] open event1: %s\n", strerror(errno));
		exit(1);
	}

	posix_fadvise(fd, 0, 0, POSIX_FADV_SEQUENTIAL);


	do {
		status = read(fd, &kb_ev, sizeof(kb_ev));
		if (status == -1) {
			fprintf(stderr, "[-] read event1: %s\n", strerror(errno));
			exit(1);
		}

		//printf("key event code: %d value: %d\n", kb_ev.code, kb_ev.value);
		if (kb_ev.type == EV_KEY && kb_ev.value > 0) {

			puts(keys[kb_ev.code]);
		}

	} while(status);

	close(fd);
	exit(0);
}

