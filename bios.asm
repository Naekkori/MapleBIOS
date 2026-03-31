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
    mov dx, 30
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
    ;MBR 읽기시도 (INT 13h, AH=02h)
    mov ax, 0x07C0 ; MBR 이 로드될 세그먼트
    mov es, ax
    xor bx, bx     ; ES:BX = 07C0:0000 (물리주소 0x7C00)

    mov ah, 0x02 ; 섹터 읽기 서비스
    mov al, 1    ; 1 개의 섹터
    mov ch, 0    ; 0 번 실린더
    mov cl, 1    ; 1 번 섹터 (부트 섹터)
    mov dh, 0    ; 0 번 헤드
    mov dl, 0x80 ; 첫번째 HDD
    int 0x13

    jc .error ; Carry Flag 가 세팅 되면 에러

    ; --- 부팅 성공 시 ---
    jmp 0x0000:0x7C00   ; 읽어온 부트 섹터 위치로 멀리 점프(Far Jump)
.error:
    ; 추가: 기존에 눌려있던 키가 있다면 무시하기 위해 버퍼 확인 및 제거
    mov ah, 0x01
    int 0x16
    jz  .no_flush
    mov ah, 0x00
    int 0x16
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
msg_welcome             db 'MapleVM BIOS 1.0', 13, 10, 0
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