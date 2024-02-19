.section .rodata

cond_prompt:	.string "if x "

prompt:		.string "x = "

prefix_then:	.ascii  "then: "
expr_meets:	.string "(x - 11)^2 + 125"
prefix_else:	.ascii  "else: "
expr_else:	.string "x^2 + 72x + 6400"
result_sep:	.string " = "

err_read:	.string "Could not read the input!\n"
err_nan:	.string "You should enter an integer!\n"

.section .data

buf:		.fill 64
buf_len = .-buf

inp_x:		.quad 1

.section .text
.global _start
_start:
	/* parse the condition */

	# print the condition prompt
	mov $cond_prompt, %rsi
	call print

	# read the full condition
	mov $buf, %rsi
	mov $buf_len, %rdx
	call readline

	jz 1f			# success
	mov $err_read, %rsi	# read error, panic
	call panic
1:

	/* parse the operator, set %r15 to the corresponding function */
	mov $buf + 2, %rsi
	movw -2(%rsi), %ax
	cmp $'<', %al		# <x
	je .ilx
	cmp $'=', %al		# =x
	je .iex
	cmp $'>', %al		# >x
	je .igx
	cmp $'!', %al		# !x
	je .inx
	jmp _start
.ilx:
	cmp $'=', %ah		# <=
	je .ile
	dec %rsi
	.il:
		mov $fjl, %r15
		jmp .cond_set
	.ile:
		mov $fjle, %r15
		jmp .cond_set
.igx:
	cmp $'=', %ah		# >=
	je .ige
	dec %rsi
	.ig:
		mov $fjg, %r15
		jmp .cond_set
	.ige:
		mov $fjge, %r15
		jmp .cond_set
.iex:
	cmp $'=', %ah		# ==
	jne _start
	mov $fje, %r15
	jmp .cond_set
.inx:
	cmp $'=', %ah		# !=
	jne _start
	mov $fjne, %r15
	jmp .cond_set
.cond_set:

	# %rsi is already set to the next char after the operator
	call skip_ws

	# parse the operand
	mov $10, %rbx
	call stoi64

	test %rbx, %rbx		# check for stoi64 errors
	jz 1f			# success
	mov $err_nan, %rsi
	call print
	jmp _start
1:

	mov %rax, %r14		# save the condition operand

	# print the 'then' branch expression
	mov $prefix_then, %rsi
	call print
	mov $'\n', %rax
	call putchar

	# print the 'else' branch expression
	mov $prefix_else, %rsi
	call print
	mov $'\n', %rax
	call putchar

	/* read the value */

.read_x:
	# print the prompt
	mov $prompt, %rsi
	call print

	mov $buf, %rsi
	mov $buf_len, %rdx
	call readline

	jz 1f			# success
	mov $err_read, %rsi	# read error, panic
	call panic
1:

	mov $buf, %rsi		# convert buf
	mov $10, %rbx		# base 10
	call stoi64		# to u64

	test %rbx, %rbx		# check for stoi64 errors
	jz 1f
	mov $err_nan, %rsi
	call print
	jmp _start
1:

	mov %r14, %rbx		# the const operand
	mov $.meets, %rcx	# jmp to .meets
	call *%r15		# call the comparison function
	jmp .else

.meets:				# input meets the condition
	pushq $expr_meets	# use a register?

	sub $11, %rax		# t = x - 11
	mul %rax		# t = t^2
	add $125, %rax		# t += 125

	jmp .done

.else:
	pushq $expr_else	# use a register?

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

	# print " = "
	mov $result_sep, %rsi
	call print

	# print the result
	mov $buf, %rsi
	call print

	mov $'\n', %rax
	call putchar

	jmp .read_x

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

/*
 * skip_ws() - skip space characters in a string
 *
 * Args: %rsi - string pointer
 *
 * Returns: %rsi - first non-space character's address
 */
.ws_next:
	inc %rsi
skip_ws:
	cmpb $' ', (%rsi)
	je .ws_next
	ret
