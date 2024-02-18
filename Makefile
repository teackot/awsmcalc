CC = as
LD = ld
CFLAGS = --64

all: debug

release: expr

debug: CFLAGS += -gdwarf-2
debug: expr

expr: expr.o fprint.o putchar.o stoi64.o u64tos.o
	$(LD) expr.o fprint.o putchar.o stoi64.o u64tos.o -o expr

expr.o: expr.S
	$(CC) $(CFLAGS) expr.S -o expr.o

fprint.o: fprint.S
	$(CC) $(CFLAGS) fprint.S -o fprint.o

putchar.o: putchar.S
	$(CC) $(CFLAGS) putchar.S -o putchar.o

stoi64.o: stoi64.S
	$(CC) $(CFLAGS) stoi64.S -o stoi64.o

u64tos.o: u64tos.S
	$(CC) $(CFLAGS) u64tos.S -o u64tos.o

clean:
	rm *.o
