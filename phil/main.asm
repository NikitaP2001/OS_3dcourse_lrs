%include "main.inc"
%include "thread.inc"
%include "syscalls.inc"
%include "spinlock.inc"

	SECTION .data

greetz: db "Hi, I am philosopher ", 0
philosopher: db "Philosopher ", 0
eating: db " is eating for ", 0
thinking: db " is thinking for ", 0
seconds: db " seconds", 0

%define BUF_SIZE 400h
write_buf: dq 0
write_lock: dq 0
forks_lock: dq 0

%define N_P 5   ; number of philosophers

forks: dq 0, 0, 0, 0, 0

	SECTION .text
	global _start
_start:
%define .thread1 rbp - thread_t@size
%define .thread2 rbp - thread_t@size*2
%define .thread3 rbp - thread_t@size*3
%define .thread4 rbp - thread_t@size*4
%define .thread5 rbp - thread_t@size*5
	push rbp
	mov rbp, rsp
	sub rsp, thread_t@size * 5

        ; alloc write buffer
        xor rdi, rdi
        mov rsi, BUF_SIZE
        mov rdx, PROT_READ | PROT_WRITE
        mov r10, MAP_PRIVATE | MAP_ANONYMOUS 
        mov rax, SYS_MMAP
        syscall
        mov qword [write_buf], rax

	;start threadas with philosopher activity
	lea rdi, [.thread1] 
	mov qword [rdi + thread_t.fn], routine
	mov qword [rdi + thread_t.parg], 1
	call thread_start

	lea rdi, [.thread2] 
	mov qword [rdi + thread_t.fn], routine
	mov qword [rdi + thread_t.parg], 2
	call thread_start

	lea rdi, [.thread3] 
	mov qword [rdi + thread_t.fn], routine
	mov qword [rdi + thread_t.parg], 3
	call thread_start

	lea rdi, [.thread4] 
	mov qword [rdi + thread_t.fn], routine
	mov qword [rdi + thread_t.parg], 4
	call thread_start

	lea rdi, [.thread5] 
	mov qword [rdi + thread_t.fn], routine
	mov qword [rdi + thread_t.parg], 5
	call thread_start
	
	; join threads
	lea rdi, [.thread1] 
	call thread_join
        
	lea rdi, [.thread2] 
	call thread_join
        
	lea rdi, [.thread3] 
	call thread_join
        
	lea rdi, [.thread4] 
	call thread_join

	lea rdi, [.thread5] 
	call thread_join

        ; free write buffer
        mov rdi, write_buf
	mov rsi, BUF_SIZE
	mov rax, SYS_MUNMAP
	syscall

	; exit
	mov rax, 0x3c
	syscall

; @ int pid - id of the philosopher
;----------------------------------
routine:
%define .number rbp - 8
	push rbp
        mov rbp, rsp
        sub rsp, 8h

        mov qword [.number], rdi

        ; philosopther i greetz everyone
        lea rdi, [write_lock]
        call spin_lock

                mov rdi, [write_buf]
                mov byte [rdi], 0
                mov rsi, greetz
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, qword [.number]
                mov rdx, BUF_SIZE
                call atoi

                mov rdi, [write_buf]
                mov rsi, BUF_SIZE
                call strlen

                mov rsi, rax
                mov rdi, [write_buf]
                call write

                endline

        lea rdi, [write_lock]
        call spin_unlock

.loop:
        mov rdi, qword [.number]
        call think

        mov rdi, qword [.number]
        call take_forks
        
        mov rdi, qword [.number]
        call eat

        mov rdi, qword [.number]
        call put_forks

        jmp .loop
	
        mov rsp, rbp
	pop rbp
        ret

; @ int pid - id of the philosopher
;----------------------------------
think:
%define .number rbp - 8
%define .time_think rbp - 10h
%define .timespec rbp - 20h
        push rbp
        mov rbp, rsp
        sub rsp, 20h

        mov qword [.number], rdi

        ; generate think time
        mov rdi, 2
        mov rsi, 5
        call RangedRand
        mov qword[.time_think], rax

        ; write lock
        lea rdi, [write_lock]
        call spin_lock

                mov rdi, [write_buf]
                mov byte [rdi], 0
                mov rsi, philosopher
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, qword [.number]
                mov rdx, BUF_SIZE
                call atoi

                mov rdi, [write_buf]
                mov rsi, thinking
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, qword [.time_think]
                mov rdx, BUF_SIZE
                call atoi

                mov rdi, [write_buf]
                mov rsi, seconds
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, BUF_SIZE
                call strlen

                mov rsi, rax
                mov rdi, [write_buf]
                call write

                endline

        lea rdi, [write_lock]
        call spin_unlock

        ; sleep to emulate thinking
        mov rax, [.time_think]
        lea rdi, [.timespec]
        mov qword [rdi], rax
        mov qword [rdi + 8h], 0
        xor rsi, rsi
        mov rax, SYS_NANOSLEEP
        syscall
        
        mov rsp, rbp
        pop rbp
        ret

; @ int pid - id of the philosopher
;----------------------------------
take_forks: 
%define .left rbp - 4h
%define .right rbp - 8h
%define .number rbp - 10h
        push rbp
        mov rbp, rsp
        sub rsp, 10h

        mov qword [.number], rdi
        call left_fork
        mov dword [.left], eax

        call right_fork
        mov dword [.right], eax

        ; enter critical section
        lea rdi, [forks_lock]
        call spin_lock
                
                ; acquire left fork
                lea rdi, [forks]
                mov eax, dword [.left]
                lea eax, [eax * 8]
                add edi, eax
                call spin_lock

                ; acquire right fork
                lea rdi, [forks]
                mov eax, dword [.right]
                lea eax, [eax * 8]
                add edi, eax
                call spin_lock

        lea rdi, [forks_lock]
        call spin_unlock

        mov rsp, rbp
        pop rbp
        ret

