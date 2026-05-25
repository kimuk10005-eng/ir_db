import csv
import re
import os

FILES = [
    "나책 바닥 기존.csv",
    "나책 바닥 기존(노란 led off).csv",
]

HEADER = ["record_type", "baseline_raw", "base_raw", "current_raw", "change", "graph", "raw_data"]

def convert(src_path, dst_path):
    out_rows = [HEADER]

    with open(src_path, newline='', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        next(reader)  # skip original header

        for row in reader:
            raw = row[-1].strip()  # raw_line은 마지막 컬럼

            # Collecting baseline... RawAvg=XXX
            m = re.match(r'Collecting baseline\.\.\. RawAvg=([\d.]+)', raw)
            if m:
                v = m.group(1)
                out_rows.append(["baseline", v, "", "", "", v, raw])
                continue

            # Final Base Raw Average = XXX
            m = re.match(r'Final Base Raw Average = ([\d.]+)', raw)
            if m:
                v = m.group(1)
                out_rows.append(["final_base", "", v, "", "", v, raw])
                continue

            # Time=Xs | BaseRaw=X | CurrentRaw=X | Change=X => Label
            m = re.match(r'Time=[\d.]+s \| BaseRaw=([\d.]+) \| CurrentRaw=([\d.]+) \| Change=([\d.]+) =>', raw)
            if m:
                base_r, cur_r, chg = m.group(1), m.group(2), m.group(3)
                out_rows.append(["data", "", base_r, cur_r, chg, cur_r, raw])
                continue

            # 나머지 (info, separator 등)
            out_rows.append(["info", "", "", "", "", "", raw])

    with open(dst_path, 'w', newline='', encoding='utf-8-sig') as f:
        csv.writer(f).writerows(out_rows)

    print(f"변환 완료: {os.path.basename(dst_path)} ({len(out_rows)-1}행)")

base = os.path.dirname(os.path.abspath(__file__))
for fname in FILES:
    src = os.path.join(base, fname)
    name, ext = os.path.splitext(fname)
    dst = os.path.join(base, name + "_변환" + ext)
    convert(src, dst)
