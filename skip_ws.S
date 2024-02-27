/*
 * skip_ws() - skip space characters in a string
 *
 * Args: %rsi - string pointer
 *
 * Returns: %rsi - first non-space character's address
 */
.ws_next:
	inc %rsi
.global skip_ws
skip_ws:
	cmpb $' ', (%rsi)
	je .ws_next
	ret
