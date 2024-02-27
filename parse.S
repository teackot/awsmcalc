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
	cmp $'x', %bl
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
	# setup the stack frame
	push %rbp
	mov %rsp, %rbp

	# %rsi points to the token being processed,
	# %rdi points to the end of the resulting array
	mov %rsi, %rdi

.next_token:
	movq (%rsi), %rax
	test %rax, %rax
	jnz .op
	movq token_op_size(%rsi), %rax
	movq %rax, (%rdi)
	add $8, %rdi
	add $token_size, %rsi
	test %rax, %rax
	jnz .next_token
	movq $0, (%rdi)
	add $8, %rdi
	jmp .next_token
.op:
	add $token_size, %rsi

	cmp $-1, %rax
	je .post_done

	cmp $'x', %rax
	jne .not_x
	movq $0, (%rdi)
	movq $'x', 8(%rdi)
	add $16, %rdi
	jmp .next_token
.not_x:

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
	/* () */
	cmp $'(', %rax
	je .push_op
	cmp $')', %rax
	jne 2f
	# pop until '('
1:
	pop %rbx
	cmp $'(', %rbx
	je .next_token
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp 1b
2:
	hlt			# should not be reachable

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
	cmp $'(', %rbx
	je .push_op
	cmp $')', %rbx
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
	cmp $'(', %rbx
	je .push_op
	cmp $')', %rbx
	je .push_op
	mov (%rsp), %rbx
	add $8, %rsp		# pop the op
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .precedence_add

.push_op:
	push %rax
	jmp .next_token

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

	movq $0, (%rdi)
	movq $-1, 8(%rdi)
	add $16, %rdi
	leave
	ret

/*
 * exec_postfix() - execute a postfix expression
 *
 * Args: %rsi - postfix expression
 *       %rdi - x
 *
 * Returns: %rax - result
 */
.global exec_postfix
exec_postfix:
	# setup the stack frame
	push %rbp
	mov %rsp, %rbp

.exec_next:
	mov (%rsi), %rbx
	add $8, %rsi
	test %rbx, %rbx
	jz .complex
	push %rbx
	jmp .exec_next
.complex:
	mov (%rsi), %rbx
	add $8, %rsi
	test %rbx, %rbx
	jnz .check_x
	push %rbx
	jmp .exec_next
.check_x:
	cmp $'x', %rbx
	jne .exec_op
	push %rdi
	jmp .exec_next
.exec_op:
	cmp $-1, %rbx
	je .exec_exit
	pop %rcx		# | operands
	pop %rax		# |
	cmp $'+', %rbx
	jne 2f
	add %rcx, %rax
	push %rax
	jmp .exec_next
2:
	cmp $'-', %rbx
	jne 2f
	sub %rcx, %rax
	push %rax
	jmp .exec_next
2:
	cmp $'*', %rbx
	jne 2f
	imul %rcx
	push %rax
	jmp .exec_next
# 2:
# 	cmp $'/', %rbx
# 	jne 2f
# 	imul %rcx
# 	push %rax
# 	jmp .exec_next
2:
	cmp $'^', %rbx
	jne 2f
	call pow
	push %rax
	jmp .exec_next
2:

.exec_exit:
	cmp %rsp, %rbp
	je 1f
	pop %rax
	leave
	ret
1:
	hlt

/* VERY BAD!!! AWFUL CODE!!!
 * pow() - raise a to the power of b (a^b)
 *
 * Args: %rax - a
 *       %rcx - b
 *
 * Uses: %rbx
 *
 * Returns: %rax - a^b
 */
pow:
	dec %rcx
	mov %rax, %rbx
1:
	imul %rbx
	loop 1b
	ret
