import csv
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

# 한글 폰트
for font in fm.findSystemFonts():
    if any(k in font for k in ["Malgun", "malgun", "NanumGothic", "gulim"]):
        fm.fontManager.addfont(font)
        plt.rcParams["font.family"] = fm.FontProperties(fname=font).get_name()
        break
plt.rcParams["axes.unicode_minus"] = False

BASE = os.path.dirname(os.path.abspath(__file__))

# ── 파일 그룹 분류 ──────────────────────────────
GROUPS = {
    "기존_밝음": [
        "나타 바닥 기존(1).csv",
        "나타 바닥 기존1.csv",
        "나타 바닥 기존3.csv",
        "나타 바닥 기존 4.csv",
    ],
    "기존_어둠": [
        "나타 바닥 어둠.csv",
        "나타 바닥 어둠`1.csv",
        "나타 기존 어둠3.csv",
        "나책 기존 어둠_모니터off.csv",
        "나책 기존 어둠_모니터off(1).csv",
    ],
    "변경_밝음": [
        "나타 바닥 변경.csv",
        "나타 바닥 변경(1).csv",
        "나타 바닥 변경(2).csv",
        "나타 바닥 변경(3).csv",
    ],
    "변경_어둠": [
        "나타 변경 어둠.csv",
        "나타 변경 어둠(1).csv",
        "나타 변경 어둠(2).csv",
        "나타 변경 어둠(3).csv",
    ],
}

def load_change(fpath):
    """두 포맷 모두 지원. (time, change) 리스트 반환"""
    rows = []
    with open(fpath, newline='', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        header = next(reader)
        is_new = "net_avg" in header   # 변경 포맷
        t = 0.0
        for row in reader:
            if not row or row[0] != "data":
                continue
            try:
                if is_new:
                    chg = float(row[9])   # change 컬럼
                    ts  = float(row[1])
                else:
                    chg = float(row[4])   # change 컬럼
                    ts  = t
                    t  += 0.1
                rows.append((ts, chg))
            except (ValueError, IndexError):
                pass
    return rows

def load_raw(fpath):
    """두 포맷 모두 지원. 원본 센서값 반환.
    기존 포맷: current_raw (col 3) = avgRaw
    변경 포맷: avg_on (col 5) = LED-ON 슬라이딩 평균
    """
    rows = []
    with open(fpath, newline='', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        header = next(reader)
        is_new = "net_avg" in header
        t = 0.0
        for row in reader:
            if not row or row[0] != "data":
                continue
            try:
                if is_new:
                    val = float(row[5])   # avg_on
                    ts  = float(row[1])
                else:
                    val = float(row[3])   # current_raw (avgRaw)
                    ts  = t
                    t  += 0.1
                rows.append((ts, val))
            except (ValueError, IndexError):
                pass
    return rows

def short_label(fname):
    n = fname.replace(".csv", "")
    n = n.replace("나타 바닥 기존", "기존")
    n = n.replace("나타 바닥 변경", "변경")
    n = n.replace("나타 변경 어둠", "변경어둠")
    n = n.replace("나타 바닥 어둠", "기존어둠")
    n = n.replace("나타 기존 어둠", "기존어둠")
    n = n.replace("나책 기존 어둠", "나책기존어둠")
    return n

COLORS = ["#1f77b4","#ff7f0e","#2ca02c","#d62728","#9467bd","#8c564b"]

def plot_group(group_name, files, out_name, title):
    fig, ax = plt.subplots(figsize=(12, 5))
    for i, fname in enumerate(files):
        fpath = os.path.join(BASE, fname)
        if not os.path.exists(fpath):
            print(f"  missing: {fname}")
            continue
        data = load_change(fpath)
        if not data:
            continue
        xs = [d[0] for d in data]
        ys = [d[1] for d in data]
        ax.plot(xs, ys, label=short_label(fname), color=COLORS[i % len(COLORS)], linewidth=1.2)

    ax.axhline(10, color="red", linestyle="--", linewidth=1, label="threshold=10")
    ax.set_title(title, fontsize=13)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Change")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    out = os.path.join(BASE, out_name)
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"저장: {out_name}")

def plot_comparison(name_a, files_a, name_b, files_b, out_name, title):
    fig, ax = plt.subplots(figsize=(12, 5))
    COLOR_A = "#1f77b4"   # 파랑 계열 — 기존
    COLOR_B = "#d62728"   # 빨강 계열 — 변경

    for i, fname in enumerate(files_a):
        fpath = os.path.join(BASE, fname)
        if not os.path.exists(fpath):
            continue
        data = load_change(fpath)
        if not data:
            continue
        xs = [d[0] for d in data]
        ys = [d[1] for d in data]
        label = name_a if i == 0 else f"_{name_a}"   # legend에 한 번만 표시
        ax.plot(xs, ys, color=COLOR_A, linewidth=1.2, label=label, alpha=0.6 + 0.1 * i)

    for i, fname in enumerate(files_b):
        fpath = os.path.join(BASE, fname)
        if not os.path.exists(fpath):
            continue
        data = load_change(fpath)
        if not data:
            continue
        xs = [d[0] for d in data]
        ys = [d[1] for d in data]
        label = name_b if i == 0 else f"_{name_b}"
        ax.plot(xs, ys, color=COLOR_B, linewidth=1.2, label=label, alpha=0.6 + 0.1 * i)

    ax.set_title(title, fontsize=13)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Change")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    out = os.path.join(BASE, out_name)
    plt.savefig(out, dpi=150)
    plt.close()
    print(f"저장: {out_name}")

# ── 그래프 1~4: 그룹별 병합 ──
plot_group("기존_밝음", GROUPS["기존_밝음"], "graph_1_기존_밝음.png",  "기존 코드 - 밝음 (runs 병합)")
plot_group("기존_어둠", GROUPS["기존_어둠"], "graph_2_기존_어둠.png",  "기존 코드 - 어둠 (runs 병합)")
plot_group("변경_밝음", GROUPS["변경_밝음"], "graph_3_변경_밝음.png",  "변경 코드 (logger) - 밝음 (runs 병합)")
plot_group("변경_어둠", GROUPS["변경_어둠"], "graph_4_변경_어둠.png",  "변경 코드 (logger) - 어둠 (runs 병합)")

# ── 그래프 5~6: 기존 vs 변경 비교 ──
plot_comparison(
    "기존(밝음)", GROUPS["기존_밝음"],
    "변경(밝음)", GROUPS["변경_밝음"],
    "graph_5_밝음_비교.png", "밝음 환경: 기존(avgRaw change) vs 변경(net_avg change)"
)
plot_comparison(
    "기존(어둠)", GROUPS["기존_어둠"],
    "변경(어둠)", GROUPS["변경_어둠"],
    "graph_6_어둠_비교.png", "어둠 환경: 기존(avgRaw change) vs 변경(net_avg change)"
)

print("완료.")
