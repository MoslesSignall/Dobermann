# 标准库文件和函数调用区
import argparse
import csv
import os
import math
from pathlib import Path

import numpy as np
from scipy import ndimage, optimize, signal
from scipy.special import logsumexp
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

# 自写函数调用区
from generate_sync_iq import generate_sync_iq
from correlate_pearson import correlate_pearson_fft
from resample_complex_poly import resample_complex_poly
from cfo_estimate import estimate_cfo
from equalize_starlink import equalize_starlink, make_equalizer, PILOTS, PILOT_REFERENCE
from classify_and_demap import classify_and_demap

def corr(a, b):
    return abs(np.vdot(a, b)) / (np.linalg.norm(a) * np.linalg.norm(b))

Fs=250e6 #采样频率
Fs_out=240e6 #重采样频率
cfo=-200e3 #预设定载波频偏
file_path = "mystery.bin"
PSS_WORD = 0xC1B5D191024D3DC3F8EC52FAA16F3958
SSS_WORD = 0xBD565D5064E9B3A94958F28624DED560946199F5B40F0E4FB5EFCB473B4C24B2D1E0BD01A6A04D5017DE91A8ECC0DA09EBFE57F9F1B44C532F161C583A42490A5C09F2A117F9A28F9B2FD547A74C44BABB4BE85DA6A62B1235E2AD084C00180142A8F7F357DEC4F31316BC58FA404909A3FCA7F88E421902B6A2580AE8030803F65809DB347F590DBC46F010EBE3A25C060D74429FC46BDF9B63719279798D232C5ABA274122FF66AD7E449F44CB40C49C24A1E2629F5BFE82CE531FDC34F8C64A43A963F40D5B71BDE6FB2F13492D6F2E8544B21D449722C635180342CD0026A1E7F7E80E91B175E852F919767E5AF9B6E909AF362F5218E2B908DC005803

# 读取二进制文件，合计12500000个采样点，采样率为250MHz
raw = np.fromfile(file_path, dtype="<i2")
iq = raw.astype("float32").view("complex64")

# PSS和SSS的期望原始信号
x = generate_sync_iq(sample_rate=Fs, cfo_hz=cfo)
r = np.abs(correlate_pearson_fft(x, iq))
peak=[] # 存储匹配位置和相关系数
for i in range(len(r)):
    if r[i] > 0.5:
        peak.append((i, r[i]))

# print(f"匹配位置和相关系数: {peak}")

# 分帧和存盘，存盘已经完成，因此进行注释
samples_per_frame = 4.4e-6 * Fs * 302 # 每帧采样点数
# for i in range(len(peak)): # 存盘
#     start = int(peak[i][0])
#     end = int(peak[i][0] + samples_per_frame)
#     frame = iq[start:end]
#     frame_file_path = f"frame_{i}.npz"
#     np.savez_compressed(frame_file_path, frame=frame)
#     print(f"帧 {i} 已保存到 {frame_file_path}")

to_deal=[0] # 本轮运转希望处理哪些内容
for i in to_deal:
    # 取出帧数据
    arr=iq[int(peak[i][0]):int(peak[i][0]+samples_per_frame)]

    # 重采样
    arr=resample_complex_poly(arr, fs_in=Fs, fs_out=Fs_out) 

    # 使用SSS进行CFO估计，并进行CFO补偿
    cfo_est = estimate_cfo(arr[1056+32:1056+1056])  # 取出第二个符号的SSS进行估计
    print(f"帧 {i} 的估计载波频偏: {cfo_est/1e3:.2f} kHz")
    arr_corrected = arr * np.exp(-2j * np.pi * cfo_est * np.arange(len(arr)) / 240e6)

    # 分符号
    symbol=[]
    for j in range(302):
        symbol.append(arr_corrected[j*1056+32:(j+1)*1056]) # 每个符号1056个采样点，CP占据32点

    # FFT环节
    for j in range(302):
        symbol[j]=np.fft.fft(symbol[j]) # 对每个符号进行FFT

    # 均衡环节
    symbol[1:] = list(equalize_starlink(np.asarray(symbol[1:])))

    # 调制方式判决
    bit_tot = np.empty(0, dtype=np.uint8)
    for j in range(1, 302):
        if j == 1:
            mode = "SSS"
            samples = symbol[j][2:1022][::-1]  # 保留 1020 个载波，从 k=1021 到 k=2
            phase = np.rint(np.angle(samples) / (np.pi / 2)).astype(int) % 4
            bits = ((phase[:, None] >> [1, 0]) & 1).astype(np.uint8).ravel()
        else:
            mode, bits = classify_and_demap(
                symbol[j], Path(f"星座图及其判决方式\\帧{i}") / f"frame_{i}_symbol_{j}.png"
            )
        bit_tot = np.concatenate([bit_tot, bits])
        np.packbits(bits, bitorder="big").tofile(
                Path(f"判决比特\\帧{i}") / f"frame_{i}_symbol_{j}.bin"
        )
    np.packbits(bit_tot, bitorder="big").tofile(
                Path(f"判决比特\\帧{i}") / f"frame_{i}_all.bin"
    )
    print(f"帧 {i} 已完成")
    # 保存的.bin文件中，起始位置对应的比特是从正载波开始的，而在一些论文中，则是从负载波开始的
    # 这里不再进行处理，如果需要的话，可以后续自行进行处理
print("======Mosles Signall======")