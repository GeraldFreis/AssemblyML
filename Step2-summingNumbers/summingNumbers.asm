
global _start

section .data
fileNamePrompt db "Please enter a valid file path: "
lenFileNamePrompt equ $ - fileNamePrompt
fileReadFail db "The file was not able to be read."
lenFileRF equ $ - fileReadFail
newLine db 10
lenNewLine equ 1

section .bss
fileName resb 64
fileDesc resd 1
bytesRead resd 1
buffer resb 128
sum resd 1
current resd 1						; this stores the current number
sign resd 1

section .text
_start:
    ; Initialize sum and current number and sign
    mov dword [sum], 0
    mov dword [current], 0
    mov dword [sign], 1

    ; Prompt for filename
    mov eax, 4
    mov ebx, 1
    mov ecx, fileNamePrompt
    mov edx, lenFileNamePrompt
    int 0x80

    ; Read filename from stdin
    mov eax, 3
    mov ebx, 0
    mov ecx, fileName
    mov edx, 64
    int 0x80

    ; Null-terminate filename
    mov esi, eax
    dec esi
    mov byte [fileName + esi], 0

    ; Open file (syscall 5)
    mov eax, 5
    mov ebx, fileName
    mov ecx, 0          
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl .lessThanError
    mov [fileDesc], eax

.reading_loop:
    ; Read chunk from file
    mov eax, 3
    mov ebx, [fileDesc]
    mov ecx, buffer
    mov edx, 128
    int 0x80
    cmp eax, 0
    jle .close_file      ; EOF
    mov [bytesRead], eax

    mov esi, buffer
    mov edi, eax          ; bytes read

.process_loop:
    ; if buffer empty
    cmp edi, 0
    je .reading_loop

    ; if current value in buffer is a comma or endline or negative
    mov al, [esi]
    cmp al, ','
    je .commit_number
    cmp al, 10
    je .commit_number
    cmp al, '-'
    jne .not_negative
    mov dword [sign],-1
    jmp .next_char

.not_negative:
    ; Accumulate multi-digit number; i.e. reading until , as numbers should be comma separated
    sub al, '0'
    movzx ebx, al
    mov eax, [current]
    imul eax, eax, 10
    add eax, ebx
    mov [current], eax
    jmp .next_char

.commit_number:
    mov eax, [current]
    mov ebx, [sign]
    imul eax, ebx
    add [sum], eax

    mov dword [current], 0
    mov dword [sign], 1

.next_char:
    inc esi
    dec edi
    jmp .process_loop

.close_file:
    ; Close file
    mov eax, 6
    mov ebx, [fileDesc]
    int 0x80

    ; Commit any remaining number
    mov eax, [current]
    mov ebx, [sign]
    imul eax, ebx
    add [sum], eax
    
    ; checking if sum is zero because we can just print
    mov eax, [sum]
    cmp eax, 0
    je .is_zero

    ; Convert sum to ASCII
    mov eax, [sum]
    mov esi, buffer + 128  ; end of buffer
    mov byte [esi], 0      ; null-terminate (not strictly needed)
    
    mov ecx, 0
    cmp eax, 0
    jge .convert
    neg eax
    mov ecx, 1
    jmp .convert

.is_zero:
	mov byte [buffer], '0'	; making the output 0
	mov esi, buffer
	mov edx, 1
	jmp .print_sum


.convert:
    xor edx, edx
    mov ebx, 10
    div ebx                 ; EAX / 10, remainder in EDX
    add dl, '0'
    dec esi
    mov [esi], dl
    test eax, eax
    jnz .convert
    
    ; first we need to check if ecx is 0 and if so we can just continue, otherwise we need to decrement esi and move a '-' sign to the front
    cmp ecx, 0
    je .print_sum
    dec esi
    mov byte [esi], '-'

.print_sum:

    ; Print result
    mov eax, 4
    mov ebx, 1
    mov ecx, esi
    mov edx, buffer + 128
    sub edx, esi
    int 0x80

    ; Print newline
    mov eax, 4
    mov ebx, 1
    mov ecx, newLine
    mov edx, lenNewLine
    int 0x80

    ; Exit
    mov eax, 1
    xor ebx, ebx
    int 0x80

.lessThanError:
    mov eax, 4
    mov ebx, 1
    mov ecx, fileReadFail
    mov edx, lenFileRF
    int 0x80
    jmp _start
