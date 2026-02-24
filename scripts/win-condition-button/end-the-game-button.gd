extends Node3D
## Tracks how many EndTheGameButton instances are activated.
## When only one is active, shows a hint. When both are active, transitions to credits.

const END_CREDITS_PATH := "res://scenes/end_credits/end_credits.tscn"
const HINT_TEXT := "find the last book to pass on"
const ACCENT := Color("#c8a2e6")
const FADE_DURATION := 1.2

static var _active_count: int = 0

@onready var _switch: Area3D = $Switch

var _canvas_layer: CanvasLayer
var _hint_label: RichTextLabel
var _fade_overlay: ColorRect
var _hint_tween: Tween
var _is_on: bool = false

func _ready() -> void:
	_create_hint_ui()
	_create_fade_overlay()
	_switch.switched_on.connect(_on_switched_on)
	_switch.switched_off.connect(_on_switched_off)

# ── Signal handlers ───────────────────────────────────────────────

func _on_switched_on() -> void:
	if _is_on:
		return
	_is_on = true
	_active_count += 1
	print("[EndGameButton] Active count: ", _active_count)

	if _active_count >= 2:
		_transition_to_credits()
	else:
		_show_hint()

func _on_switched_off() -> void:
	if not _is_on:
		return
	_is_on = false
	_active_count = maxi(_active_count - 1, 0)
	print("[EndGameButton] Active count: ", _active_count)
	_hide_hint()

# ── Hint UI ───────────────────────────────────────────────────────

func _create_hint_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 99
	add_child(_canvas_layer)

	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.text = HINT_TEXT
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Pin to bottom of screen
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = 0.0
	_hint_label.offset_right = 0.0
	_hint_label.offset_top = -60.0
	_hint_label.offset_bottom = -20.0
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_hint_label.add_theme_font_size_override("normal_font_size", 28)
	_hint_label.add_theme_color_override("default_color", ACCENT)

	_hint_label.modulate = Color(1, 1, 1, 0)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_hint_label)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.anchor_left = 0.0
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_top = 0.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.modulate = Color(1, 1, 1, 0)
	_canvas_layer.add_child(_fade_overlay)

func _show_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.4)

func _hide_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.4)

# ── Credits transition ────────────────────────────────────────────

func _transition_to_credits() -> void:
	_hide_hint()
	var tw := create_tween()
	tw.tween_property(_fade_overlay, "modulate:a", 1.0, FADE_DURATION)
	tw.tween_callback(_load_credits)

func _load_credits() -> void:
	# Reset for potential future replays
	_active_count = 0
	SceneLoader.load_scene(END_CREDITS_PATH)
