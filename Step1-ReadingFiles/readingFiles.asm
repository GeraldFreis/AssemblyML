global _start
; --- In this file we take in a file by name through the terminal and print the contents of it to terminal ----

section .data

fileNamePrompt db "Please enter a valid file path: "
lenFileNamePrompt equ $ - fileNamePrompt
fileReadFail db "The file was not able to be read."
lenFileRF equ $ - fileReadFail

section .bss

fileName resb 64
fileDesc resd 1 	; to contain the fileDescriptor so that I can read 
bytesRead resd 1
buffer resb 128		; reserving 128 bytes for the buffer

section .text

_start:
	; reading in the file name
	mov eax, 4
	mov ebx, 1
	mov ecx, fileNamePrompt
	mov edx, lenFileNamePrompt
	int 0x80

	mov eax, 3
	mov ebx, 0
	mov ecx, fileName
	mov edx, 64
	int 0x80

	mov esi, eax
	dec esi
	mov byte [fileName + esi], 0 	; ensuring that we escape the null character
	
	; opening the file
	mov eax, 5
	mov ebx, fileName
	mov ecx, 0
	mov edx, 0
	int 0x80
	

	; after kernel call I should have the file descriptor in eax
	cmp eax, 0
	jl .lessThanError
	mov [fileDesc], eax
.read_loop:
	mov eax, 3
	mov ebx, [fileDesc]
	mov ecx, buffer
	mov edx, 128
	int 0x80
	cmp eax, 0
	jle .close_file
	mov [bytesRead], eax

	; printing output to stdout
	mov eax, 4
	mov ebx, 1
	mov ecx, buffer
	mov edx, [bytesRead]
	int 0x80
	jmp .read_loop
	; jumping to finish because I am a good boy
	
.close_file:
	mov eax, 6	; close syscall
	mov ebx, [fileDesc]
	int 0x80
	jmp .done

.lessThanError:
	mov eax, 4
	mov ebx, 1
	mov ecx, fileReadFail
	mov edx, lenFileRF
	int 0x80
	jmp .done

.done: ; when finished
	mov eax, 1
	xor ebx, ebx
	int 0x80


