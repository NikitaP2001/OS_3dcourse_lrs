%ifndef THREAD_INC
%define THREAD_INC

extern thread_start
extern thread_join

struc thread_t
	.pstack		resq 0
	.fn		resq 0
	.lock		resq 0
	.parg		resq 0
endstruc
%define thread_t.pstack 0
%define thread_t.fn 	8h
%define thread_t.lock 	10h
%define thread_t.parg 	18h

thread_t@size equ 20h

%endif ; THREAD_INC
