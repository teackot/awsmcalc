/*
 * struct token:
 *   - value: i64
 *   - op: u64 (padded char), -1 - end
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
	movq $-1, (%rdi)
	movq $0, token_op_size(%rdi)
	add $token_size, %rdi
	ret

/*
 * transform_postfix() - transform the tokens into a postfix form in place
 *
 * Postfix form description: an array of i64
 *                         : if [n] != 0 then [n] - number
 *                         , else
 *                           : if [n + 1] == 0 then ([n], [n + 1]) == 0
 *                           , if [n + 1] in {+, -, *, /, ^} then ([n], [n + 1]) - operator
 *                           , if [n + 1] == -1 then end of array
 *                           , else - error
 *
 * Args: %rsi - tokens[]
 */
.global transform_postfix
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
	test %rax, %rax
	jnz 1b
	movq $0, (%rdi)
	add $8, %rdi
	jmp 1b
.op:
	cmp $-1, %rax
	je .post_done

	add $token_size, %rsi

	/* first op is always pushed */
	cmp %rsp, %rbp
	je .push_op

	/* pops if prev is also ^ */
	cmp $'^', %rax
	je .precedence_pow
	/* pops *, / and ^ */
	cmp $'*', %rax
	je .precedence_mul
	cmp $'/', %rax
	je .precedence_mul
	/* pops all non-parentheses */
	cmp $'+', %rax
	je .precedence_add
	cmp $'-', %rax
	je .precedence_add
	# TODO: parentheses
	hlt			# unreachable

.precedence_pow:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	cmp $'^', %rbx
	jne .push_op
	add $8, %rsp		# pop the op
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .precedence_pow

.precedence_mul:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	cmp $'+', %rbx
	je .push_op
	cmp $'-', %rbx
	je .push_op
	add $8, %rsp		# pop the op
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .precedence_mul

.precedence_add:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	add $8, %rsp		# pop the op
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .precedence_add

.push_op:
	push %rax
	jmp 1b

.post_done:
	# pop the rest of the stack
2:
	cmp %rsp, %rbp
	je 2f
	pop %rbx
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp 2b
2:

	movq $-1, (%rdi)
	add $8, %rdi
	leave
	ret
