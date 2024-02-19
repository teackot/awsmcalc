/*
 * fj* - check if the arguments meet a condition (a <=> b).
 *       Basically a conditional jump as a function.
 *
 * Args: %rax - a
 *       %rbx - b
 *       %rcx - jmp address on success
 */
.global fjge
fjge:
	cmp %rbx, %rax
	jge .meets
	ret
.global fjg
fjg:
	cmp %rbx, %rax
	jg .meets
	ret
.global fje
fje:
	cmp %rbx, %rax
	je .meets
	ret
.global fjne
fjne:
	cmp %rbx, %rax
	jne .meets
	ret
.global fjl
fjl:
	cmp %rbx, %rax
	jl .meets
	ret
.global fjle
fjle:
	cmp %rbx, %rax
	jle .meets
	ret
.meets:
	sub $8, %rsp		# forget the return address
	jmp *%rcx
