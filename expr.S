.section .rodata

prompt:		.ascii "x = \0"
expr_ge16:	.ascii "(x - 11)^2 + 125 = \0"
expr_l16:	.ascii "x^2 + 72x + 6400 = \0"

err_read:	.ascii "Could not read the input!\n\0"
err_nan:	.ascii "You should enter a non-negative integer!\n\0"

.section .data

buf:		.fill 64
buf_len = .-buf

inp_x:		.quad 1

.section .text
.global _start
_start:
	# print the prompt
	mov $prompt, %rsi
	call print

	xor %rax, %rax		# read
	xor %rdi, %rdi		# from stdin
	mov $buf, %rsi		# into buf
	mov $buf_len-1, %rdx	# at most buf_len chars (1b reserved tor \0)
	syscall

	add $buf-1, %rax	# point at \n (buf[rax-1])
	cmpb $'\n', (%rax)
	je .read_success
	mov $err_read, %rsi	# | no \n, panic with a read error
	jmp panic		# |
.read_success:
	movb $0, (%rax)		# trim newline

	mov $buf, %rsi		# convert buf
	mov $10, %rbx		# base 10
	call stoi64		# to u64

	test %rbx, %rbx		# check for stou64 errors
	jz .u64_success
	mov $err_nan, %rsi
	call print
	jmp _start
.u64_success:

	cmp $16, %rax
	jl .l16
	
.ge16:
	pushq $expr_ge16	# use a register?

	sub $11, %rax		# t = x - 11
	mul %rax		# t = t^2
	add $125, %rax		# t += 125

	jmp .done

.l16:
	pushq $expr_l16		# use a register?

	mov %rax, %rcx		# tmp %rcx = x

	mul %rax		# x^2
	mov %rax, %rbx		# %rbx = x^2

	mov %rcx, %rax		# | %rax = 72x
	mov $72, %rcx		# |
	mul %rcx		# |

	add %rbx, %rax		# %rbx + %rax = x^2 + 72x
	add $6400, %rax		# + 6400

.done:
	mov $10, %rbx		# base 10
	mov $buf, %rdi		# into the buf
	call u64tos		# rax to string

	# print the expression
	popq %rsi		# use a register?
	call print

	# print the result
	mov $buf, %rsi
	call print

	mov $'\n', %rax
	call putchar

	/* sys_exit */
	mov $60, %rax
	xor %rdi, %rdi
	syscall

/*
 * panic() - print an error message and exit with an error
 *
 * Args: %rsi - error message
 *
 * Never returns
 */
panic:
	mov $2, %rdi		# stderr
	call fprint

	/* sys_exit */
	mov $60, %rax
	mov $-1, %rdi
	syscall
