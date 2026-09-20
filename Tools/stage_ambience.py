# 채택한 앰비언스 루프만 Godot 프로젝트로 옮긴다.
#
# 2026-09-20 오디션(Downloads/ambience_review.html)에서 확정된 11개만 다룬다.
# 채택되지 않은 것은 쓰지 않는다 — 후보를 늘리려면 먼저 오디션 페이지에서 고를 것.
#
# 하는 일 세 가지:
#   1) WAV → OGG Vorbis 변환. audio_manager._looped() 가 AudioStreamOggVorbis 에만
#      loop=true 를 걸기 때문에 WAV 로 두면 베드가 한 번 울리고 끝난다. 변환은 선택이 아니다.
#   2) RMS 정규화(-14 dBFS). 원본 레벨이 -13 ~ -24 dBFS 로 제각각이라 그대로 두면
#      방마다 앰비언스 크기가 널뛴다. 여기서 맞춰 두면 BED_DB 하나로 전체가 잡힌다.
#      목표값 -14 는 임의로 고른 값이 아니라 옛 베드(Kenney rumble_*, -7.6 dBFS)와
#      audio_manager 의 BED_DB 가 맞물려 있던 지점에서 역산한 것이다.
#      처음에 -24 로 잡았다가 실제 게임에서 앰비언스가 통째로 안 들렸다 — 17dB 모자랐다.
#   3) 라이선스 증빙을 _licenses/ 에 남긴다.
#
# 사용:
#   python Tools/stage_ambience.py
#   python Tools/stage_ambience.py --dry-run

import argparse
import os
import sys

import numpy as np
import soundfile as sf

try:  # 콘솔이 cp949 여도 한글 로그가 깨지지 않게
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

SRC_ROOT = r"C:\Users\vnvnc\Downloads"
BZ = r"UltraSciFiGameAudioAmbiencePack\UltraSciFiGameAudioAmbiencePack"
SL = "sfx_loops"

OUT_REL = os.path.join("GodotPrototype", "assets", "audio", "ambience")
TARGET_RMS_DB = -14.0

# (원본, 대상, 용도) — 대상 이름은 audio_manager.gd 가 참조할 이름이다.
FILES = [
    # --- L1 BED ---
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 15_Eric Berzins_USFA.wav",
     "bed_common.ogg", "전 구역 기본 베드"),
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 8_Eric Berzins_USFA.wav",
     "bed_workshop.ogg", "정비 구역 베드 — 작업실·정비 홀·격납고"),
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 6_Eric Berzins_USFA.wav",
     "bed_power.ogg", "전력 구역 베드 — 릴레이실·축전기 저장고·발전실"),
    # --- L2 TEXTURE ---
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 13_Eric Berzins_USFA.wav",
     "tex_power_highvolt.ogg", "전력 릴레이실 고전압 위협감"),
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 11_Eric Berzins_USFA.wav",
     "tex_hydro_air.ogg", "수경재배 공조·습한 공기"),
    (rf"{BZ}\AMBSci_Sci-Fi Ambience Loop 7_Eric Berzins_USFA.wav",
     "tex_crew_quiet.ogg", "승무원 구역 — 침실·복도"),
    (rf"{SL}\machine_11.ogg", "tex_power_machine_01.ogg", "전력 릴레이실 기계 험"),
    (rf"{SL}\machine_08.ogg", "tex_power_machine_02.ogg", "비상 발전실·축전기 저장고"),
    (rf"{SL}\pump_01.ogg", "tex_hydro_pump.ogg", "급수 통로·저수조실 펌프"),
    (rf"{SL}\water_flowing.ogg", "tex_hydro_water.ogg", "저수조실 물 흐름"),
    (rf"{SL}\noise_01.ogg", "tex_terminal_noise.ogg", "단말기 근접 노이즈·조명 지지직"),
]

