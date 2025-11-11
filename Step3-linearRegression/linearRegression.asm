; this file takes in a csv file name from command line, and calculates the a and b values for linear regression
global _start

section .data
fileNamePrompt db "Please enter a valid csv file containing your x and y columns:", 10
lenFileNamePrompt equ $ - fileNamePrompt

fileNotFoundError db "File was not found in path", 10
lenFileNotFoundError equ $ - fileNotFoundError

resultA db "a = "
lenResultA equ $ - resultA
resultB db "b = "
lenResultB equ $ - resultB

newLine db 10
lenNewLine equ 1

dot db ".", 0
lenDot equ 1

section .bss
fileName resb 64
fileDesc resd 1
bytesRead resd 1
buffer resb 128

sumX resd 1
sumY resd 1
sumProdXY resd 1
sumXSquared resd 1
linesRead resd 1

tempVar resd 1

currentX resd 1
currentY resd 1
sign resd 1
col resd 1

aValue resd 1
bValue resd 1

section .text
_start:
    ; initialize
    mov dword [sumX], 0
    mov dword [sumY], 0
    mov dword [sumProdXY], 0
    mov dword [sumXSquared], 0
    mov dword [linesRead], 0
    mov dword [sign], 1
    mov dword [col], 0

    ; prompt filename
    mov eax, 4
    mov ebx, 1
    mov ecx, fileNamePrompt
    mov edx, lenFileNamePrompt
    int 0x80

    ; read filename
    mov eax, 3
    mov ebx, 0
    mov ecx, fileName
    mov edx, 64
    int 0x80

    ; null terminate
    mov esi, eax
    dec esi
    mov byte [fileName + esi], 0

    ; open file (syscall 5)
    mov eax, 5
    mov ebx, fileName
    mov ecx, 0
    mov edx, 0
    int 0x80
    cmp eax, 0
    jl .file_error
    mov [fileDesc], eax

.reading_loop:
    mov eax, 3
    mov ebx, [fileDesc]
    mov ecx, buffer
    mov edx, 128
    int 0x80
    cmp eax, 0
    jle .close_file

    mov [bytesRead], eax
    mov esi, buffer
    mov edi, eax

.process_loop:
    cmp edi, 0
    je .reading_loop
    mov al, [esi]

    cmp al, '-'
    jne .not_neg
    mov dword [sign], -1
    jmp .next_char

.not_neg:
    cmp al, ','
    je .switch_col
    cmp al, 10
    je .commit_line

    ; accumulate digit
    sub al, '0'
    movzx ebx, al
    cmp dword [col], 0
    je .accum_x

.accum_y:
    mov eax, [currentY]
    imul eax, eax, 10
    add eax, ebx
    mov [currentY], eax
    jmp .next_char

.accum_x:
    mov eax, [currentX]
    imul eax, eax, 10
    add eax, ebx
    mov [currentX], eax
    jmp .next_char

.switch_col:
    mov dword [col], 1
    mov dword [sign], 1
    jmp .next_char

.commit_line:
    ; update sums
    mov eax, [currentX]
    imul eax, [sign]
    add [sumX], eax

    mov eax, [currentY]
    imul eax, [sign]
    add [sumY], eax

    mov eax, [currentX]
    mov ebx, [currentY]
    imul eax, ebx
    add [sumProdXY], eax

    mov eax, [currentX]
    imul eax, eax
    add [sumXSquared], eax

    inc dword [linesRead]

    ; reset for next
    mov dword [currentX], 0
    mov dword [currentY], 0
    mov dword [col], 0
    mov dword [sign], 1

.next_char:
    inc esi
    dec edi
    jmp .process_loop

.close_file:
    mov eax, 6
    mov ebx, [fileDesc]
    int 0x80

    ; compute a and b
    call .calculate_a_and_b

    ; print results
    call .print_results

    ; exit
    mov eax, 1
    xor ebx, ebx
    int 0x80

.file_error:
    mov eax, 4
    mov ebx, 1
    mov ecx, fileNotFoundError
    mov edx, lenFileNotFoundError
    int 0x80
    jmp _start




.calculate_a_and_b:
    ; a = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    mov eax, [linesRead]
    mov ebx, [sumProdXY]
    imul eax, ebx               ; n * Σxy
    mov ecx, [sumX]
    mov edx, [sumY]
    imul ecx, edx               ; Σx * Σy
    sub eax, ecx                ; numerator a
    imul eax, 1000
    mov [aValue], eax
    
    mov eax, [linesRead]
    mov ebx, [sumXSquared]
    imul eax, ebx               ; n * Σx²
    mov ecx, [sumX]
    imul ecx, ecx               ; (Σx)²
    sub eax, ecx                ; denominator
    mov ebx, eax

    mov eax, [aValue]
    cdq
    idiv ebx
    mov [aValue], eax

    ; b = (Σy - a*Σx) / n
    mov ebx, [sumX]
    imul ebx, [aValue]

    mov eax, [sumY]
    imul eax, 1000
    sub eax, ebx
    cdq
    idiv dword [linesRead]
    mov [bValue], eax
    ret

.print_results:
    ; print "a = "

    mov eax, 4
    mov ebx, 1
    mov ecx, resultA
    mov edx, lenResultA
    int 0x80

    mov eax, [aValue]
    mov ebx, 1000
    cdq
    idiv ebx
    call .print_number

    ; printing a . 
    mov [aValue], edx 			; saving the remainder

    mov eax, 4
    mov ebx, 1
    mov ecx, dot
    mov edx, lenDot
    int 0x80

    ; now I want to print the remainder
    mov eax, [aValue]
    call .print_number

    ; newline
    mov eax, 4
    mov ebx, 1
    mov ecx, newLine
    mov edx, lenNewLine
    int 0x80

    ; print "b = "
    mov eax, 4
    mov ebx, 1
    mov ecx, resultB
    mov edx, lenResultB
    int 0x80

    mov eax, [bValue]
    mov ebx, 1000
    cdq
    idiv ebx
    mov [tempVar], edx

    call .print_number

    mov eax, 4
    mov ebx, 1
    mov ecx, dot
    mov edx, lenDot
    int 0x80

    ; now printing remainder
    mov eax, [tempVar]
    cmp eax, 0
    jge .frac_pos
    neg eax
    .frac_pos:
    	call .print_number

    ; newline
    mov eax, 4
    mov ebx, 1
    mov ecx, newLine
    mov edx, lenNewLine
    int 0x80
    ret



.print_number:
    mov esi, buffer + 127
    mov byte [esi], 0
    mov ecx, 0
    cmp eax, 0
    jge .convert_loop
    neg eax
    mov ecx, 1

.convert_loop:
    xor edx, edx
    mov ebx, 10
    div ebx
    add dl, '0'
    dec esi
    mov [esi], dl
    test eax, eax
    jnz .convert_loop

    cmp ecx, 0
    je .write_num
    dec esi
    mov byte [esi], '-'

.write_num:
    mov eax, 4
    mov ebx, 1
    mov ecx, esi
    mov edx, buffer + 128
    sub edx, esi
    int 0x80
    ret
