/*
 * putchar() - prints a character to stdout
 *
 * Args: %rax - character
 */
.global putchar
putchar:
	push %rax

	mov $1, %rax		# sys_write
	mov $1, %rdi		# to stdout
	mov %rsp, %rsi		# from the stack
	mov $1, %rdx		# 1 char
	syscall

	add $8, %rsp
	ret
