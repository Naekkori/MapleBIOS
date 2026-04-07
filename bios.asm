;======================================
;            MapleVM BIOS 1.2.3
;            Author: Naekkori
;======================================
[BITS 16]
org 0x0000

start:
    jmp biosmain

; ---------------------------------------------------------
; [1] 인터럽트 벡터 점프 테이블 (고정 위치)
; ---------------------------------------------------------

; 0x0020: INT 08h (Timer)
times 0x0020 - ($ - $$) db 0
    jmp int08_handler_logic

; 0x0024: INT 09h (Keyboard)
times 0x0024 - ($ - $$) db 0
    jmp int09_handler_logic

; 0x0100: INT 10h (Video)
times 0x0100 - ($ - $$) db 0
    jmp int10_handler_logic

; 0x0110: INT 11h (Equipment)
times 0x0110 - ($ - $$) db 0
    jmp int11_handler_logic

; 0x0120: INT 12h (Memory)
times 0x0120 - ($ - $$) db 0
    jmp int12_handler_logic

; 0x0130: INT 13h (Disk)
times 0x0130 - ($ - $$) db 0
    jmp int13_handler_logic

; ---------------------------------------------------------
; [2] 실제 인터럽트 핸들러 로직 (공간이 넉넉한 곳)
; ---------------------------------------------------------
times 0x0500 - ($ - $$) db 0

int08_handler_logic:
    push ax
    push ds
    mov ax, 0x0040
    mov ds, ax
    inc word [0x006C]    ; BDA 틱 카운터 증가
    jnz .no_overflow
    inc word [0x006E]
.no_overflow:
    mov al, 0x20         ; EOI 신호
    out 0x20, al
    pop ds
    pop ax
    iret

int09_handler_logic:
    push ax
    ; 키보드 데이터는 나중에 포트 I/O로 처리
    mov al, 0x20
    out 0x20, al
    pop ax
    iret

int10_handler_logic:
    int 0xF0            ; VM_CALL (하이퍼바이저 호출)
    iret

int11_handler_logic:
    mov ax, 0x0001      ; 장비 상태 보고
    iret

int12_handler_logic:
    mov ax, 640         ; 640KB 보고
    iret

int13_handler_logic:
    int 0xF0
    iret

; ---------------------------------------------------------
; [3] 바이오스 메인 엔트리
; ---------------------------------------------------------
times 0x0580 - ($ - $$) db 0
; 루아에서 이 인터럽트 번호를 가로채서 기능을 수행.
; 하지만 CPU 입장에서는 '실행할 코드'가 있어야 하므로 iret을 배치함.
intF0_handler:
    iret
biosmain:
    ; 1. 스택 및 세그먼트 초기화
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0xFFFE
    
    mov ax, 0xF000  ; 바이오스 데이터 접근을 위해 DS를 F000으로 설정
    mov ds, ax
    mov es, ax
    sti

    ; 2. 화면 초기화 및 환영 메시지
    call clear_screen

    mov si, msg_welcome
    call print_string

    ; 3. 비프음 (POST 성공)
    call beep
    ; 부팅 진입
    call boot_entry
; 부팅 실패 시 혹은 모든 로직 종료 시 여기서 멈춤
.bios_halt:
    hlt
    jmp .bios_halt

boot_entry: 
    mov si, msg_booting
    call print_string
    int 0x19
    
    ; int 0x19가 리턴되었다는 건 부팅 실패를 의미함
    mov si, msg_os_not_found
    call print_string

    call beep_os_not_found
    jmp $ ; 여기서 정지시켜서 로그 확인

.halt:
    hlt
    jmp .halt ; 재시도하지 않고 여기서 멈춤

; --- 함수 라이브러리 ---
; ---------------------------------------------------------
; sleep: CX 틱만큼 대기 (1틱 = 약 55ms)
; 입력: CX = 대기할 틱 수
; ---------------------------------------------------------
sleep:
    push ax
    push ds
    push bx

    mov ax, 0x0040
    mov ds, ax
    mov bx, [0x006C]    ; 현재 틱 카운터(Low Word) 읽기
    add bx, cx          ; 목표 틱 계산

.wait:
    cmp [0x006C], bx    ; 현재 틱이 목표에 도달했는지 확인
    jb .wait            ; 아직 도달하지 않았다면 계속 대기

    pop bx
    pop ds
    pop ax
    ret
print_string:
    push ax
    push si
.loop:
    lodsb           ; AL = [DS:SI], SI++
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

clear_screen:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    ret

beep:
    push dx
    push ax
    push cx

    ; 스피커 켜기 로직
    mov dx, 0x402
    mov al, 0xA0
    out dx, al
    mov dx, 0x404
    mov al, 70
    out dx, al
    mov dx, 0x400
    mov al, 1
    out dx, al
    
    ; --- 타이머 기반 대기 ---
    mov cx, 3           ; 약 3틱 대기 (약 165ms)
    call sleep
    ; -----------------------

    ; 스피커 끄기
    mov al, 0
    mov dx, 0x400       ; 포트 주소 다시 확인
    out dx, al

    pop cx
    pop ax
    pop dx
    ret
beep_os_not_found:
    push dx
    push ax
    push cx

    ; OS를 찿을수 없으면 3번 울림
    mov dx, 0x402
    mov al, 0xA0
    out dx, al
    mov dx, 0x404
    mov al, 70
    out dx, al
    mov dx, 0x400
    mov al, 1
    out dx, al

    mov cx, 3
    call sleep

    mov al, 0
    mov dx, 0x400
    out dx, al

    mov cx, 3
    call sleep

    mov dx, 0x400
    mov al, 1
    out dx, al
    
    mov cx, 3
    call sleep

    mov al, 0
    mov dx, 0x400     
    out dx, al
    ; -----------------------

    pop cx
    pop ax
    pop dx
    ret
; --- 데이터 영역 ---
msg_welcome             db 'MapleVM BIOS 1.2.2', 13, 10, 0
msg_setup_info          db 'Press any key to enter Setup...', 13, 10, 0
msg_setup_title         db 13, 10
                        db 0xC9, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xBB, 13, 10
                        db 0xBA, ' ', 'Setup Menu', ' ', 0xBA, 13, 10
                        db 0xC8, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xBC, 13, 10
                        db 0
msg_setup_notimplements db 'Not implemented yet.', 13, 10, 0
msg_setup_pressback     db 'Press Q key to back...', 13, 10, 0
msg_booting             db 'Booting from DISK...', 13, 10, 0
msg_os_not_found        db 'Error: OS not found.', 13, 10, 0
msg_os_retryhint        db 'Press any key to retry...', 13, 10, 0

; --- 리셋 벡터 영역 ---
; 패딩 계산 시 발생할 수 있는 오차를 줄이기 위해 절대 주소 사용 권장
times 65520-($-$$)      db 0
jmp 0xF000:start
times 65536-($-$$)      db 0