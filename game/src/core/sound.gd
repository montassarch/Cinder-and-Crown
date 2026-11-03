class_name SoundBank
extends Node
## Music, ambience and sound effects (autoload "Sound"). Files live in audio/ (picked from the free library by
## tools/audio/pick_audio.py; credits in audio/CREDITS.md). Effects are named cues: each plays one of its files at random
## with a little pitch variation, from a small pool of voices. Music cross-fades between two players; ambience loops
## quietly under it. Everything plays on with the game paused (menus, the shop) and can be muted.

const DIR := "res://audio"
const VOICES: int = 12
const FADE_SECONDS: float = 1.2
const MUSIC_DB: float = -9.0
const AMBIENCE_DB: float = -18.0
const VICTORY_MUSIC := &"victory"
const FALLEN_MUSIC := &"fallen"
const HISTORY: int = 64

## cue: files (in audio/sfx), loudness in dB, random pitch spread
const CUES := {
	&"swing": {"files": ["swing_1", "swing_2", "swing_3"], "db": -8.0, "pitch": 0.1},
	&"swing_heavy": {"files": ["swing_heavy_1", "swing_heavy_2"], "db": -6.0, "pitch": 0.08},
	&"hit": {"files": ["hit_1", "hit_2", "hit_3"], "db": -6.0, "pitch": 0.08},
	&"punch": {"files": ["punch_1"], "db": -4.0, "pitch": 0.12},
	&"arrow": {"files": ["bow_1"], "db": -8.0, "pitch": 0.1},
	&"clash": {"files": ["clash_1", "clash_2"], "db": -3.0, "pitch": 0.06},
	&"block": {"files": ["block_1"], "db": -6.0, "pitch": 0.08},
	&"roll": {"files": ["roll_1"], "db": -10.0, "pitch": 0.1},
	&"jump": {"files": ["jump_1"], "db": -12.0, "pitch": 0.08},
	&"land": {"files": ["land_1"], "db": -12.0, "pitch": 0.08},
	&"step": {"files": ["step_1", "step_2"], "db": -18.0, "pitch": 0.12},
	&"draw": {"files": ["draw_1"], "db": -10.0, "pitch": 0.05},
	&"hero_hurt": {"files": ["hero_hurt_1", "hero_hurt_2"], "db": -6.0, "pitch": 0.08},
	&"enemy_hurt": {"files": ["enemy_hurt_1", "enemy_hurt_2"], "db": -12.0, "pitch": 0.15},
	&"enemy_die": {"files": ["enemy_die_1"], "db": -8.0, "pitch": 0.15},
	&"roar": {"files": ["roar_1", "roar_2"], "db": -3.0, "pitch": 0.05},
	&"cast": {"files": ["magic_1", "magic_3"], "db": -8.0, "pitch": 0.08},
	&"spell": {"files": ["magic_2", "fire_1"], "db": -10.0, "pitch": 0.12},
	&"drink": {"files": ["drink_1"], "db": -8.0, "pitch": 0.05},
	&"blast": {"files": ["blast_1"], "db": -4.0, "pitch": 0.08},
	&"slam": {"files": ["stones_1", "stones_2"], "db": -4.0, "pitch": 0.08},
	&"summon": {"files": ["magic_3"], "db": -8.0, "pitch": 0.05},
	&"hazard": {"files": ["fire_2", "stones_1"], "db": -8.0, "pitch": 0.12},
	&"gate": {"files": ["gate_1"], "db": -8.0, "pitch": 0.0},
	&"boon": {"files": ["gem_1"], "db": -8.0, "pitch": 0.0},
	&"cells": {"files": ["coins_1"], "db": -10.0, "pitch": 0.1},
}

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_on: int = 0
var _current_music: StringName = &""
var _ambience: AudioStreamPlayer
var _current_ambience: StringName = &""
var _history: Array[StringName] = []
var _muted: bool = false
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = AMBIENCE_DB
	add_child(_ambience)


## Plays one of `cue`'s files; returns the voice playing it (null for an unknown cue).
func play(cue: StringName, extra_db: float = 0.0) -> AudioStreamPlayer:
	var spec: Dictionary = CUES.get(cue, {})
	if spec.is_empty():
		return null
	var files: Array = spec["files"]
	var stream := _load("sfx", files[randi() % files.size()], false)
	if stream == null:
		return null
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = float(spec["db"]) + extra_db
	var spread: float = spec["pitch"]
	voice.pitch_scale = 1.0 + randf_range(-spread, spread)
	voice.play()
	_history.append(cue)
	if _history.size() > HISTORY:
		_history.pop_front()
	return voice


## Fades over to `track` (audio/music/<track>.ogg, looping); the same track keeps playing undisturbed.
func music(track: StringName) -> void:
	if track == _current_music or track == &"":
		return
	var stream := _load("music", track, true)
	if stream == null:
		return
	_current_music = track
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var fresh := _music[_music_on]
	fresh.stream = stream
	fresh.volume_db = -40.0
	fresh.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fresh, "volume_db", MUSIC_DB, FADE_SECONDS)
	if old.playing:
		tween.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
		tween.chain().tween_callback(old.stop)


func ambience(track: StringName) -> void:
	if track == _current_ambience:
		return
	_current_ambience = track
	var stream := _load("ambience", track, true) if track != &"" else null
	_ambience.stop()
	if stream != null:
		_ambience.stream = stream
		_ambience.play()


func current_music() -> StringName:
	return _current_music


func current_ambience() -> StringName:
	return _current_ambience


func music_player() -> AudioStreamPlayer:
	return _music[_music_on]


func set_muted(muted: bool) -> void:
	_muted = muted
	AudioServer.set_bus_mute(0, muted)


func is_muted() -> bool:
	return _muted


## The cues played lately, oldest first (tests and tools read this).
func history() -> Array[StringName]:
	return _history


func clear_history() -> void:
	_history.clear()


func _load(folder: String, name: StringName, loop: bool) -> AudioStream:
	var key := "%s/%s" % [folder, name]
	if _cache.has(key):
		return _cache[key]
	var stream := load("%s/%s/%s.ogg" % [DIR, folder, name]) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_cache[key] = stream
	return stream
