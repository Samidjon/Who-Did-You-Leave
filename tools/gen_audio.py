#!/usr/bin/env python3
"""Процедурные звуки-заглушки для «Кого ты оставил?».

Синтез с нуля (шум, фильтры, затухающие резонансы), без сторонних записей.
Зацикленные фоны строятся периодическими, чтобы не было щелчка на стыке.
Это временные слоты: замените файлы настоящими записями с теми же именами.

Запуск:  python3 tools/gen_audio.py <путь_к_проекту>
"""
import sys, os
import numpy as np
from scipy import signal
import wave

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
SR = 22050
rng = np.random.default_rng(415)


def path(sub, name):
    d = os.path.join(ROOT, "assets", "audio", sub)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name)


def write(sub, name, x, peak=0.85):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path(sub, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("audio", sub, name, f"{len(x)/SR:.2f}s")


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(n):
    return rng.standard_normal(n)


def periodic_noise(dur, lo, hi, beta=0.0):
    """Шум с полосой lo..hi Гц, идеально периодичный на длине dur."""
    n = int(dur * SR)
    F = np.fft.rfft(noise(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = (f >= lo) & (f <= hi)
    f2 = f.copy()
    f2[0] = 1
    F = F * mask / (f2 ** (beta / 2))
    return np.fft.irfft(F, n)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, hi, order=2):
    sos = signal.butter(order, hi, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, lo, order=2):
    sos = signal.butter(order, lo, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]
    return buf


def reverb(x, size=0.6, mix=0.3, damp=3000):
    n = int(size * SR)
    ir = noise(n) * np.exp(-np.arange(n) / (SR * size / 5))
    ir = lp(ir, damp)
    wet = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    wet = wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(x))
    return dry * (1 - mix) + wet * mix


def resonator(x, freq, q=30):
    b, a = signal.iirpeak(freq, q, fs=SR)
    return signal.lfilter(b, a, x)


# ------------------------------------------------------------------ фоны
def building_hum():
    dur = 12.0
    t = t_axis(dur)
    hum = (np.sin(2 * np.pi * 50 * t) * 0.25 + np.sin(2 * np.pi * 100 * t) * 0.12
           + np.sin(2 * np.pi * 150 * t) * 0.05)
    hum *= 0.7 + 0.3 * np.sin(2 * np.pi * t / dur * 2)
    air = periodic_noise(dur, 30, 700, beta=1.0)
    air /= np.max(np.abs(air))
    vent = periodic_noise(dur, 200, 1800, beta=0.5)
    vent /= np.max(np.abs(vent))
    vent *= 0.6 + 0.4 * np.sin(2 * np.pi * t / dur * 3 + 1)
    write("ambience", "amb_building_hum.wav", hum * 0.4 + air * 0.6 + vent * 0.12, 0.6)


def pipes_water():
    dur = 8.0
    t = t_axis(dur)
    flow = periodic_noise(dur, 300, 2500, beta=0.6)
    flow /= np.max(np.abs(flow))
    mod = 0.5 + 0.5 * np.sin(2 * np.pi * t * 3 / dur) * np.sin(2 * np.pi * t * 7 / dur)
    gurgle = np.zeros_like(t)
    for k in range(10):
        at = rng.uniform(0, dur - 0.4)
        n = int(0.25 * SR)
        f0 = rng.uniform(300, 700)
        tt = np.arange(n) / SR
        g = np.sin(2 * np.pi * (f0 + 900 * tt) * tt) * env(n, 0.01, 0.06)
        place(gurgle, g * 0.4, at)
    write("ambience", "amb_pipes_water.wav", flow * (0.3 + 0.7 * mod) * 0.5 + gurgle, 0.5)


def fridge():
    dur = 6.0
    t = t_axis(dur)
    x = sum(np.sin(2 * np.pi * f * t) / (i + 1) for i, f in enumerate([120, 240, 360, 480]))
    x += periodic_noise(dur, 80, 400) * 3
    write("ambience", "amb_fridge_hum.wav", x, 0.4)


def stairwell():
    dur = 10.0
    t = t_axis(dur)
    w = periodic_noise(dur, 40, 900, beta=1.6)
    w /= np.max(np.abs(w))
    w *= 0.5 + 0.5 * np.sin(2 * np.pi * t * 2 / dur) ** 2
    whistle = np.sin(2 * np.pi * 620 * t + 3 * np.sin(2 * np.pi * t * 1 / dur)) * 0.02 * (np.sin(2 * np.pi * t / dur) ** 4)
    write("ambience", "amb_stairwell_wind.wav", w + whistle, 0.5)


def menu_drone():
    dur = 20.0
    t = t_axis(dur)
    freqs = [55.0, 82.35, 110.0, 130.8, 164.8]
    freqs = [round(f * dur) / dur for f in freqs]
    x = np.zeros_like(t)
    for i, f in enumerate(freqs):
        detune = (i + 1) / dur
        x += np.sin(2 * np.pi * f * t) * (0.5 / (i + 1)) * (0.6 + 0.4 * np.sin(2 * np.pi * t * (i + 1) / dur))
        x += np.sin(2 * np.pi * (f + detune) * t) * (0.3 / (i + 1))
    tape = periodic_noise(dur, 1000, 6000) * 0.8
    write("music", "music_menu_drone.wav", x + tape, 0.45)


# ------------------------------------------------------------------ шаги
def step(name, hard=False, seed_shift=0):
    n = int(0.28 * SR)
    tt = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (rng.uniform(70, 110) - 30 * tt) * tt) * env(n, 0.002, 0.035)
    scuff = bp(noise(n), 800 if not hard else 1500, 4000 if not hard else 7000) * env(n, 0.004, 0.03 if not hard else 0.02)
    heel = np.zeros(n)
    place(heel, bp(noise(int(0.05 * SR)), 300, 2000) * env(int(0.05 * SR), 0.001, 0.012), rng.uniform(0.04, 0.07))
    x = thump * 0.8 + scuff * (0.35 if not hard else 0.6) + heel * 0.4
    write("sfx", name, reverb(x, 0.35, 0.12), 0.7)


