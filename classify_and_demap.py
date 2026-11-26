"""Classify one equalized OFDM symbol, return hard bits and save a diagnostic plot."""

import matplotlib.pyplot as plt
import numpy as np
from scipy.special import logsumexp


def _constellations():
    qpsk = np.array([1, 1j, -1, -1j])
    gray_qpsk = np.array([0, 1, 3, 2])
    models = {
        "BPSK": (np.array([1, -1]), np.array([0, 1])),
        "QPSK": (qpsk, gray_qpsk),
        "4QAM": (qpsk * np.exp(1j * np.pi / 4), gray_qpsk),
        "8PSK": (np.exp(1j * np.pi / 4 * np.arange(8)),
                 np.arange(8) ^ (np.arange(8) >> 1)),
    }
    sizes = {"8-RQAM": (4, 2), "16-QAM": (4, 4), "32-XQAM": (6, 6),
             "64-QAM": (8, 8), "256-QAM": (16, 16)}
    for name, (ni, nq) in sizes.items():
        i, q = np.indices((ni, nq))
        re, im = 2*i - ni + 1, 2*q - nq + 1
        grid = re + 1j*im
        if name == "32-XQAM":
            points = grid[~((abs(re) == 5) & (abs(im) == 5))]
            labels = np.arange(32)  # Increasing I, then Q, with corners omitted.
        else:
            points = grid.ravel()
            labels = ((i ^ (i >> 1))*nq + (q ^ (q >> 1))).ravel()
        models[name] = points / np.sqrt(np.mean(abs(points)**2)), labels
    return models


def _score_models(train, test, models):
    fits = []
    # The input is already phase-aligned by the receiver. Allow small residual rotations.
    phases = np.deg2rad(np.arange(-20, 21, 4))
    for name, (points, labels) in models.items():
        best_error = np.inf
        for phase in phases:
            rotated = points * np.exp(1j * phase)
            distances = abs(train[:, None] - rotated)**2
            error = distances.min(axis=1).mean()
            if error < best_error:
                best_error, best_phase = error, phase
        variance = max(best_error, 1e-5)
        rotated = points * np.exp(1j * best_phase)
        distances = abs(test[:, None] - rotated)**2
        # Equal prior for each point; score only the subcarriers withheld from fitting.
        score = np.mean(logsumexp(-distances / variance, axis=1)) - np.log(len(points)*variance)
        evm = np.sqrt(distances.min(axis=1).mean())
        fits.append((score, name, best_phase, evm))
    return sorted(fits, reverse=True)


def classify_and_demap(symbol, plot_path="modulation_check.png", *, bins=None):
    """Return (modulation name, flat uint8 bits), or ('UNKNOWN', empty bits).

    symbol is one 1024-element FFT row after channel equalization and coarse phase alignment.
    Use unshifted NumPy FFT order. By default, use Starlink non-pilot active indices.
    Pass bins=np.arange(1024) to consider every position of an all-data test input.
    """
    symbol = np.asarray(symbol, dtype=complex)
    if symbol.shape != (1024,):
        raise ValueError("symbol must be a one-dimensional array of 1024 FFT values")
    if bins is None:
        pilots = np.r_[488:496, 528:536]
        bins = np.setdiff1d(np.arange(2, 1022), pilots)
        signed_k = np.fft.fftfreq(1024) * 1024
        fit_bins = bins[abs(signed_k[bins]) < 440]
    else:
        bins = np.asarray(bins)
        if (bins.ndim != 1 or bins.dtype.kind not in "iu"
                or np.any((bins < 0) | (bins >= 1024)) or len(np.unique(bins)) != len(bins)):
            raise ValueError("bins must be unique integer FFT indices in [0, 1023]")
        fit_bins = bins
    if len(fit_bins) < 16 or not np.isfinite(symbol[bins]).all():
        raise ValueError("Need at least 16 finite, selected subcarriers")

    scale = np.sqrt(np.mean(abs(symbol[fit_bins[::2]])**2))
    if scale == 0:
        raise ValueError("Selected training subcarriers have zero energy")
    train = symbol[fit_bins[::2]] / scale
    test = symbol[fit_bins[1::2]] / scale
    models = _constellations()
    fits = _score_models(train, test, models)
    score, candidate, phase, evm = fits[0]
    points, labels = models[candidate]

    # Compare against an unstructured complex Gaussian fit to the same training set.
    mean = train.mean()
    noise_var = max(np.mean(abs(train - mean)**2), 1e-5)
    baseline = -np.mean(abs(test - mean)**2) / noise_var - np.log(noise_var)
    gap = score - fits[1][0]
    # These are receiver heuristics, not calibrated probabilities.
    accepted = score - baseline >= 0.12 and gap >= 0.10
    aligned = symbol[bins] / scale * np.exp(-1j * phase)

    fig, (left, right) = plt.subplots(1, 2, figsize=(10, 4.3), layout="constrained")
    left.scatter(aligned.real, aligned.imag, s=7, alpha=0.45, color="#8D5B56", label="Measured")
    left.scatter(points.real, points.imag, s=40, marker="+", color="#2C3F50", label="Model")
    left.set(aspect="equal", xlabel="I", ylabel="Q",
             title=f"{candidate} | hold-out RMS error {evm:.3f}")
    left.grid(alpha=0.18)
    left.legend()
    names = [fit[1] for fit in fits]
    scores = [fit[0] - baseline for fit in fits]
    right.barh(names, scores, color=["#8D5B56"] + ["#C88D88"]*(len(fits)-1))
    right.invert_yaxis()
    right.axvline(0, color="#34414c", lw=1, ls=":")
    right.set(title=f"Decision: {candidate if accepted else 'UNKNOWN'}",
              xlabel="Hold-out log likelihood minus Gaussian baseline")
    fig.savefig(plot_path, dpi=160)
    plt.close(fig)

    if not accepted:
        return "UNKNOWN", np.empty(0, dtype=np.uint8)
    nearest = abs(aligned[:, None] - points).argmin(axis=1)
    width = (len(points) - 1).bit_length()
    shifts = np.arange(width - 1, -1, -1)
    bits = ((labels[nearest, None] >> shifts) & 1).astype(np.uint8).ravel()
    return candidate, bits