LICENSES = {
    "UltraSciFiAmbience_EricBerzins.txt": """Ultra Sci-Fi Game Audio Ambience Pack — Eric Berzins
출처: https://eberzins.itch.io/ultra-sci-fi-game-audio-ambience-pack
확인일: 2026-09-20

무료. 게임·영상·앱 등에 로열티 없이 동기화/임베드/믹스 가능(상업 포함).
크레딧 불필요(권장).
금지: 사운드 파일 자체의 판매·재배포, 저작자 사칭, 생성형 AI 학습 사용.

사용 파일: bed_common / bed_workshop / bed_power /
          tex_power_highvolt / tex_hydro_air / tex_crew_quiet
(WAV 원본을 OGG 로 변환하고 RMS 정규화함 — 위 라이선스가 허용하는 범위의 가공)
""",
    "OGA_30_CC0_SFX_loops.txt": """30 CC0 SFX loops — OpenGameArt
출처: https://opengameart.org/content/30-cc0-sfx-loops
확인일: 2026-09-20

라이선스: CC0 1.0 (퍼블릭 도메인). 크레딧 불필요, 상업 사용 허용.
https://creativecommons.org/publicdomain/zero/1.0/

사용 파일: tex_power_machine_01(machine_11) / tex_power_machine_02(machine_08) /
          tex_hydro_pump(pump_01) / tex_hydro_water(water_flowing) /
          tex_terminal_noise(noise_01)
""",
}


def stage(src_root: str, out_dir: str, dry: bool) -> int:
    lic_dir = os.path.join(os.path.dirname(out_dir), "_licenses")
    errs = 0
    for rel, dest, use in FILES:
        src = os.path.join(src_root, rel)
        if not os.path.exists(src):
            print(f"  [없음] {rel}")
            errs += 1
            continue
        data, sr = sf.read(src, always_2d=True, dtype="float32")
        rms = float(np.sqrt(np.mean(data ** 2)))
        gain = 10 ** ((TARGET_RMS_DB - 20 * np.log10(rms + 1e-12)) / 20)
        out = data * gain
        peak = float(np.max(np.abs(out)))
        # 정규화가 클리핑을 만들면 피크 -1dBFS 로 되돌린다
        if peak > 0.891:
            out *= 0.891 / peak
            print(f"  (피크 제한 적용) {dest}")
        # crest 가 큰 파일은 피크에 걸려 목표 RMS 에 못 닿는다. 얼마나 모자란지 찍어 둔다 —
        # audio_manager 의 TEX_TRIM 이 그만큼을 재생 게인으로 되돌린다.
        got = 20 * np.log10(float(np.sqrt(np.mean(out ** 2))) + 1e-12)
        short = TARGET_RMS_DB - got
        note = f"  (목표보다 {short:.1f}dB 낮음 → TEX_TRIM 필요)" if short > 1.0 else ""
        path = os.path.join(out_dir, dest)
        print(f"  {dest:26s} RMS {got:6.1f}dB <- {os.path.basename(src)[:40]:42s} {use}{note}")
        if not dry:
            # 통째로 넘기면 libsndfile 의 vorbis 인코더가 20초 넘는 버퍼에서 죽는다.
            # 1초씩 끊어 쓰면 문제없다.
            with sf.SoundFile(path, "w", samplerate=sr, channels=out.shape[1],
                              format="OGG", subtype="VORBIS") as f:
                for i in range(0, len(out), sr):
                    f.write(out[i:i + sr])
    if not dry:
        os.makedirs(lic_dir, exist_ok=True)
        for name, body in LICENSES.items():
            with open(os.path.join(lic_dir, name), "w", encoding="utf-8") as f:
                f.write(body)
        print(f"  라이선스 증빙 {len(LICENSES)}개 -> {lic_dir}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_ROOT)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, OUT_REL)
    if not os.path.isdir(out_dir):
        print(f"대상 폴더가 없습니다: {out_dir}")
        return 1
    print(f"원본: {a.src}\n대상: {out_dir}\n")
    errs = stage(a.src, out_dir, a.dry_run)
    if errs:
        print(f"\n{errs}개 파일을 찾지 못했습니다.")
        return 1
    print("\n완료. Godot 에서 재임포트 필요 (run.bat 이 헤드리스 임포트를 수행함).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
