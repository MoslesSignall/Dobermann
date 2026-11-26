import numpy as np
from numpy.fft import fft, ifft

def correlate_pearson_fft(a, b):
    """
    用 FFT 计算滑动 Pearson 相关系数（无 NaN 情况）。
    corr_i = sum(conj(a0) * b0[i:i+M]) / (||a0|| * ||b0[i:i+M]||)
    a是短序列，b是长序列
    """
    a = np.asarray(a, dtype=complex)
    b = np.asarray(b, dtype=complex)
    M, N = len(a), len(b)
    assert M <= N

    a0 = a - a.mean()
    a_norm = np.sqrt(np.sum(np.abs(a0)**2).real)

    # 分子：滑动内积 sum(conj(a0) * b[i:i+M])
    # 用相关运算: 把 a 反序取共轭后与 b 卷积
    # np.convolve 对复数也支持，但为了效率用 FFT
    n_fft = 1 << (N + M - 1).bit_length()
    # 相关 = ifft( fft(b) * conj(fft(reverse(a0))) )
    a_rev = np.conj(a0[::-1])
    corr = ifft(fft(b, n_fft) * fft(a_rev, n_fft))[M - 1:N]

    # 但滑动内积要去掉窗口均值，需减去 mean(w)*sum(conj(a0)) = 0
    # 因为 a0 已去均值，sum(conj(a0)) = 0，所以分子不用修正 ✓

    # 分母：每个窗口 ||b0|| = sqrt(sum |b_i - mean|^2)
    # 滑动平方和 - (滑动和的平方)/M
    b_abs2 = np.abs(b)**2
    b_sum = np.convolve(b, np.ones(M), mode='valid')          # 窗口和
    b_abs2_sum = np.convolve(b_abs2, np.ones(M), mode='valid')# 窗口平方和
    var = b_abs2_sum - np.abs(b_sum)**2 / M
    var = np.clip(var.real, 0, None)  # 防止数值误差出现小负数
    b_norm = np.sqrt(var)

    with np.errstate(invalid='ignore', divide='ignore'):
        res = corr / (a_norm * b_norm)
    res[b_norm == 0] = np.nan
    return res