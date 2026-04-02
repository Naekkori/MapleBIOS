;======================================
;            MapleVM BIOS 1.2.2
;            Author: Naekkori
;======================================
[BITS 16]
org 0x0000

start:
    jmp biosmain
; --- 0x0024: INT 09h (키보드 하드웨어 인터럽트) ---
times 0x0024 - ($ - $$) db 0
int09_handler:
    push ax
    ; 키보드 데이터 처리는 나중에 포트 I/O로 구현 가능
    ; 지금은 인터럽트만 정상 종료시킴
    mov al, 0x20 ; EOI (End of Interrupt) 신호
    out 0x20, al ; Master PIC에 전송
    pop ax
    iret
; --- 0x0100: INT 10h (비디오 서비스) ---
times 0x0100 - ($ - $$) db 0
int10_handler:
    mov ah, 0x01 ; VM_CALL_VIDEO
    int 0xF0
    iret
; --- 0x0110: INT 11h (장비체크)      ---
times 0x0110 - ($ - $$) db 0
int11_handler:
    ; AX에 장비 목록 반환 (표준 IBM PC 규격)
    ; Bit 0: 플로피 드라이브 있음 (1)
    ; Bit 1: 수치 보조 프로세서 없음 (0)
    ; Bit 4-5: 비디오 모드 (01 = 40x25 컬러, 10 = 80x25 컬러)
    ; Bit 6-7: 플로피 드라이브 개수 (00 = 1개)
    mov ax, 0x0021 ; 0000 0000 0010 0001 (80x25 컬러, 플로피 1개)
    iret
; --- 0x0120: INT 12h (메모리 크기 체크) ---
times 0x0120 - ($ - $$) db 0
int12_handler:
    mov ax, 640
    iret
; --- 0x0150: INT 15h (시스템 서비스) ---
times 0x0150 - ($ - $$) db 0
int15_handler:
    ; AH=88h (확장 메모리 크기 확인) 대응
    stc             ; 에러 플래그를 세워 "확장 메모리 없음"을 알리거나
    iret            ; 혹은 단순히 iret
; --- 0x0210: INT 13h (디스크 서비스) ---
times 0x0210 - ($ - $$) db 0
int13_handler:
    ; 루아의 HandleDiskInterrupt 호출
    mov ah, 0x02 ; 루아에서 구분할 ID
    int 0xF0     ; 여기서 F000:0580으로 점프함
    iret         ; 루아 처리가 끝나면 여기로 돌아와야 함

    ; 루아에서 작업결과(성공 0 실패 1)
    or ah, ah
    jz .success
    stc        ;AH 가 0 이 아니면 CarryFlag 설정
    iret
.success:
    clc        ;성공시 CarryFlag 해제
    iret
; --- 0x0400: INT 16h (키보드 서비스) ---
times 0x0400 - ($ - $$) db 0
int16_handler:
    push ds
    xor ax, ax
    mov ds, ax
    ; AH 기능 코드에 따른 분기 (현재는 단순 iret)
    pop ds
    iret

; --- 0x0480: INT 19h (Bootstrap Loader) ---
times 0x0480 - ($ - $$) db 0
int19_handler:
    mov ax, 0x0000 ;세그먼트 0 설정
    mov es, ax
    mov bx, 0x7C00 ;로드할 메모리 오프셋

    mov ah, 0x02   ;INT 13h  AH=02h 섹터 읽기
    mov al, 1      ;읽을 섹터수 1개
    mov ch, 0      ;실린더 0
    mov cl, 1      ;섹터 1
    mov dh, 0      ;헤드 0
    mov dl, 0x80   ;드라이브 번호 (0x80 첫번째 FDD)
    int 0x13
    
    jc .fail

    ;부트 시그니처 확인 (0xAA55)
    mov ax, [es:0x7DFE]
    cmp ax, 0xAA55
    jne .fail

    jmp 0x0000:0x7C00 ;부트로더 진입
.fail:
    stc
    iret
; --- 0x0500: INT 08h (타이머 서비스) ---
times 0x0500 - ($ - $$) db 0
int08_handler:
    ; 아직 타이머 로직이 없으므로 인터럽트 종료만 알리고 복귀
    ; 실제 하드웨어라면 PIC에 EOI를 보내야 하지만, 
    ; 여기선 루아가 처리하므로 iret만 해도 무방.
    iret
; --- 0x0580: 메인 진입점 ---
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

    ; 4. 부팅 시도
    int 0x19

    ; 5. 부팅 실패 시 메시지 출력 후 정지
    mov si, msg_os_not_found ; msg_boot_fail 대신 정의된 라벨 사용
    call print_string
.halt:
    hlt
    jmp .halt

; --- 함수 라이브러리 ---
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
    mov dx, 0x402
    mov al, 0xA0
    out dx, al
    mov dx, 0x404
    mov al, 70
    out dx, al
    mov dx, 0x400
    mov al, 1
    out dx, al
    
    mov cx, 0x5000
.delay:
    nop
    loop .delay

    mov al, 0
    out dx, al
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