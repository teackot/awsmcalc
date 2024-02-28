.section .rodata

# Original task:
# if x >= 16
# then: (x - 11)^2 + 125
# else: x^2 + 72*x + 6400

cond_prompt:	.string "if x "
then_prompt:	.string "then: "
else_prompt:	.string "else: "
prompt:		.string "x = "

result_sep:	.string " = "

err_read:	.string "Could not read the input!\n"
err_nan:	.string "You should enter an integer!\n"

cmd_quit:	.string "quit"

.section .data

buf_len = 64			# universal buf len
buf:		.fill buf_len
expr_then_buf:	.fill buf_len
expr_else_buf:	.fill buf_len

.section .bss

.lcomm expr_then, 64 * 16 # token_size = 16
.lcomm expr_else, 64 * 16 # token_size = 16

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
	xor %r10, %r10
	call stoi64

	test %rbx, %rbx		# check for stoi64 errors
	jz 1f			# success
	mov $err_nan, %rsi
	call print
	jmp _start
1:

	mov %rax, %r14		# save the condition operand

	/*
	 * Parse expressions
	 */

	/* parse the "then" expression */

	# print the "then" prompt
	mov $then_prompt, %rsi
	call print

	# read the expression
	mov $expr_then_buf, %rsi
	mov $buf_len, %rdx
	call readline

	jz 1f			# success
	mov $err_read, %rsi	# read error, panic
	call panic
1:

	# tokenize the expression
	mov $expr_then_buf, %rsi
	mov $expr_then, %rdi
	call tokenize

	# transform to a postfix form
	mov $expr_then, %rsi
	call transform_postfix

	/* parse the "else" expression */

	# print the "else" prompt
	mov $else_prompt, %rsi
	call print

	# read the expression
	mov $expr_else_buf, %rsi
	mov $buf_len, %rdx
	call readline

	jz 1f			# success
	mov $err_read, %rsi	# read error, panic
	call panic
1:

	# tokenize the expression
	mov $expr_else_buf, %rsi
	mov $expr_else, %rdi
	call tokenize

	# transform to a postfix form
	mov $expr_else, %rsi
	call transform_postfix

	/*
	 * Expressions parsed.
	 */

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
	xor %r10, %r10		# error on non-numeric
	call stoi64		# to u64

	/* handle errors and commands */
	test %rbx, %rbx		# check for stoi64 errors
	jz 1f
	cmp $-2, %rbx		# NaN, check if it's a command
	je .cmd
	mov $err_nan, %rsi
	call print
	jmp _start
.cmd:
	movw (buf), %bx		# fetch 2 bytes of a string in reversed order
	cmp $'q', %bx		# "q" - short for quit (\0 in the higher half)
	je .exit
	mov $buf, %rsi		# |
	mov $cmd_quit, %rdi	# | full "quit" command
	call strcmp
	test %rsi, %rsi
	jz .exit
	jmp .read_x
1:

	# pass the input into the condition
	# (rax contains input after the conversion)
	mov %r14, %rbx		# the const operand
	mov $.meets, %rcx	# jmp to .meets
	call *%r15		# call the comparison function
	jmp .else

	/* input meets the condition */
.meets:
	pushq $expr_then_buf

	mov $expr_then, %rsi
	mov %rax, %rdi
	call exec_postfix

	jmp .done

	/* input doesn't meet the condition */
.else:
	pushq $expr_else_buf

	mov $expr_else, %rsi
	mov %rax, %rdi
	call exec_postfix

.done:
	mov $10, %rbx		# base 10
	mov $buf, %rdi		# into the buf
	call u64tos		# rax to string

	# print the expression
	popq %rsi
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

.exit:
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
