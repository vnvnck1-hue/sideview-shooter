# 면 맵 (face maps)

프랍의 면을 손으로 나눈 그림. `assets/` 아래와 **같은 상대경로**를 쓴다.

    assets/props/workshop_locker_game_scale.png        원화
    assets/faces/props/workshop_locker_game_scale.png  ← 여기

칠하는 색 (안티에일리어싱 없이, 순색으로):

| 색 | 면 |
|---|---|
| 파랑 `#0000FF` | 정면 |
| 빨강 `#FF0000` | 상판 |
| 초록 `#00FF00` | 좌측면 |
| 노랑 `#FFFF00` | 우측면 |
| 자홍 `#FF00FF` | 밑면 |
| 청록 `#00FFFF` | 좌상 경사 |
| 흰색 `#FFFFFF` | 우상 경사 |

비워 둔 곳(알파 0)은 기존 자동 노멀을 그대로 쓴다 — 큰 면만 칠해도 된다.

## 각진 것 / 부드러운 것

- **각진 것**(사물함·작업대): 면을 꽉 채워 칠하고 `soft: 0`. 칠한 대로 딱 갈라진다.
- **부드러운 것**(소파·쿠션): 각 면의 **코어만 최소한으로** 찍고 `soft` 를 키운다(20px 내외).
  베이커가 노멀 필드를 번지게 해 코어 사이를 그라데이션으로 잇는다 — 있지도 않은 모서리가 생기지 않게.
  `assets/faces/props/workshop_armchair_game_scale.png` 가 그 예다 (실루엣의 33% 만 칠해져 있다).

수치는 `GodotPrototype/faces/tuning.json` 에 자산별로 둔다.

이 폴더에는 `.gdignore` 가 있어 **Godot 이 임포트하지 않는다.** 면 맵은 런타임에 원본 PNG 를 직접 읽으므로
(`FaceNormal.load_png`) 그림을 고치고 저장하면 재임포트 없이 랩에서 `R` 만 누르면 바로 반영된다.

나누는 곳: 로비 → 면 라이팅 랩 (`scripts/face_lab.gd`)
굽는 곳: `godot --path GodotPrototype --headless --script res://tools/bake_face_normals.gd`
문서: `Docs/FACE_LIGHTING.md`
