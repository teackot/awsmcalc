/*
 * u64tos() - converts an unsigned integer to
 *            a null-terminated string
 *
 * Args: %rax - unsigend integer to convert
 *       %rbx - radix
 *       %rdi - buffer
 */
.global u64tos
u64tos:
	mov %rdi, %rsi

	/* convert (reversed) */
.next:
	xor %rdx, %rdx		# rdx:rax = rax
	div %rbx
	add $'0', %rdx		# convert to a digit char
	movb %dl, (%rdi)	# write to the dest string
	inc %rdi
	test %rax, %rax		# check if there's still anything left
	jnz .next

	movb $0, (%rdi)		# null-terminate the string

	/* reverse */
	dec %rdi		# point to the last char
.swap:
	movb (%rsi), %al	# | swap memory at rdi and rsi
	movb (%rdi), %bl	# |
	movb %al, (%rdi)	# |
	movb %bl, (%rsi)	# |

	inc %rsi		# | next pair
	dec %rdi		# |
	cmp %rsi, %rdi
	jg .swap

	ret
