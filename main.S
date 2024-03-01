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
err_unex:	.string  "Unexpected symbol: "
err_unex_len = . - err_unex - 1
err_parens:	.string  "Parentheses don't match!\n"

cmd_quit:	.string "quit"

.section .data

buf_len = 64			# universal buf len
buf:		.fill buf_len
expr_then_buf:	.fill buf_len
expr_else_buf:	.fill buf_len

.section .bss

.lcomm expr_then, 64 * 16	# token_size = 16
.lcomm expr_else, 64 * 16	# token_size = 16

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
	mov $buf, %rsi
	call skip_ws
	add $2, %rsi
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
1:
	mov $then_prompt, %rsi
	mov $expr_then_buf, %r12
	mov $buf_len, %rdx
	mov $expr_then, %r13
	call get_expr

	test %rax, %rax
	jnz 1b

	/* parse the "else" expression */

1:
	mov $else_prompt, %rsi
	mov $expr_else_buf, %r12
	mov $buf_len, %rdx
	mov $expr_else, %r13
	call get_expr

	test %rax, %rax
	jnz 1b

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
	call i64tos		# rax to string

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

/*
 * get_expr() - prompt for, read and parse an expression
 *
 * Args: %rsi - prompt
 *       %r12 - buf
 *       %rdx - buf size
 *       %r13 - parsed expr destination
 *
 * Returns: %rax - error code
 */
get_expr:
	# print the prompt
	push %rdx
	call print		# prompt is in %rsi
	pop %rdx

	# read the expression
	mov %r12, %rsi
	call readline		# buf size is in %rdx

	jz 1f			# success
	mov $err_read, %rsi	# read error, panic
	call panic
1:

	# tokenize the expression
	mov %r12, %rsi		# string
	mov %r13, %rdi		# dest
	push %r12
	call tokenize
	pop %r12

	test %rax, %rax		# check for tokenize errors
	jz 1f			# jump on success
	cmp $-2, %rax		# | parentheses?
	je .parens_err		# |
	mov %rsi, %r9		# unexpected symbol pointer
	sub %r12, %r9		# unexpected symbol index
	mov %r12, %rbx
	call print_unex
	mov $-1, %rax
	ret
.parens_err:
	mov $err_parens, %rsi
	call print
	mov $-1, %rax
	ret
1:

	# transform to a postfix form
	mov %r13, %rsi
	call transform_postfix

	xor %rax, %rax
	ret

/*
 * print_unex() - print an 'unexpected symbol' error message
 *                with a pointer to the said symbol
 *
 * Args: %r9  - symbol index
 *       %rbx - expression string
 */
print_unex:
	mov $err_unex, %rsi
	call print
	mov %rbx, %rsi
	call print
	mov $'\n', %rax
	call putchar

	add $err_unex_len, %r9
1:
	mov $' ', %rax
	call putchar
	dec %r9
	jnz 1b

	mov $'^', %rax
	call putchar
	mov $'\n', %rax
	call putchar
	ret
