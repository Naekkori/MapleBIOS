[BITS 16]
org 0x0000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    ; 1. 환영 메시지 출력
    mov si, msg_welcome
    call print_string

    ; 2. 셋업 진입 안내 출력
    mov si, msg_setup_info
    call print_string

    ; 3. 대기 루프
    mov dx, 30          
.wait_outer:
    mov cx, 0xFFFF          
.wait_inner:
    mov ah, 0x01
    int 16h                
    jnz enter_setup         ; 키 입력 시 enter_setup(일반 라벨)으로 점프

    loop .wait_inner        
    dec dx
    jnz .wait_outer         

    ; 4. 타임아웃 시 일반 부팅 진행
    mov si, msg_booting
    call print_string
    jmp boot_os             ; boot_os로 점프 (아래로 흘러가지 않게 차단)

; --- 셋업 메뉴 루틴 (독립된 섹션) ---
enter_setup:
    mov ah, 0x00            ; 키 버퍼 비우기
    int 0x16
    
    mov si, msg_enter_setup
    call print_string

    mov si, msg_setup_title
    call print_string

    mov si, msg_setup_notimplements
    call print_string

    mov si, msg_setup_pressback
    call print_string

.wait_q:                    ; 셋업 내에서 Q를 기다리는 로컬 루프
    mov ah, 0x00
    int 0x16
    cmp al, 'q'
    je start                ; q 누르면 처음(재부팅 느낌)으로
    cmp al, 'Q'
    je start                ; 대문자 Q 대응
    jmp .wait_q             ; Q가 아니면 계속 대기

; --- 부팅 시도 루틴 ---
boot_os:
    ; [MBR 읽기 실패 가정]
    mov si, msg_os_not_found
    call print_string

.halt_loop:
    hlt             ; CPU 정지 (인터럽트 발생 시까지)
    jmp .halt_loop  ; 인터럽트로 깨어나도 다시 정지 (완전 무한 루프)
; --- 문자열 출력 공용 함수 (일반 라벨) ---
print_string:
    mov ah, 0x0E
.loop:                      ; print_string 내부에서만 쓰는 로컬 라벨
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

; --- 데이터 영역 ---
msg_welcome             db 'MapleVM BIOS 1.0', 13, 10, 0
msg_setup_info          db 'Press any key to enter Setup...', 13, 10, 0
msg_setup_title         db 13, 10, '--- Setup Menu ---', 13, 10, 0
msg_setup_notimplements db 'Status: Not implemented yet.', 13, 10, 0
msg_setup_pressback     db 'Press Q key to back...', 13, 10, 0
msg_enter_setup         db 13, 10, 'Entering Setup Menu...', 13, 10, 0
msg_booting             db 'Booting from ROM...', 13, 10, 0
msg_os_not_found        db 'Error: OS not found.', 13, 10, 0

; --- 패딩 및 리셋 벡터 ---
times 65520-($-$$) db 0
jmp 0xF000:start