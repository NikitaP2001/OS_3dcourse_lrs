%include "main.inc"
%include "thread.inc"
%include "syscalls.inc"
%include "spinlock.inc"

%define STACK_SIZE (4096 * 1024)
%define CLONE_FLAGS    CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND|CLONE_PARENT| \
	CLONE_THREAD|CLONE_IO

; params:
; 	@thread_t  *pthread
; ret:
; 	0 on success
;----------------------------------------
thread_start:
%define .pthread rbp - 8 
	push rbp
	mov rbp, rsp
	sub rsp, 8h

	; save arguments
	mov qword [.pthread], rdi 	; pointer to thread struc

	; acquire lock
	lea rdi, [rdi + thread_t.lock]
	mov qword [rdi], 0
	call spin_lock

	; allocate thread stack
	call .mmap
	test rax, rax
	js .error

	; save ptrstack in thread struc
	mov rdi, [.pthread]
	mov qword [rdi + thread_t.pstack], rax

	call .clone
	test rax, rax
	js .error

	xor rax, rax
	jmp .exit

.clone:
	push rdi
	mov rdi, CLONE_FLAGS
	lea rsi, [rax + STACK_SIZE - 10h]
	pop qword [rsi + 8h]
	mov rax, SYS_CLONE
	syscall
	test rax, rax
	jne .parent
	
	; child`s code
	mov rdi, qword [rsp + 8h] ; pthread
	mov rax, qword [rdi + thread_t.fn]
	mov rdi, qword [rdi + thread_t.parg]

	call rax

	; release lock
	mov rdi, qword [rsp + 8h]
	lea rdi, [rdi + thread_t.lock]
	call spin_unlock

	xor rdi, rdi
	mov rax, SYS_EXIT
	syscall

.parent:

	ret

.mmap:
	mov rax, SYS_MMAP
	mov rdi, 0
        mov r8, 0
        mov r9, 0
	mov rsi, STACK_SIZE
	mov rdx, PROT_WRITE | PROT_READ
	mov r10, MAP_ANONYMOUS | MAP_PRIVATE | MAP_GROWSDOWN
	syscall

	ret

.error:

	mov rax, -1

.exit:

	mov rsp, rbp
	pop rbp
	ret


; params
; 	@thread_t  *pthread
; ret: 
;       0 on success
;-------------------------------------
thread_join:
%define .pthread rbp - 8
	push rbp
	mov rbp, rsp 
	sub rsp, 8h

	mov qword [.pthread], rdi 	; pointer to thread struc

	; wait for thread lock release
	lea rdi, [rdi + thread_t.lock]
	call spin_lock

	; unmap stack
	mov rdi, qword [.pthread]
	mov rdi, qword [rdi + thread_t.pstack]
	mov rsi, STACK_SIZE
	mov rax, SYS_MUNMAP
	syscall
	test rax, rax
	js .error

	; release lock again
	mov rdi, qword [.pthread]
	lea rdi, [rdi + thread_t.lock]
	call spin_unlock
	xor rax, rax

        jmp .exit
.error:
	mov rax, -1

.exit:

	mov rsp, rbp
	pop rbp
	ret

