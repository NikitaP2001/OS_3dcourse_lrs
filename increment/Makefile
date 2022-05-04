TARGET = inc

CFLAGS = -f elf64
LDFLAGS = 

CC=nasm
LD=ld

SOURCES = $(wildcard *.asm)
OBJECTS = $(SOURCES:.asm=.o)

%.o: %.asm
	$(CC) $(CFLAGS) -o $@ $<
	
all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $(LDLIBS) $^

clean:
	rm *.o
