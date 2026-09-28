extends Node
## 규격 테스트 씬: 플레이어가 움직인 **뒤** 발 높이를 맞추는 한 줄짜리 노드.
## process_priority 5 — 플레이어(0) 다음, 카메라(10) 전. 판정 자체는 scale_lab.gd 의 settle_feet 에 있다.

var lab: Node


func _process(delta: float) -> void:
	if lab != null and lab.player != null and lab.current_room != null:
		lab.settle_feet(delta)
