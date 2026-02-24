extends Control
## Opening narrative scene that displays story text line by line,
## then transitions to the game level.

const GAME_SCENE_PATH := "res://scenes/game_scene/game_ui.tscn"

## Time in seconds between each line appearing.
@export var line_delay: float = 2.5
## Duration of each line's fade-in tween.
@export var fade_in_duration: float = 0.8
## Duration of the final fade-out to black.
@export var fade_out_duration: float = 1.2

@onready var text_container: VBoxContainer = %TextContainer
@onready var fade_overlay: ColorRect = %FadeOverlay

var _narrative_lines: Array[String] = [
	"have you ever noticed something strange in a dream...",
	"and felt a shiver as you teeter between worlds?",
	"focus your attention on the [i][color=#a0a0a0]out of place[/color][/i] to undo the local weave and slip past obstacles ([i][color=#c8a2e6]q[/color][/i] to enter [i][color=#c8a2e6]focus mode[/color][/i])",
	"trigger platforms by locating their buttons ([i][color=#c8a2e6]e[/color][/i] to [i][color=#c8a2e6]interact[/color][/i])",
	"to pass on from this place, find the knowledge hidden in the sacred books in both [i][color=#a0a0a0]the White Lodge[/color][/i] and the [i][color=#a0a0a0]Great Cathedral[/color][/i]",
	"[i](if caught in bad geometry, press [color=#c8a2e6]up arrow[/color] for emergency collision escape)[/i]"
]

var _current_line_index: int = 0
var _elapsed: float = 0.0
var _all_shown: bool = false
var _waiting_for_input: bool = false
var _transitioning: bool = false
var _continue_label: RichTextLabel

func _ready() -> void:
	# Build a RichTextLabel for each narrative line, starting invisible.
	for line_text in _narrative_lines:
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.text = line_text
		label.modulate = Color(1, 1, 1, 0)
		label.add_theme_font_size_override("normal_font_size", 24)
		label.add_theme_font_size_override("italics_font_size", 24)
		label.add_theme_color_override("default_color", Color(0.88, 0.88, 0.88, 1.0))
		text_container.add_child(label)

	# Build the "press e to continue" prompt (hidden until all lines are shown).
	_continue_label = RichTextLabel.new()
	_continue_label.bbcode_enabled = true
	_continue_label.fit_content = true
	_continue_label.scroll_active = false
	_continue_label.text = "\npress [i][color=#c8a2e6]e[/color][/i] to continue"
	_continue_label.modulate = Color(1, 1, 1, 0)
	_continue_label.add_theme_font_size_override("normal_font_size", 20)
	_continue_label.add_theme_font_size_override("italics_font_size", 20)
	_continue_label.add_theme_color_override("default_color", Color(0.6, 0.6, 0.6, 1.0))
	text_container.add_child(_continue_label)

	# Ensure the fade overlay starts fully transparent.
	fade_overlay.modulate = Color(1, 1, 1, 0)

	# Immediately show the first line.
	_show_next_line()

func _process(delta: float) -> void:
	if _transitioning or _waiting_for_input:
		return

	_elapsed += delta

	if not _all_shown:
		if _elapsed >= line_delay:
			_elapsed = 0.0
			_show_next_line()

func _input(event: InputEvent) -> void:
	if _waiting_for_input and not _transitioning:
		if event.is_action_released("interact"):
			_start_transition()

func _show_next_line() -> void:
	if _current_line_index >= _narrative_lines.size():
		_all_shown = true
		_elapsed = 0.0
		_show_continue_prompt()
		return

	# _narrative_lines indices map 1:1 to the first N children of text_container.
	var label := text_container.get_child(_current_line_index) as RichTextLabel
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)
	_current_line_index += 1

	if _current_line_index >= _narrative_lines.size():
		_all_shown = true
		_elapsed = 0.0
		# Show the prompt after the last line finishes fading in.
		tween.tween_callback(_show_continue_prompt)

func _show_continue_prompt() -> void:
	_waiting_for_input = true
	var tween := create_tween()
	tween.tween_property(_continue_label, "modulate:a", 1.0, fade_in_duration)

func _start_transition() -> void:
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_out_duration)
	tween.tween_callback(_load_game_scene)

func _load_game_scene() -> void:
	SceneLoader.load_scene(GAME_SCENE_PATH)
