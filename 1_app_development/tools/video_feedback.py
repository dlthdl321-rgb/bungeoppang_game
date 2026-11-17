"""게임 화면 녹화(말로 설명한 영상)를 받아쓰기 + 장면 사진으로 나눈다.

사용법 (저장소 루트에서):
    python 1_app_development/tools/video_feedback.py <영상 파일> [출력 폴더]

출력 폴더(기본: 영상 옆 <영상이름>_feedback/)에 만드는 것:
    transcript.md   — 몇 분 몇 초에 무슨 말을 했는지
    frames/         — 말한 구간마다 시작·중간·끝 장면 사진(가로 720px)
    overview/       — 말이 없는 구간도 놓치지 않도록 10초마다 찍은 장면 사진

필요한 패키지: faster-whisper, imageio-ffmpeg (pip install --user ...)
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from faster_whisper import WhisperModel

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
MODEL = "large-v3-turbo"
OVERVIEW_EVERY_SEC = 10
FRAME_WIDTH = 720


def ts(sec: float) -> str:
    m, s = divmod(sec, 60)
    return f"{int(m):02d}:{s:05.2f}"


def grab(video: Path, sec: float, out: Path) -> None:
    subprocess.run(
        [FFMPEG, "-y", "-loglevel", "error", "-ss", f"{sec:.2f}", "-i", str(video),
         "-frames:v", "1", "-vf", f"scale={FRAME_WIDTH}:-2", str(out)],
        check=True,
    )


def duration(video: Path) -> float:
    proc = subprocess.run([FFMPEG, "-i", str(video)], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    for line in proc.stderr.splitlines():
        if "Duration:" in line:
            h, m, s = line.split("Duration:")[1].split(",")[0].strip().split(":")
            return int(h) * 3600 + int(m) * 60 + float(s)
    raise RuntimeError("영상 길이를 읽지 못했습니다.")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    video = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else video.with_name(video.stem + "_feedback")
    (out / "frames").mkdir(parents=True, exist_ok=True)
    (out / "overview").mkdir(parents=True, exist_ok=True)

    total = duration(video)
    print(f"영상 길이 {ts(total)} — 받아쓰기 시작")

    model = WhisperModel(MODEL, device="cpu", compute_type="int8")
    # faster-whisper의 내장 디코더(PyAV)는 버전에 따라 깨지므로 ffmpeg로 16kHz 모노를 직접 뽑는다.
    pcm = subprocess.run(
        [FFMPEG, "-loglevel", "error", "-i", str(video), "-vn", "-ac", "1", "-ar", "16000",
         "-f", "s16le", "-"],
        check=True, capture_output=True,
    ).stdout
    audio = np.frombuffer(pcm, np.int16).astype(np.float32) / 32768.0
    segments, _ = model.transcribe(audio, language="ko", vad_filter=True, beam_size=5)

    lines = [f"# 받아쓰기 — {video.name}", "", f"영상 길이: {ts(total)}", "",
             "| # | 시작 | 끝 | 말 | 장면 사진 |", "|---|---|---|---|---|"]
    for i, seg in enumerate(segments, 1):
        text = seg.text.strip().replace("|", "/")
        shots = []
        for tag, sec in (("a", seg.start), ("b", (seg.start + seg.end) / 2), ("c", seg.end)):
            name = f"{i:03d}{tag}_{ts(sec).replace(':', 'm')}.png"
            grab(video, min(sec, max(total - 0.1, 0)), out / "frames" / name)
            shots.append(f"frames/{name}")
        lines.append(f"| {i} | {ts(seg.start)} | {ts(seg.end)} | {text} | {' '.join(shots)} |")
        print(f"[{ts(seg.start)}] {text}")

    sec = 0.0
    while sec < total:
        grab(video, sec, out / "overview" / f"{ts(sec).replace(':', 'm')}.png")
        sec += OVERVIEW_EVERY_SEC

    (out / "transcript.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"완료: {out}")


if __name__ == "__main__":
    main()