# ------------------------------------------------------------------ двери
def door_creak():
    dur = 1.6
    n = int(dur * SR)
    tt = np.arange(n) / SR
    rate = 90 + 160 * np.sin(np.pi * tt / dur) ** 2 + 40 * np.sin(2 * np.pi * 3.1 * tt)
    phase = np.cumsum(rate / SR)
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    pulses *= 0.6 + 0.4 * rng.random(n)
    body = resonator(pulses, 820, 12) + resonator(pulses, 1460, 15) * 0.7 + resonator(pulses, 2600, 20) * 0.4
    amp = np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 0.7
    latch = np.zeros(n)
    place(latch, bp(noise(800), 1500, 6000) * env(800, 0.001, 0.008), 0.0)
    write("sfx", "door_open_creak.wav", reverb(body * amp * 0.6 + latch * 0.8, 0.5, 0.25), 0.75)


def door_close():
    n = int(0.6 * SR)
    tt = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (85 - 40 * tt) * tt) * env(n, 0.002, 0.07)
    knock = bp(noise(n), 150, 1200) * env(n, 0.001, 0.04)
    latch = np.zeros(n)
    place(latch, bp(noise(600), 2000, 7000) * env(600, 0.0005, 0.006), 0.012)
    write("sfx", "door_close.wav", reverb(thud + knock * 0.6 + latch * 0.6, 0.6, 0.3), 0.8)


def clack(n_len=0.06, lo=1200, hi=6000, f=2400):
    n = int(n_len * SR)
    return resonator(bp(noise(n), lo, hi), f, 8) * env(n, 0.0005, 0.012) + bp(noise(n), lo, hi) * env(n, 0.0005, 0.006)


