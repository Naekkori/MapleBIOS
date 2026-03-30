import os

def bin_to_csv(input_file, output_file):
    if not os.path.exists(input_file):
        print(f"Error: {input_file} 파일을 찾을 수 없습니다.")
        return

    with open(input_file, "rb") as f:
        bindata = f.read()

    # CSV 헤더 작성
    with open(output_file, "w") as f:
        f.write("Address,Data\n")
        
        # 256바이트 단위로 끊어서 행 생성
        chunk_size = 256
        for i in range(0, len(bindata), chunk_size):
            address = hex(i).upper().replace("0X", "")
            # 주소를 4자리 상수로 맞춤 (예: 0000, 0100)
            address = address.zfill(4)
            
            chunk = bindata[i:i+chunk_size]
            hex_str = chunk.hex().upper()
            
            f.write(f"{address},{hex_str}\n")

    print(f"✅ 변환 완료: {output_file}")
    print(f"총 {len(bindata)} 바이트가 { (len(bindata)//chunk_size) + 1 }개의 행으로 저장되었습니다.")

# 실행
bin_to_csv("bios.bin", "BiosRom.csv")