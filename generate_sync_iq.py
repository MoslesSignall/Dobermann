import numpy as np

def generate_sync_iq(sample_rate=250000000, cfo_hz=0.0):
    """返回含循环前缀的 PSS 与 SSS，按时间拼接为一维 complex128 数组。"""
    PSS_WORD = 0xC1B5D191024D3DC3F8EC52FAA16F3958
    SSS_WORD = 0xBD565D5064E9B3A94958F28624DED560946199F5B40F0E4FB5EFCB473B4C24B2D1E0BD01A6A04D5017DE91A8ECC0DA09EBFE57F9F1B44C532F161C583A42490A5C09F2A117F9A28F9B2FD547A74C44BABB4BE85DA6A62B1235E2AD084C00180142A8F7F357DEC4F31316BC58FA404909A3FCA7F88E421902B6A2580AE8030803F65809DB347F590DBC46F010EBE3A25C060D74429FC46BDF9B63719279798D232C5ABA274122FF66AD7E449F44CB40C49C24A1E2629F5BFE82CE531FDC34F8C64A43A963F40D5B71BDE6FB2F13492D6F2E8544B21D449722C635180342CD0026A1E7F7E80E91B175E852F919767E5AF9B6E909AF362F5218E2B908DC005803

    symbol_samples = sample_rate * 44 // 10_000_000  # 一个符号时段为 4.4 µs
    adc_index = np.arange(symbol_samples)
    chip_time = adc_index * (240_000_000 / sample_rate)

    # PSS：差分相位调制、首块反相、32 点前缀，再按接收采样时刻求值。
    bits = np.array([(PSS_WORD >> i) & 1 for i in range(128)])
    phase = -np.pi / 4 - np.pi / 2 * np.cumsum(2 * bits - 1)
    block = np.exp(1j * phase)
    pss_chips = np.concatenate((-block[-32:], -block, np.tile(block, 7)))
    pss = np.sinc(chip_time[:, None] - np.arange(len(pss_chips))) @ pss_chips

    # SSS：把文献给出的四相值映射到子载波，直接在接收采样时刻叠加。
    # chip_time - 32 包含循环前缀。归一化使有效段的均方幅度为 1。
    k = np.arange(2, 1022)
    signed_k = np.where(k < 512, k, k - 1024)
    phase_index = np.array([(SSS_WORD >> (2 * int(i))) & 3 for i in k - 2])
    coefficients = 1j ** phase_index
    angle = (2j * np.pi / 1024) * (chip_time[:, None] - 32) * signed_k
    sss = (np.exp(angle) @ coefficients) / np.linalg.norm(coefficients)

    x = np.concatenate((pss, sss))
    time_s = np.arange(len(x)) / sample_rate
    x *= np.exp(2j * np.pi * cfo_hz * time_s)
    return x