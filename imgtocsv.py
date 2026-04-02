import csv
import os

def convert_vhd_to_csv(input_file, output_file):
    sector_size = 512
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} 파일을 찾을 수 없습니다.")
        return

    with open(input_file, 'rb') as f_in, open(output_file, 'w', newline='', encoding='utf-8') as f_out:
        writer = csv.writer(f_out)
        # 헤더 작성
        writer.writerow(['Sector', 'Data'])
        
        sector_num = 0
        while True:
            data = f_in.read(sector_size)
            if not data:
                break
            
            # 데이터를 16진수 문자열로 변환 (예: "eb3c90...")
            hex_data = data.hex()
            
            # CSV에 섹터 번호와 데이터 기록
            writer.writerow([sector_num, hex_data])
            sector_num += 1
            
    print(f"변환 완료! 총 {sector_num} 섹터가 {output_file}에 저장되었습니다.")

# 실행
convert_vhd_to_csv('fd1440.img', 'vhd_dataset.csv')