/*
 * readline() - read a full line from stdin into a null-terminated string,
 *              trimming the '\n' character
 *
 * Args: %rsi - buffer address
 *       %rdx - buffer size
 *
 * Returns: %rax - pointer to the null terminator
 *          %rbx - error code
 *          SF, !ZF - presence of an error
 */
.global readline
readline:
	xor %rax, %rax		# read
	xor %rdi, %rdi		# from stdin
	dec %rdx		# at most %rdx - 1 chars (1b reserved tor \0)
	syscall

	lea -1(%rax, %rsi), %rax # point at \n (buf[rax-1])
	cmpb $'\n', (%rax)
	jne .read_err
	movb $0, (%rax)		# trim newline
	xor %rbx, %rbx		# success
	ret
.read_err:
	mov $-1, %rbx		# default error code
	ret