; @ int pid - id of the philosopher
;----------------------------------
eat:
%define .number rbp - 8
%define .time_eat rbp - 10h
%define .timespec rbp - 20h
        push rbp
        mov rbp, rsp
        sub rsp, 20h

        mov qword [.number], rdi

        ; generate eat time
        mov rdi, 2
        mov rsi, 5
        call RangedRand
        mov qword[.time_eat], rax

        ; write lock
        lea rdi, [write_lock]
        call spin_lock

                mov rdi, [write_buf]
                mov byte [rdi], 0
                mov rsi, philosopher
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, qword [.number]
                mov rdx, BUF_SIZE
                call atoi

                mov rdi, [write_buf]
                mov rsi, eating
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, qword [.time_eat]
                mov rdx, BUF_SIZE
                call atoi

                mov rdi, [write_buf]
                mov rsi, seconds
                mov rdx, BUF_SIZE
                call strcat

                mov rdi, [write_buf]
                mov rsi, BUF_SIZE
                call strlen

                mov rsi, rax
                mov rdi, [write_buf]
                call write

                endline

        lea rdi, [write_lock]
        call spin_unlock

        ; sleep to emulate thinking
        mov rax, [.time_eat]
        lea rdi, [.timespec]
        mov qword [rdi], rax
        mov qword [rdi + 8h], 0
        xor rsi, rsi
        mov rax, SYS_NANOSLEEP
        syscall
        
        mov rsp, rbp
        pop rbp
        ret

; @ int pid - id of the philosopher
;----------------------------------
put_forks:
%define .left rbp - 4h
%define .right rbp - 8h
%define .number rbp - 10h
        push rbp
        mov rbp, rsp
        sub rsp, 10h

        mov qword [.number], rdi
        call left_fork
        mov dword [.left], eax

        call right_fork
        mov dword [.right], eax

        ; release left fork
        lea rdi, [forks]
        mov eax, dword [.left]
        lea eax, [eax * 8]
        add edi, eax
        call spin_unlock

        ; release right fork
        lea rdi, [forks]
        mov eax, dword [.right]
        lea eax, [eax * 8]
        add edi, eax
        call spin_unlock

        mov rsp, rbp
        pop rbp
        ret

left_fork:
        mov rax, rdi
        dec rax
        ret

right_fork:
        mov rax, rdi
        xor rdx, rdx
        mov rsi, N_P
        div rsi
        mov rax, rdx
        ret

write:
	mov rdx, rsi
	mov rsi, rdi
	mov rdi, 1
	mov rax, SYS_WRITE
	syscall

	ret

; Converts num to decimal and appends
; to string
; @char *pstr - nullterm str to append num on
; @long long num - number for convertation
; @int max_size - max size of the string
; return:
;       0 on success
;       -1 no space to append
;--------------------------------------------------
atoi:
        push rbp
        push r10
        mov rbp, rsp
        xor r8, r8      ; is lz
        mov r9, 10      ; base of converion
        xor r10, r10    ; converted num len

        mov rcx, rdx    ; save max_len for repe
        mov rax, rsi
        test rax, rax
        jns .g_z
                mov r8, 1
                not rax
                inc rax
.g_z:
        test rax, rax
        je .w_s
                xor rdx, rdx
                div r9 
                add rdx, 30h
                push rdx
                inc r10
                jmp .g_z
.w_s:
        test r8, r8
        je .seek
                inc r10
                push '-'

.seek:
        repne scasb      ; seek strend
        dec rdi

.append: 
        test rcx, rcx
        je .of
        test r10, r10
        je .end
                pop rdx 
                mov byte[rdi], dl

                inc rdi
                dec r10
                dec rcx
                jmp .append
.of:
        mov rax, -1

.end:
        mov byte[rdi], 0
        xor rax, rax

.exit:

        mov rsp, rbp
        pop r10
        pop rbp
        ret


; Appends string
; @char *p_str1
; @char *p_str2
; @int sz_str1
; ret:
;       0 on success
strcat:
        mov rcx, rdx
        xor rax, rax
        repne scasb
        dec rdi
.for:
        test rcx, rcx
        je .of
        cmp byte [rsi], 0
        je .end
                movsb
                dec rcx
                jmp .for

.of:
        mov rax, -1
        jmp .exit

.end:
        mov byte [rdi], 0
        xor rax, rax
.exit:

        ret

; @chat sz_str
; @int max_sz
strlen:
        mov rcx, rsi
        mov rsi, rdi
        xor al, al
        repne scasb

        sub rdi, rsi
        mov rax, rdi 

        ret

; Generate random in diapazon
; @int min
; @int max
;

RangedRand:
%define .rand_val rbp - 8h
        push rbp
        mov rbp, rsp
        sub rsp, 8h

.n_c:
        rdrand rax
        jnc .n_c
        mov qword [.rand_val], rax
        
        mov rcx, rsi        
        sub rcx, rdi
        xor rdx, rdx
        mov rax, qword [.rand_val]
        div rcx
        add rdx, rdi
        
        mov rax, rdx        

        mov rsp, rbp
        pop rbp
        ret
