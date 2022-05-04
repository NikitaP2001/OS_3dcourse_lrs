TARGET = main

CFLAGS = -c
LDFLAGS =

CC=c++
LD=c++

SOURCES = $(wildcard *.cpp)
OBJECTS = $(SOURCES:.cpp=.o)

%.o: %.cpp
	$(CC) $(CFLAGS) -o $@ $<

all: CFLAGS += -DDEBUG
all: $(TARGET) 

release: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $(LDLIBS) $^

clean:
	rm *.o
