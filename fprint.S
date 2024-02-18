/*
 * print() - fprint() with fd = 1 (stdout)
 *
 * Args: %rsi - string pointer
 */
.global print
print:
	mov $1, %rdi		# stdout
/*
 * fprint() - prints a null-terminated string to fd
 *
 * Args: %rsi - string pointer
 *       %rdi - fd
 */
.global fprint
fprint:
	mov $1, %rdx		# 1 char at a time
.next:
	movb (%rsi), %al	# get a char
	test %al, %al		# check for \0
	jz .printed
	mov $1, %rax		# sys_write
	syscall
	inc %rsi
	jmp .next
.printed:
	ret
