import numpy as np
from scipy.optimize import minimize_scalar
from generate_sync_iq import generate_sync_iq

def estimate_cfo(rx_sss, fs=240e6, bounds=(-300e3, -100e3)):
    ref_sss = generate_sync_iq(sample_rate=240e6, cfo_hz=0)[1088:2112]
    rx_sss = np.asarray(rx_sss)
    ref_sss = np.asarray(ref_sss)
    if rx_sss.ndim != 1 or rx_sss.shape != ref_sss.shape or rx_sss.size < 2:
        raise ValueError("两段 SSS 必须是等长的一维序列")

    t = np.arange(len(rx_sss)) / fs
    product = rx_sss * np.conj(ref_sss)

    def loss(f):
        corrected = product * np.exp(-2j * np.pi * f * t)
        return -abs(np.sum(corrected))  # 让相干叠加的幅值最大

    cfo_est = minimize_scalar(loss, bounds=bounds, method="bounded").x
    return float(cfo_est)