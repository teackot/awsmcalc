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

	# peek at the next char
	movb (%rsi), %bl	# %rsi to be incremented later
	test %bl, %bl		# \0, end of string
	jz .tok_done

	/* check if it is an operator */
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
	# TODO: count matching parentheses
	cmp $'(', %bl
	je .tok_op
	cmp $')', %bl
	je .tok_op
	cmp $'x', %bl
	je .tok_op

	jmp .tok_int

.tok_op:
	# write an operator token
	movq %rbx, (%rdi)
	movq $0, token_op_size(%rdi)
	add $token_size, %rdi

	# next token
	inc %rsi
	jmp tokenize
	
.tok_int:
	# get an integer
	# TODO: handle NaN
	mov $10, %rbx
	mov $-1, %r10
	call stoi64

	# write an integer token
	movq $0, (%rdi)
	movq %rax, token_op_size(%rdi)
	add $token_size, %rdi

	# next token
	jmp tokenize

.tok_done:
	# terminate the array with a -1 "operator"
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

	# %rsi - next token
	# %rdi - next output position
	mov %rsi, %rdi

.next_token:
	# operator vs integer
	movq (%rsi), %rax	# token.op
	test %rax, %rax
	jnz .op

	/* integer */

	movq token_op_size(%rsi), %rax # get the value
	movq %rax, (%rdi)	# integer is simply written to output
	add $8, %rdi
	add $token_size, %rsi
	test %rax, %rax		# | check for zero, because ...
	jnz .next_token		# |
	movq $0, (%rdi)		# | ... zero has to be 2 bytes long
	add $8, %rdi		# |
	jmp .next_token

	/* operator */

.op:
	add $token_size, %rsi

	# end of the array
	cmp $-1, %rax
	je .pop_rest

	# x: special case of an operator, just write it to output
	cmp $'x', %rax
	jne .not_x
	movq $0, (%rdi)
	movq $'x', 8(%rdi)
	add $16, %rdi
	jmp .next_token
.not_x:

	# TODO: unnecessary?
	# first op is always pushed
	cmp %rsp, %rbp
	je .push_op

	cmp $'^', %rax
	je .pow_pop
	cmp $'*', %rax
	je .mul_pop
	cmp $'/', %rax
	je .mul_pop
	cmp $'+', %rax
	je .add_pop
	cmp $'-', %rax
	je .add_pop
	cmp $'(', %rax
	je .push_op
	cmp $')', %rax
	je .rparen_pop
	hlt			# can not be reachable if tokenization worked correctly

	/* *_pop: pop operators of >= precedence */

.pow_pop:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	cmp $'^', %rbx		# only pops ^
	jne .push_op
	add $8, %rsp		# pop the op
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .pow_pop

.mul_pop:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	cmp $'+', %rbx		# | don't pop these
	je .push_op		# |
	cmp $'-', %rbx		# |
	je .push_op		# |
	cmp $'(', %rbx		# |
	je .push_op		# |
	cmp $')', %rbx		# |
	je .push_op		# |
	add $8, %rsp		# pop the operator
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .mul_pop

.add_pop:
	cmp %rsp, %rbp
	je .push_op
	mov (%rsp), %rbx
	cmp $'(', %rbx		# | don't pop these
	je .push_op		# |
	cmp $')', %rbx		# |
	je .push_op		# |
	add $8, %rsp		# pop the operator
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .add_pop

	# pop everything until '('
	# TODO: tokenize() should guarantee that all parens have a pair
.rparen_pop:
	pop %rbx

	cmp $'(', %rbx
	je .next_token

	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .rparen_pop

.push_op:
	push %rax
	jmp .next_token

.pop_rest:
	# pop the rest of the stack
	cmp %rsp, %rbp		# stack is empty,
	je .post_exit		# leave
	pop %rbx
	movq $0, (%rdi)
	movq %rbx, 8(%rdi)
	add $16, %rdi
	jmp .pop_rest

.post_exit:
	# terminate the array with a -1 "operator"
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
	test %rbx, %rbx		# | 2-byte value: either 0, or an operator
	jz .complex		# |
	push %rbx		# all ints are pushed to be used as operands later
	jmp .exec_next
.complex:
	mov (%rsi), %rbx
	add $8, %rsi
	test %rbx, %rbx
	jnz .check_x
	push %rbx		# it is a 2-byte 0
	jmp .exec_next
.check_x:
	# if it is 'x', push the passed x value
	cmp $'x', %rbx
	jne .exec_op
	push %rdi
	jmp .exec_next

	/* execute the operator and push the result to the stack */
.exec_op:
	cmp $-1, %rbx		# end of the expression
	je .exec_exit
	pop %rcx		# | operands
	pop %rax		# |

	cmp $'+', %rbx
	jne 1f
	add %rcx, %rax
	push %rax
	jmp .exec_next
1:

	cmp $'-', %rbx
	jne 1f
	sub %rcx, %rax
	push %rax
	jmp .exec_next
1:

	cmp $'*', %rbx
	jne 1f
	imul %rcx
	push %rax
	jmp .exec_next
1:

# 	cmp $'/', %rbx
# 	jne 1f
# 	imul %rcx
# 	push %rax
# 	jmp .exec_next
# 1:

	cmp $'^', %rbx
	jne 1f
	call pow
	push %rax
	jmp .exec_next
1:

.exec_exit:
	movq (%rsp), %rax
	mov %rbp, %rbx		# | the stack should only contain 1 value,
	sub %rsp, %rbx		# | the result
	cmp $8, %rbx		# |
	jne .exec_err		# |
	add $8, %rsp
	leave
	ret

.exec_err:
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
