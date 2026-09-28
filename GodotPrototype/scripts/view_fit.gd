extends Node
## 창을 꽉 채우는 정수 배율 캔버스 + 화면 모드(창 / 전체화면) (autoload "ViewFit", 2026-09-25).
##
## ── 캔버스 ──
## 엔진의 정수 배율 스트레치(scale_mode="integer")는 쓰지 않는다 — **정수 배율은 여기서 직접 맞춘다.**
##   · integer + expand 는 캔버스 크기를 **분수 배율**로 먼저 정하고(2400×1494 창 ÷ 1.5 = 1600×995) 배율만
##     정수로 내려(×1) 1600×995 캔버스가 창 가운데 떴다.
##   · 그걸 content_scale_size 로 바로잡아도 **전체화면에서는 엔진 쪽 integer 경로가 출력 전체를 다시 2/3 로 줄여**
##     모니터 가운데 1600×1067 에만 그렸다 (2026-09-25, 실제 모니터 캡처로 확인. Godot 창이 보고하는 크기·
##     최종 변환은 정상이라 렌더 텍스처 캡처로는 보이지 않았다. 설정 없는 최소 프로젝트에 integer 스트레치만
##     넣어도 재현된다 — 150% 배율 모니터 2400×1600).
## 그래서 project.godot 은 scale_mode="fractional" 이고, 여기서 배율 k 를 정수로 고른 뒤(최소 캔버스
## AppFlow.VIEW_SIZE 가 들어가는 가장 큰 정수, 최소 1) 기준 크기(content_scale_size)를 **창 ÷ k** 로 넣는다.
## 그러면 분수 배율이 정확히 k 가 되어 아트 1px = 화면 정수 px 규칙이 지켜지고 캔버스가 창 전체를 덮는다.
##   2400×1494 창 → k 1 → 캔버스 2400×1494      3840×2160 → k 2 → 1920×1080      1600×900 → k 1
##
## ── 화면 모드 ──
## 로비의 "화면 모드" 드롭다운과 게임 안 F11 이 모두 여기를 거친다(set_fullscreen / toggle_fullscreen).
## 고른 값은 user://display.cfg 에 저장되고 다음 실행 때 그대로 시작한다. 창 모드는 **최대화된 창**이다 —
## 화면을 최대한 넓게 쓰는 것이 기본 방침이라서다(창 크기를 줄이는 건 사용자가 창 테두리로 한다).
## 환경 변수 DISPLAY_MODE=window|fullscreen 이 있으면 저장값보다 앞선다 (스크린샷 도구가 화면을 강제할 때).
##
## 자동 로드 이름(ViewFit)을 코드에 그대로 쓰면 --script 도구에서 컴파일이 깨지므로(TerminalScreen 주석 참고)
## 게임 씬은 get_tree().root.get_node("ViewFit") 로 찾아 쓴다. 로비는 도구가 열지 않으므로 이름을 그대로 쓴다.

signal mode_changed(fullscreen: bool)

const SAVE_PATH := "user://display.cfg"

var fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_fit)
	_fit()
	set_fullscreen(_initial_fullscreen(), false)


func _initial_fullscreen() -> bool:
	var env := OS.get_environment("DISPLAY_MODE").to_lower()
	if env == "fullscreen":
		return true
	if env == "window":
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return bool(cfg.get_value("display", "fullscreen", false))
	return false


## 화면 모드를 바꾼다. save = user://display.cfg 에 남길지 (시작할 때 복원하는 호출만 false)
func set_fullscreen(on: bool, save := true) -> void:
	var w := get_tree().root
	if on:
		w.mode = Window.MODE_FULLSCREEN
	else:
		# 전체화면 → 최대화로 바로 가면 일부 환경에서 창 크기가 전체화면 값에 묶여 남는다. 창으로 한 번 풀고 최대화한다
		if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			w.mode = Window.MODE_WINDOWED
		w.mode = Window.MODE_MAXIMIZED
	var changed := fullscreen != on
	fullscreen = on
	if save:
		var cfg := ConfigFile.new()
		cfg.set_value("display", "fullscreen", on)
		cfg.save(SAVE_PATH)
	if changed:
		mode_changed.emit(on)


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func _fit() -> void:
	var root := get_tree().root
	var win := Vector2(root.size)
	if win.x <= 0.0 or win.y <= 0.0:
		return
	var base := Vector2(AppFlow.VIEW_SIZE)
	var k := maxi(1, int(floor(minf(win.x / base.x, win.y / base.y))))
	var want := Vector2i((win / float(k)).floor())
	if root.content_scale_size != want:
		root.content_scale_size = want
