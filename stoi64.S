/*
 * stoi64() - converts a null-terminated string to
 *            a signed integer
 *
 * Args: %rsi - string
 *       %rbx - radix
 *
 * Returns: %rax - resulting number
 *          %rbx - error code
 */
.global stoi64
stoi64:
	xor %rax, %rax		# initial number is 0
	xor %rcx, %rcx		# character
	xor %r8, %r8		# char counter
	xor %r9, %r9		# negative flag
.convert:
	movb (%rsi), %cl
	test %cl, %cl
	jz .done
	sub $'0', %cl		# convert a digit
	cmp $9, %cx		# cx to ignore the SF
	jle .numeric
	not %r9			# switch negative flag
	cmp $'-'-'0', %cl	# negative
	je .next
	mov $-2, %rbx		# not a number
	jmp .end
.numeric:
	mul %rbx		# | append it
	add %rcx, %rax		# |
.next:
	inc %rsi
	inc %r8
	jmp .convert
.done:
	xor %rbx, %rbx		# error code 0
	test %r8, %r8
	jnz .sign		# string wasn't empty
	not %rbx		# error code -1 - empty string
.sign:
	test %r9, %r9
	jz .end
	neg %rax
.end:
	ret
