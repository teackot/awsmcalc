/*
 * strcmp() - compare two strings
 *
 * Args: %rsi - string 1
 *       %rdi - string 2
 *
 * Returns: %rsi - pointer to the first different char
 *               , or 0 if the strings are equal
 */
.global strcmp
.next:
	inc %rsi
	inc %rdi
strcmp:
	movb (%rsi), %al
	cmpb (%rdi), %al
	jne .diff
	test %al, %al
	jnz .next
	xor %rsi, %rsi
.diff:
	ret
