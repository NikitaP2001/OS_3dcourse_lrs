%include "main.inc"
%include "thread.inc"
%include "syscalls.inc"
%include "spinlock.inc"

	SECTION .data

%define BUF_SIZE 400h
write_buf: dq 0
write_lock: dq 0

main_tsc_val: dd 0

	SECTION .text
	global _start
_start:
%define .thread1 rbp - thread_t@size
%define .thread2 rbp - thread_t@size*2

	push rbp
	mov rbp, rsp
	sub rsp, thread_t@size * 2

        ; alloc write buffer
        xor rdi, rdi
        mov rsi, BUF_SIZE
        mov rdx, PROT_READ | PROT_WRITE
        mov r10, MAP_PRIVATE | MAP_ANONYMOUS 
        mov rax, SYS_MMAP
        syscall
        mov qword [write_buf], rax


        rdtsc                         ; save main time stamp counter
        mov dword [main_tsc_val], eax

        ; start threads
	lea rdi, [.thread1] 
	mov qword [rdi + thread_t.fn], inc_task
	mov qword [rdi + thread_t.parg], 1
	call thread_start

	lea rdi, [.thread2] 
	mov qword [rdi + thread_t.fn], inc_task
	mov qword [rdi + thread_t.parg], 2
	call thread_start
	
	; join threads
	lea rdi, [.thread1] 
	call thread_join
        
	lea rdi, [.thread2] 
	call thread_join
       
        ; free write buffer
        mov rdi, write_buf
	mov rsi, BUF_SIZE
	mov rax, SYS_MUNMAP
	syscall

	; exit
	mov rax, 0x3c
	syscall

	SECTION .data
%define TSC_DIFF 1000000
variable: dq 0

	SECTION .text

 inc_task:

 .wait:
        rdtsc                           ; read time stamp
        sub eax, dword [main_tsc_val]   ; sub saved main stamp
        cmp eax, TSC_DIFF               ; compare with wait timei (1000000 - enough)
        jb .wait 

        ; variable increment loop
        mov rcx, 1000
.loop:
        inc qword [variable]

        dec rcx
        jne .loop



        lea rdi, [write_lock]
        call spin_lock


        mov rdi, [write_buf]
        mov byte [rdi], 0
        mov rsi, qword [variable]
        mov rdx, BUF_SIZE
        call atoi

        mov rdi, [write_buf]
        mov rsi, 20
        call write

        endline

        lea rdi, [write_lock]
        call spin_unlock


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
