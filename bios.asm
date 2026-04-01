;======================================
;            MapleVM BIOS 1.2.1
;            Author: Naekkori
;======================================
[BITS 16]
org 0x0000

start:
    jmp biosmain
; --- 0x0100 지점에 INT 10h / 13h 핸들러 배치 ---
times 0x0100 - ($ - $$) db 0
int10_handler:
    ; (현재는 MapleVMBIOS.mlua에서 이 주소로 점프하게 되어 있음)
    ; 여기에 실제 화면 출력/디스크 핸들링 로직을 넣거나, 간단히 iret 처리
    iret

; --- 0x0200 지점에 INT 12h 핸들러 배치 ---
times 0x0200 - ($ - $$) db 0
int12_handler:
    mov ax, 640    ; 메모리 640KB 보고
    iret

; --- 0x0400 지점에 INT 16h 핸들러 배치 ---
times 0x0400 - ($ - $$) db 0
int16_handler:
    ; 키보드 서비스 핸들러
    iret

times 0x0500 - ($ - $$) db 0
biosmain:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    call clear_screen
    call post_bell
.print_welcome:
    ; 환영 메시지 출력
    mov  si, msg_welcome
    call print_string

    ; 셋업 진입 안내 출력
    mov  si, msg_setup_info
    call print_string

    ; 대기 루프
    mov dx, 3
.wait_outer:
    mov cx, 0xFFFF
.wait_inner:
    mov ah, 0x01
    int 16h
    jnz enter_setup ; 키 입력 시 enter_setup(일반 라벨)으로 점프

    loop .wait_inner
    dec  dx
    jnz  .wait_outer

    ; 타임아웃 시 일반 부팅 진행
    mov  si, msg_booting
    call print_string
    jmp  boot_os         ; boot_os로 점프 (아래로 흘러가지 않게 차단)

; --- 셋업 메뉴 루틴 (독립된 섹션) ---
enter_setup:
    call clear_screen

    mov ah, 0x00 ; 키 버퍼 비우기
    int 0x16

    mov  si, msg_setup_title
    call print_string

    mov  si, msg_setup_notimplements
    call print_string

    mov  si, msg_setup_pressback
    call print_string

.wait_q: ; 셋업 내에서 Q를 기다리는 로컬 루프
    mov ah, 0x00
    int 0x16
    cmp al, 'q'
    je  start    ; q 누르면 처음(재부팅 느낌)으로
    cmp al, 'Q'
    je  start    ; 대문자 Q 대응
    jmp .wait_q  ; Q가 아니면 계속 대기

; --- 부팅 시도 루틴 ---
boot_os:
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    ; 1. 먼저 디스크(MBR)를 메모리로 읽어옵니다.
    mov ax, 0x0000 ; ES를 0으로 설정 (0x7C00에 바로 쓰기 위해)
    mov es, ax
    mov bx, 0x7C00 ; 목적지 주소 ES:BX = 0000:7C00

    mov ah, 0x02   ; 섹터 읽기 서비스
    mov al, 1      ; 1개 섹터
    mov ch, 0      ; 0번 실린더
    mov cl, 1      ; 1번 섹터
    mov dh, 0      ; 0번 헤드
    mov dl, 0x80   ; 첫번째 HDD
    int 0x13       ; 이제 CPUCore의 INT 13h 핸들러가 작동!

    jc .error      ; 읽기 실패 시 에러 처리 (Carry Flag 확인)

    ; 2. 읽기가 성공했다면, 데이터가 들어있는 0x7C00으로 점프.
    jmp 0x0000:0x7C00

.error:
    ; 에러 메시지 출력 루틴
    mov si, msg_os_not_found
    call print_string
    hlt
.no_flush:
    mov  si, msg_os_not_found
    call print_string

    mov  si, msg_os_retryhint
    call print_string

    ; 키 입력 대기 (AH=00h, INT 16h)
    mov ah, 0x00
    int 0x16

    ; 키가 눌리면 시스템 재시작 (처음으로 점프)
    jmp start

; --- 문자열 출력 공용 함수 (일반 라벨) ---
print_string:
    mov ah, 0x0E
.loop: ; print_string 내부에서만 쓰는 로컬 라벨
    lodsb
    cmp al, 0
    je  .done
    int 0x10
    jmp .loop
.done:
    ret

clear_screen: ; 화면 전부 지우기
    mov ah, 0x06
    mov al, 0x00
    int 0x10
    ret
; --- 시스템 벨 --
post_bell:
    ; 음높이 설정 (약간 높게 설정하여 '띡' 느낌 부여)
    mov dx, 0x402
    mov al, 160      ; 기존 100에서 160으로 높임 (더 날카로운 소리)
    out dx, al

    ; 볼륨 설정
    mov dx, 0x404
    mov al, 70       ; 너무 크지 않게 70% 정도로 조절
    out dx, al

    ; 재생 시작
    mov dx, 0x400
    mov al, 1
    out dx, al

    ; --- 아주 짧은 딜레이 (Busy Wait) ---
    mov cx, 0x2000
.delay:
    nop
    loop .delay

    ; 소리 즉시 끄기
    mov dx, 0x400
    mov al, 0
    out dx, al
    ret
; --- 데이터 영역 ---
msg_welcome             db 'MapleVM BIOS 1.2.1', 13, 10, 0
msg_setup_info          db 'Press any key to enter Setup...', 13, 10, 0
msg_setup_title         db 13, 10 ; 상자 위 여백
                        db 0xC9, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xBB, 13, 10 ; ╔════════════╗
                        db 0xBA, ' ', 'Setup Menu', ' ', 0xBA, 13, 10                                                 ; ║ Setup Menu ║
                        db 0xC8, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xBC, 13, 10 ; ╚════════════╝
                        db 0 ; 전체 문자열의 끝을 알리는 NULL
msg_setup_notimplements db 'Not implemented yet.', 13, 10, 0
msg_setup_pressback     db 'Press Q key to back...', 13, 10, 0
msg_booting             db 'Booting from DISK...', 13, 10, 0
msg_os_not_found        db 'Error: OS not found.', 13, 10, 0
msg_os_retryhint        db 'Press any key to retry...', 13, 10, 0

; --- 패딩 및 리셋 벡터 ---
times 65520-($-$$)      db 0
jmp 0xF000:start