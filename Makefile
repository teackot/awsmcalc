CC = as
LD = ld
CFLAGS = --64

all: debug

release: expr

debug: CFLAGS += -gdwarf-2
debug: expr

expr: expr.o fprint.o putchar.o readline.o stoi64.o u64tos.o fj.o
	$(LD) expr.o fprint.o putchar.o readline.o stoi64.o u64tos.o fj.o -o expr

expr.o: expr.S
	$(CC) $(CFLAGS) expr.S -o expr.o

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

clean:
	rm *.o