def door_locked():
    x = np.zeros(int(0.8 * SR))
    for i, at in enumerate([0.0, 0.12, 0.27, 0.36]):
        place(x, clack(f=1800 + 300 * i) * (1.0 - 0.15 * i), at)
    place(x, np.sin(2 * np.pi * 110 * t_axis(0.2)) * env(int(0.2 * SR), 0.002, 0.04) * 0.5, 0.02)
    write("sfx", "door_locked_rattle.wav", reverb(x, 0.4, 0.2), 0.7)


def door_unlock():
    x = np.zeros(int(0.7 * SR))
    place(x, clack(f=3000) * 0.6, 0.0)
    place(x, clack(f=2200, n_len=0.09), 0.22)
    place(x, clack(f=1600, n_len=0.1) * 1.2, 0.4)
    write("sfx", "door_unlock.wav", reverb(x, 0.3, 0.2), 0.7)


def grate_open():
    dur = 1.8
    n = int(dur * SR)
    tt = np.arange(n) / SR
    scrape = bp(noise(n), 600, 5000) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 5 * tt)))
    ring = sum(resonator(noise(n) * 0.02, f, 60) for f in [523, 1187, 2011, 3320])
    pulses = (rng.random(n) < (40 / SR)).astype(float)
    squeal = resonator(pulses, 1300, 25) * 3
    amp = np.sin(np.pi * tt / dur) ** 0.5
    x = (scrape * 0.3 + ring * 2 + squeal) * amp
    place(x, clack(f=900, n_len=0.15) * 2, 0.0)
    write("sfx", "grate_open.wav", reverb(x, 0.9, 0.35), 0.75)


def key_pickup():
    x = np.zeros(int(0.7 * SR))
    for i in range(5):
        n = int(0.4 * SR)
        tt = np.arange(n) / SR
        f = rng.uniform(2500, 5200)
        ping = (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 2.76 * tt)) * env(n, 0.0005, 0.06)
        place(x, ping * rng.uniform(0.4, 1.0), i * 0.05 + rng.uniform(0, 0.03))
    write("sfx", "key_pickup.wav", reverb(x, 0.3, 0.2), 0.6)


def paper():
    dur = 0.7
    n = int(dur * SR)
    tt = np.arange(n) / SR
    crackle = (rng.random(n) < 0.02).astype(float) * rng.standard_normal(n)
    body = hp(noise(n), 1500) * (0.3 + 0.7 * np.abs(signal.sosfilt(signal.butter(2, 12, fs=SR, output="sos"), noise(n)) * 20))
    x = (body * 0.25 + hp(crackle, 2000)) * np.sin(np.pi * tt / dur) ** 0.6
    write("sfx", "paper_rustle.wav", x, 0.55)


def switch_click():
    x = np.zeros(int(0.25 * SR))
    place(x, clack(f=3500, n_len=0.03), 0.0)
    place(x, clack(f=1800, n_len=0.05) * 0.8, 0.018)
    write("sfx", "switch_click.wav", reverb(x, 0.25, 0.15), 0.6)
    y = np.zeros(int(0.2 * SR))
    place(y, clack(f=4200, n_len=0.025), 0.0)
    place(y, clack(f=2600, n_len=0.03) * 0.7, 0.04)
    write("sfx", "flashlight_click.wav", y, 0.45)
    z = clack(f=1400, n_len=0.04) * 0.6
    write("sfx", "ui_click.wav", np.concatenate([z, np.zeros(1000)]), 0.35)


def fuse_clunk():
    dur = 1.4
    n = int(dur * SR)
    tt = np.arange(n) / SR
    thunk = np.sin(2 * np.pi * (70 - 20 * tt) * tt) * env(n, 0.001, 0.08)
    metal = clack(f=900, n_len=0.2)
    saw = signal.sawtooth(2 * np.pi * 100 * tt) * env(n, 0.05, 0.4) * 0.3
    x = thunk + saw
    place(x, metal * 1.2, 0.0)
    place(x, bp(noise(3000), 3000, 9000) * env(3000, 0.0, 0.03) * 0.8, 0.05)
    write("sfx", "fuse_clunk.wav", reverb(x, 0.6, 0.3), 0.8)


