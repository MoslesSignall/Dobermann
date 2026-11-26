from math import gcd
import numpy as np
from scipy.signal import resample_poly

def resample_complex_poly(x, fs_in=250e6, fs_out=240e6):
    """
    复数序列有理数重采样：fs_in -> fs_out
    x: 1D complex array
    """
    num = int(round(fs_out / 1e6))   # 240
    den = int(round(fs_in  / 1e6))   # 250
    g = gcd(num, den)
    L = num // g   # 24  (上采样)
    M = den // g   # 25  (下采样)

    # resample_poly 会自动设计抗混叠/抗镜像 FIR 滤波器
    y = resample_poly(x, up=L, down=M, axis=-1)
    return y