extends Area3D

signal switched_on()
signal switched_off()

@export var active_color: Color = Color.GREEN
@export var inactive_color: Color = Color.RED
@export var interact_sfx_path: String = "res://assets/audio/sfx/portal-opened.mp3"
@export var switch_volume : int = -15
@onready var mesh: MeshInstance3D = $Mesh


var is_active: bool = false
var _player_nearby: bool = false

# UI nodes (created in code)
var _canvas_layer: CanvasLayer
var _prompt_label: RichTextLabel
var _audio_player: AudioStreamPlayer
var _fade_tween: Tween

const PROMPT_TEXT := "press [i][color=#c8a2e6]e[/color][/i] to interact"
const FLASH_COLOR := Color("#c8a2e6")
const NORMAL_COLOR := Color(0.78, 0.78, 0.78, 1.0)

func _ready() -> void:
	_setup_material()
	_update_color(inactive_color)
	_create_prompt_ui()
	_create_audio_player()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ── Material helpers ──────────────────────────────────────────────

func _setup_material() -> void:
	if mesh.material_override == null:
		var material = StandardMaterial3D.new()
		mesh.material_override = material

func _update_color(color: Color) -> void:
	if mesh.material_override:
		mesh.material_override.albedo_color = color

# ── Prompt UI ─────────────────────────────────────────────────────

func _create_prompt_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_prompt_label = RichTextLabel.new()
	_prompt_label.bbcode_enabled = true
	_prompt_label.fit_content = true
	_prompt_label.scroll_active = false
	_prompt_label.text = PROMPT_TEXT
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Anchor to bottom-center
	_prompt_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.anchor_top = 1.0
	_prompt_label.offset_top = -80.0
	_prompt_label.offset_bottom = -30.0
	_prompt_label.offset_left = 0.0
	_prompt_label.offset_right = 0.0
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_prompt_label.add_theme_font_size_override("normal_font_size", 22)
	_prompt_label.add_theme_font_size_override("italics_font_size", 22)
	_prompt_label.add_theme_color_override("default_color", NORMAL_COLOR)

	# Start fully transparent
	_prompt_label.modulate = Color(1, 1, 1, 0)
	_prompt_label.pivot_offset = _prompt_label.size / 2.0
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_canvas_layer.add_child(_prompt_label)

# ── Audio ─────────────────────────────────────────────────────────

func _create_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.volume_db = switch_volume
	_audio_player.bus  = "Master"
	var stream = load(interact_sfx_path)
	if stream:
		_audio_player.stream = stream
	add_child(_audio_player)

# ── Proximity signals ────────────────────────────────────────────

func _on_body_entered(_body: Node3D) -> void:
	_player_nearby = true
	_fade_prompt(1.0)

func _on_body_exited(_body: Node3D) -> void:
	if get_overlapping_bodies().size() == 0:
		_player_nearby = false
		_fade_prompt(0.0)

func _fade_prompt(target_alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_prompt_label, "modulate:a", target_alpha, 0.25)

# ── Input ─────────────────────────────────────────────────────────

func _unhandled_input(event):
	if event.is_action_pressed("interact") and _player_nearby:
		var bodies = get_overlapping_bodies()
		if bodies.size() > 0:
			is_active = !is_active
			print("Switch activated by input. Active: ", is_active)
			_update_color(active_color if is_active else inactive_color)
			_flash_prompt()
			_play_sfx()
			if is_active:
				switched_on.emit()
			else:
				switched_off.emit()

# ── Flash effect ──────────────────────────────────────────────────

func _flash_prompt() -> void:
	var tw := create_tween()
	# Brief scale-up + color punch
	tw.set_parallel(true)
	tw.tween_property(_prompt_label, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(_prompt_label, "modulate", Color(FLASH_COLOR, 1.0), 0.08)
	tw.set_parallel(false)
	# Return to normal
	tw.set_parallel(true)
	tw.tween_property(_prompt_label, "scale", Vector2.ONE, 0.2)
	tw.tween_property(_prompt_label, "modulate", Color(1, 1, 1, 1), 0.2)

# ── SFX ───────────────────────────────────────────────────────────

func _play_sfx() -> void:
	if _audio_player and _audio_player.stream:
		_audio_player.play()
