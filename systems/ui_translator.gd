extends RefCounted

# 씬(.tscn)에 정적으로 박힌 Label/Button 텍스트는 Godot가 자동으로 번역해주지 않는다 —
# 코드에서 tr()을 직접 부른 텍스트만 번역된다. 화면마다 라벨을 하나씩 감싸는 대신
# 여기서 한 번에 훑어 처리하고, 언어가 바뀌면 다시 처리한다.
#
# [경계선] 관리 대상은 bind() 시점에 이미 트리에 있던 Label/Button뿐이다. 그 뒤에 코드가
# 만들어 붙이는 노드(탭·목록 항목 등)는 원문이 한국어라는 보장이 없어(영어로 시작한 판이면
# 영어가 원문으로 잡힌다) 건드리지 않는다 — 그런 텍스트는 각 화면이 tr()로 만들고,
# 언어가 바뀔 때 다시 만들도록 on_locale_changed 콜백을 넘기면 된다.
#
# 이미 코드가 값을 바꿔 쓴 라벨(포맷 문자열/게임 상태 반영)도 건드리지 않는다. 그 판정은
# "지금 있는 문자열이 우리가 마지막으로 써넣은 값 그대로인가"로 한다.
#
# static func 안에서는 tr()(Object 인스턴스 메서드)을 쓸 수 없어 TranslationServer를 직접 쓴다.

const SOURCE_META := "i18n_source"
const APPLIED_META := "i18n_applied"

static var _entries: Array = []
static var _hooked: bool = false


# 지금 한 번 번역하고, 이후 언어가 바뀔 때마다 다시 번역되도록 등록한다.
# 화면 _ready() 맨 앞에서 부르면 뒤이어 코드가 채우는 동적 텍스트가 항상 이깁니다.
# on_locale_changed: 언어가 바뀔 때 그 화면이 스스로 다시 만들어야 하는 텍스트가 있으면 넘긴다
static func bind(root: Node, on_locale_changed := Callable()) -> void:
	if not _hooked:
		_hooked = true
		LocaleManager.locale_changed.connect(_on_locale_changed)

	_entries = _entries.filter(func(e): return is_instance_valid(e["root"])) # 씬이 바뀔 때마다 등록되므로 죽은 것부터 걷어낸다

	var managed: Array[Control] = []
	_collect(root, managed)
	_entries.append({"root": root, "managed": managed, "callback": on_locale_changed})
	_apply(managed)


static func _collect(node: Node, out: Array[Control]) -> void:
	if node is Label or node is Button:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


static func _on_locale_changed(_locale: String) -> void:
	var alive: Array = []
	for entry in _entries:
		if not is_instance_valid(entry["root"]):
			continue
		alive.append(entry)
		_apply(entry["managed"])
		var callback: Callable = entry["callback"]
		if callback.is_valid():
			callback.call()
	_entries = alive


static func _apply(managed: Array[Control]) -> void:
	for node in managed:
		if is_instance_valid(node):
			_translate(node)


static func _translate(node: Control) -> void:
	var current: String = node.text
	if not node.has_meta(SOURCE_META):
		if current == "":
			return
		node.set_meta(SOURCE_META, current)
	elif current != node.get_meta(APPLIED_META, "") and current != node.get_meta(SOURCE_META):
		return

	var translated := TranslationServer.translate(node.get_meta(SOURCE_META))
	node.text = translated
	node.set_meta(APPLIED_META, translated)
