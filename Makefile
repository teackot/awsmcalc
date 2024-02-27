CC = as
LD = ld
CFLAGS = --64

all: debug

release: expr

debug: CFLAGS += -gdwarf-2
debug: expr

expr: main.o fprint.o putchar.o readline.o stoi64.o u64tos.o fj.o strcmp.o skip_ws.o parse.o
	$(LD) main.o fprint.o putchar.o readline.o stoi64.o u64tos.o fj.o strcmp.o skip_ws.o parse.o -o expr

main.o: main.S
	$(CC) $(CFLAGS) main.S -o main.o

fprint.o: fprint.S
	$(CC) $(CFLAGS) fprint.S -o fprint.o

putchar.o: putchar.S
	$(CC) $(CFLAGS) putchar.S -o putchar.o

readline.o: readline.S
	$(CC) $(CFLAGS) readline.S -o readline.o

stoi64.o: stoi64.S
	$(CC) $(CFLAGS) stoi64.S -o stoi64.o

u64tos.o: u64tos.S
	$(CC) $(CFLAGS) u64tos.S -o u64tos.o

fj.o: fj.S
	$(CC) $(CFLAGS) fj.S -o fj.o

strcmp.o: strcmp.S
	$(CC) $(CFLAGS) strcmp.S -o strcmp.o

skip_ws.o: skip_ws.S
	$(CC) $(CFLAGS) skip_ws.S -o skip_ws.o

parse.o: parse.S
	$(CC) $(CFLAGS) parse.S -o parse.o

clean:
	rm *.o