# ------------------------------------------------------------------ устройства
def intercom_buzz():
    dur = 2.0
    tt = t_axis(dur)
    sq = signal.square(2 * np.pi * 380 * tt) * (0.6 + 0.4 * signal.square(2 * np.pi * 25 * tt))
    sq = bp(sq, 300, 3000)
    gate = (tt < 1.2).astype(float)
    gate = signal.sosfilt(signal.butter(1, 60, fs=SR, output="sos"), gate)
    write("sfx", "intercom_buzz.wav", sq * gate + bp(noise(len(tt)), 2000, 6000) * 0.05 * gate, 0.5)


def phone_ring():
    dur = 4.0
    tt = t_axis(dur)
    striker = (signal.square(2 * np.pi * 20 * tt) > 0).astype(float)
    hits = np.diff(striker, prepend=0)
    hits = np.abs(hits) * ((tt < 1.8).astype(float))
    bell = sum(resonator(hits, f, 120) * a for f, a in [(1020, 1), (1360, 0.7), (2470, 0.4), (3300, 0.2)])
    write("sfx", "phone_ring.wav", reverb(bell, 0.5, 0.2)[: len(tt)], 0.6)


def phone_pickup():
    x = np.zeros(int(0.6 * SR))
    place(x, clack(f=1000, n_len=0.12) * 1.2, 0.0)
    place(x, bp(noise(4000), 400, 3000) * env(4000, 0.02, 0.06) * 0.4, 0.1)
    write("sfx", "phone_pickup.wav", x, 0.6)


def radio_static():
    dur = 4.0
    tt = t_axis(dur)
    s = periodic_noise(dur, 400, 5000, beta=0.3)
    s /= np.max(np.abs(s))
    crack = np.zeros_like(tt)
    for _ in range(25):
        place(crack, noise(200) * env(200, 0, 0.002) * rng.uniform(1, 3), rng.uniform(0, dur - 0.02))
    wob = 0.7 + 0.3 * np.sin(2 * np.pi * tt * 3 / dur)
    tone = np.sin(2 * np.pi * (1000 + 30 * np.sin(2 * np.pi * tt / dur)) * tt) * 0.03
    write("sfx", "radio_static.wav", s * wob * 0.5 + crack + tone, 0.5)


# ------------------------------------------------------------------ сюжетные
def pipe_knock(strength=1.0):
    n = int(0.9 * SR)
    tt = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (95 - 30 * tt) * tt) * env(n, 0.001, 0.05)
    ring = sum(np.sin(2 * np.pi * f * tt) * env(n, 0.001, d) * a
               for f, d, a in [(412, 0.35, 0.25), (1097, 0.2, 0.15), (1873, 0.12, 0.08)])
    click = bp(noise(n), 800, 5000) * env(n, 0.0005, 0.01)
    return (thump + ring + click * 0.5) * strength


def knock_three():
    x = np.zeros(int(3.0 * SR))
    for i, at in enumerate([0.0, 0.62, 1.24]):
        place(x, pipe_knock(1.0 - 0.05 * i), at)
    write("sfx", "knock_three.wav", reverb(x, 1.0, 0.3), 0.85)
    far = lp(x, 900)
    write("sfx", "knock_three_far.wav", reverb(far, 1.4, 0.45), 0.6)
    y = np.zeros(int(2.6 * SR))
    for i, at in enumerate([0.0, 0.5, 1.0]):
        place(y, pipe_knock(0.9), at)
        place(y, hp(clack(f=1500, n_len=0.05), 500) * 0.3, at)
    write("sfx", "knock_player.wav", reverb(y, 0.6, 0.2), 0.8)


