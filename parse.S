/*
 * struct token:
 *   - value: i64
 *   - op: u64 (padded char)
 */
token_value_size = 8
token_op_size = 8
token_size = token_value_size + token_op_size

.section .text

/*
 * tokenize() - tokenize an expression
 *
 * Args: %rsi - string
 *       %rdi - tokens[]
 */
.global tokenize
tokenize:
	xor %rbx, %rbx

	call skip_ws
	movb (%rsi), %bl	# %rsi to be incremented later
	test %bl, %bl
	jz .tok_done
	cmp $'+', %bl
	je .tok_op
	cmp $'-', %bl
	je .tok_op
	cmp $'*', %bl
	je .tok_op
	# cmp $'/', %bl
	# je .tok_op
	cmp $'^', %bl
	je .tok_op
	cmp $'(', %bl
	je .tok_op
	cmp $')', %bl
	je .tok_op
	jmp .tok_int

.tok_op:
	inc %rsi
	movq %rbx, (%rdi)
	movq $0, token_op_size(%rdi)
	add $token_size, %rdi
	jmp tokenize
	
.tok_int:
	# TODO: handle NaN
	mov $10, %rbx
	mov $-1, %r10
	call stoi64

	movq $0, (%rdi)
	movq %rax, token_op_size(%rdi)
	add $token_size, %rdi
	jmp tokenize

.tok_done:
	ret

/*
 * transform_postfix() - transform the tokens into a postfix form in place
 *
 * Postfix form description: an array of i64
 *                         : if [n] != 0 then [n] - number
 *                         , else
 *                           : if [n + 1] == 0 then ([n], [n + 1]) == 0
 *                           , if [n + 1] in {+, -, *, /, ^} then ([n], [n + 1]) - operator
 *                           , else - error
 *
 * Args: %rsi - tokens[]
 */
.global sort_postfix
transform_postfix:
	# set the stack frame
	push %rbp
	mov %rsp, %rbp

	# %rsi points to the token being processed,
	# %rdi points to the end of the resulting array
	mov %rsi, %rdi

1:
	movq (%rsi), %rax
	test %rax, %rax
	jnz .op
	movq token_op_size(%rsi), %rax
	movq %rax, (%rdi)
	add $8, %rdi
	add $token_size, %rsi
	jmp 1b
.op:
	/* first op is always pushed */
	cmp %rsp, %rbp
	je .push_op
	/* +, - are simply pushed */
	cmp $'+', %rax
	je .push_op
	cmp $'-', %rax
	je .push_op
	/* *, / pop the stack if they have a higher precedence */
	cmp $'*', %rax
	je .precedence_mul
	cmp $'/', %rax
	je .precedence_mul
	/* same for ^ */
	cmp $'^', %rax
	je .precedence_pow
	# TODO: parentheses
.precedence_mul:
	mov (%esp), %rbx
	cmp $'-', %rbx
	jne .push_op
	cmp $'+', %rbx
	jne .push_op
	add $8, %esp		# pop the op
	movq %rbx, (%rdi)
	add $8, %rdi
	cmp %rsp, %rbp
	je .push_op
	jmp .precedence_mul
.precedence_pow:
	mov (%esp), %rbx
	cmp $'^', %rbx
	je .push_op
	add $8, %esp		# pop the op
	movq %rbx, (%rdi)
	add $8, %rdi
	cmp %rsp, %rbp
	je .push_op
	jmp .precedence_pow
.push_op:
	push %rax

	leave
	ret
