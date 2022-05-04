%include "spinlock.inc"
; params:
; 	@ long long *p_lock
spin_lock:
    	mov     rcx, 1             
retry:
	xor     rax, rax          
	XACQUIRE lock cmpxchg [rdi], rcx
			       
	je      out                
pause:
	mov     rax, [rdi]      
	test    rax, rax
	jz      retry         
        pause
			    
	jmp     pause      
out:
    	ret                   

spin_unlock:
    	XRELEASE mov qword [rdi], 0 
    	ret