def pipe_bang():
    n = int(3.0 * SR)
    tt = np.arange(n) / SR
    hammer = np.sin(2 * np.pi * (60 - 10 * tt) * tt) * env(n, 0.001, 0.12)
    ring = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * env(n, 0.001, d) * a
               for f, d, a in [(236, 1.2, 0.3), (611, 0.9, 0.2), (1143, 0.6, 0.15), (1789, 0.4, 0.1), (2650, 0.25, 0.06)])
    x = hammer + ring
    for k in range(4):
        place(x, pipe_knock(0.25) * 0.5, 0.35 + k * 0.17)
    write("sfx", "pipe_bang.wav", reverb(x, 1.2, 0.35), 0.85)


def distant_steps():
    x = np.zeros(int(4.5 * SR))
    for i in range(5):
        n = int(0.3 * SR)
        tt = np.arange(n) / SR
        s = np.sin(2 * np.pi * (80 - 30 * tt) * tt) * env(n, 0.003, 0.05) + bp(noise(n), 300, 1500) * env(n, 0.003, 0.03) * 0.3
        place(x, s * (0.6 + 0.1 * i), 0.3 + i * 0.82)
    write("sfx", "distant_steps.wav", reverb(lp(x, 700), 1.6, 0.5), 0.5)


def figure_presence():
    dur = 3.5
    tt = t_axis(dur)
    swell = np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 2
    rise = np.clip(tt / (dur * 0.7), 0, 1) ** 3 * (tt < dur * 0.72)
    sub = np.sin(2 * np.pi * (38 + 6 * tt) * tt) * swell
    breath = bp(noise(len(tt)), 300, 2500) * rise
    breath = signal.sosfilt(signal.butter(2, [400, 1400], btype="band", fs=SR, output="sos"), breath)
    hiss = hp(noise(len(tt)), 4000) * swell * 0.05
    write("sfx", "figure_presence.wav", reverb(sub * 0.7 + breath * 3 + hiss, 1.2, 0.3), 0.75)


def whisper():
    dur = 3.2
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    syll = [(0.2, 0.22), (0.5, 0.18), (0.8, 0.3), (1.45, 0.2), (1.75, 0.35), (2.35, 0.25)]
    for at, ln in syll:
        m = int(ln * SR)
        src = noise(m)
        f1 = rng.uniform(500, 900)
        f2 = rng.uniform(1300, 2400)
        v = resonator(src, f1, 6) + resonator(src, f2, 8) * 0.7 + hp(src, 4500) * 0.15
        place(x, v * env(m, 0.03, ln / 2.5), at)
    x = lp(x, 2400)  # «через дверь»
    write("sfx", "whisper_behind_door.wav", reverb(x, 0.8, 0.35), 0.6)


def light_buzz():
    dur = 2.0
    tt = t_axis(dur)
    x = sum(np.sin(2 * np.pi * f * tt) / k for k, f in enumerate([100, 200, 300, 500, 700], 1))
    x += bp(periodic_noise(dur, 2000, 6000), 2000, 6000) * 4
    write("sfx", "light_buzz.wav", x, 0.35)


def sting_low():
    dur = 3.0
    tt = t_axis(dur)
    e = env(len(tt), 0.02, 1.0)
    x = (np.sin(2 * np.pi * 49 * tt) + 0.5 * np.sin(2 * np.pi * 73.4 * tt) + 0.3 * np.sin(2 * np.pi * 103.8 * tt)) * e
    x += lp(noise(len(tt)), 300) * e * 0.3
    write("sfx", "sting_low.wav", reverb(x, 1.5, 0.4), 0.7)


if __name__ == "__main__":
    building_hum(); pipes_water(); fridge(); stairwell(); menu_drone()
    for i in range(4):
        step(f"step_0{i+1}.wav")
    for i in range(2):
        step(f"step_concrete_0{i+1}.wav", hard=True)
    door_creak(); door_close(); door_locked(); door_unlock(); grate_open()
    key_pickup(); paper(); switch_click(); fuse_clunk()
    intercom_buzz(); phone_ring(); phone_pickup(); radio_static()
    knock_three(); pipe_bang(); distant_steps(); figure_presence(); whisper(); light_buzz(); sting_low()
