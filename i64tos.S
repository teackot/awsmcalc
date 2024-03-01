/*
 * i64tos() - converts an signed integer to a null-terminated string
 *
 * Args: %rax - integer to convert
 *       %rbx - radix
 *       %rdi - buffer
 */
.global i64tos
i64tos:
	mov %rdi, %rsi
	xor %r8, %r8		# is_neg: bool

	# set %r8 and invert the sign if negative
	test %rax, %rax
	jns .next
	mov $1, %r8
	neg %rax

	/* convert (reversed) */
.next:
	xor %rdx, %rdx		# rdx:rax = rax
	div %rbx
	add $'0', %rdx		# convert to a digit char
	movb %dl, (%rdi)	# write to the dest string
	inc %rdi
	test %rax, %rax		# check if there's still anything left
	jnz .next

	# add a '-' if negative
	test %r8, %r8
	jz .null
	movb $'-', (%rdi)
	inc %rdi

.null:
	movb $0, (%rdi)		# null-terminate the string

	/* reverse */
	dec %rdi		# point to the last char
.swap:
	# swap memory at rdi and rsi
	movb (%rsi), %al
	movb (%rdi), %bl
	movb %al, (%rdi)
	movb %bl, (%rsi)

	inc %rsi		# | next pair
	dec %rdi		# |
	cmp %rsi, %rdi
	jg .swap

	ret
