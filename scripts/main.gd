extends Node2D
## Ritmo de Victoria — prototipo del Mundo 1: David vs. Goliat.
## Se juega con dos pulgares: mitad izquierda = escudo de ACERO (enemigos claros, arma, snare),
## mitad derecha = escudo de BRONCE (enemigos oscuros, patada, kick).
## Toda la lógica y el dibujo (placeholder) están en este script.

# ---------- Niveles ----------
# Para usar tu tema: reemplazá los archivos (o agregá niveles a esta lista).
# Mundo 1 · David: 6 niveles. Un nivel sin "audio" aparece como "Próximamente".
# El nivel con "boss": true se desbloquea juntando BOSS_STARS_NEEDED estrellas en los anteriores.
# "card": tarjeta de colección que se desbloquea al ganar el nivel (texto parafraseado, no cita literal).
const LEVELS := [
	{"name": "No Voy a Temer", "audio": "res://assets/music/no_voy_a_temer.ogg", "midi": "res://assets/music/no_voy_a_temer.mid",
	 "hit_sfx": false,   # la batería ya está en el audio: los golpes no suenan
	 "bg": "valle_ela",
	 "claro": ["oso_blanco"], "oscuro": ["oso_marron"],
	 "card": {"title": "El pastor elegido", "ref": "1 Samuel 16:11-13",
		"text": "Dios no eligió al más alto ni al mayor, sino al menor de los hijos de Isaí, el que cuidaba las ovejas. Samuel lo ungió y el Espíritu de Dios vino sobre él."}},
	{"name": "Valle de Elá (tema de prueba)", "audio": "res://assets/music/david_prueba.ogg", "midi": "res://assets/music/david_prueba.mid",
	 "drums": "res://assets/music/david_prueba_bateria.ogg", "bg": "valle_ela",
	 "claro": ["leon_blanco"], "oscuro": ["leon_marron"],
	 "card": {"title": "El desafío del gigante", "ref": "1 Samuel 17:4-16",
		"text": "Durante cuarenta días Goliat de Gat salió a desafiar a Israel. Era un gigante con armadura de bronce, y todo el ejército temblaba ante él."}},
	{"name": "El campeón (prueba de honda)", "audio": "res://assets/music/david_prueba.ogg",
	 "midi": "res://assets/music/david_prueba_honda.mid", "drums": "res://assets/music/david_prueba_honda_bateria.ogg",
	 "bg": "valle_ela",
	 "card": {"title": "Cinco piedras lisas", "ref": "1 Samuel 17:38-40",
		"text": "David dejó la armadura del rey porque no estaba acostumbrado a ella. Tomó su cayado, eligió cinco piedras lisas del arroyo y fue con su honda."}},
	{"name": "Nivel 4",
	 "card": {"title": "El arpa que trae paz", "ref": "1 Samuel 16:23",
		"text": "Cuando el rey Saúl estaba atormentado, David tomaba el arpa y tocaba; entonces Saúl encontraba alivio."}},
	{"name": "Nivel 5",
	 "card": {"title": "La batalla es de Jehová", "ref": "1 Samuel 17:45-47",
		"text": "Goliat venía con espada, lanza y escudo. David le respondió que él venía en el nombre del Señor, porque la batalla no se gana con armas sino con Dios."}},
	{"name": "Jefe: Goliat", "boss": true,
	 "card": {"title": "El gigante cae", "ref": "1 Samuel 17:49-50",
		"text": "Una sola piedra de la honda bastó: Goliat cayó con el rostro en tierra. David venció sin espada en la mano."}},
]
const LEVEL_SLOTS := 6        # casilleros por mundo
const BOSS_STARS_NEEDED := 10 # estrellas (de los niveles 1-5) para desbloquear al jefe

# ---------- Ajustes de juego ----------
const HERO_X := 360.0
const HIT_X := 440.0          # punto de choque con los enemigos
const GROUND_Y := 545.0
const CHAR_SCALE := 1.25
const SPEED := 640.0          # px por segundo de los enemigos
const WIN_PERFECT := 0.05     # ± segundos
const WIN_GOOD := 0.10
const WIN_OK := 0.15
const BOSS_REQUIRED := 0.75   # % de piedras para derribar a Goliat
const GOLIATH_X := 1000.0
const SETTINGS_PATH := "user://ajustes.cfg"

const COL_A := Color(0.96, 0.92, 0.82)    # claro  → escudo de acero (arma)
const COL_B := Color(0.42, 0.27, 0.16)    # oscuro → escudo de bronce (patada)

enum State { MENU, LEVELS, PLAYING, PAUSED, RESULTS }
var state: int = State.MENU

var player: AudioStreamPlayer
var drum_player: AudioStreamPlayer      # stem de batería del jugador (modo "pista")
var drum_mode := "pista"                # "pista" = stem sincronizado · "golpe" = sonido al tocar
var drums_active := false
var hit_sfx := true                     # false = el audio ya trae la batería; los golpes son mudos
var pending_sfx: Array = []             # golpes adelantados que esperan su tiempo exacto
var clock_offset := 0.0
var clock_init := false
var last_audio_pos := -1.0
var pause_usec := 0
var drum_btn: Button
var font: Font

# Sprites (assets/characters) y sonidos de golpe (assets/sfx)
const ENEMY_ARMY := "filisteo"
var tex_hero: Texture2D
var tex_claro: Texture2D
var tex_oscuro: Texture2D
var tex_boss: Texture2D
const HERO_NAME := "david"
const HERO_PX := 0.585         # px de pantalla por px de sprite (idle ≈ 205 px de alto)
var hero_frames := {}
var bg_far: Texture2D
var bg_ground: Texture2D
const ENEMY_PX := 0.42         # px de pantalla por px de sprite (≈150 px antes de CHAR_SCALE)
var enemy_frames := {}
# Ejército del nivel: lista de variantes por lado ("A" = claro, "B" = oscuro).
# Cada variante: {"run": [texturas], "down": textura}. Si hay una sola pose, se anima por código.
var army := {"A": [], "B": []}
const DEFAULT_CLARO := ["filisteo/claro"]
const DEFAULT_OSCURO := ["filisteo/oscuro"]
var last_won := false
var celebrating := false
var celebrate_start := -10.0
const CELEBRATE_SECS := 2.8      # festejo de David antes de mostrar los resultados
const JUMP_PERIOD := 0.7
var sfx := {}          # nombre → [AudioStreamPlayer...]
var sfx_idx := {}
var level_idx := 0
var notes: Array = []
var first_note_t := 0.0
var now := 0.0
var bg_time := 0.0
var song_len := 1.0
var offset_ms := 0
var start_usec := 0
var max_time_seen := -100.0

var score := 0
var combo := 0
var max_combo := 0
var health := 100.0
var counts := {}
var deltas: Array = []
var popups: Array = []
var stones: Array = []
var last_a := -10.0
var last_b := -10.0
var last_hit := -10.0
var last_kind_a := "cayado"     # animación del último toque al escudo de acero
var last_throw_t := -10.0       # último lanzamiento de piedra (honda)
var honda_spin_t := -10.0       # (reservado)
var first_h_t := -1.0           # primer enemigo con escudo del nivel (para el aviso)
var has_honda := false          # el nivel tiene notas de honda
var honda_charge := 0           # barra de honda: se llena con aciertos
var press_t := {"A": -10.0, "B": -10.0}
const HONDA_CHARGE := 6         # aciertos (Perfecto/Bien) para cargar la honda
const HONDA_TOGETHER := 0.09    # máx. diferencia entre los dos pulgares para contar como "a la vez"
const HONDA_LINK := 2.6         # segundos máx. entre la honda y el enemigo con escudo
var last_hurt := -10.0
var failed := false
var stars_by_level := {}

var boss_total := 0
var boss_hits := 0
var boss_first_t := 0.0
var goliath_state := "hidden"   # hidden · alive · fallen · standing
var goliath_enter_t := 0.0
var goliath_fall_t := 0.0
var goliath_flinch_t := -10.0

# Modo de prueba automática (línea de comandos)
var autotest := false
var bot := "perfect"
var shots: Array = []
var screen_arg := ""

# UI
var menu_root: Control
var levels_root: Control
var levels_grid: GridContainer
var levels_info: Label
var cards_root: Control
var cards_list: VBoxContainer
var results_card: Label
var pause_root: Control
var results_root: Control
var results_label: Label
var offset_label: Label
var apply_btn: Button
var avg_delta := 0.0
var rotate_root: Control


func _ready() -> void:
	# Fuente con símbolos (★ ☆ → ⟳): en la web no hay fuentes del sistema para completarlos
	var sym: FontFile = load("res://assets/fonts/simbolos.ttf")
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.fallbacks = [sym]
	font = fv
	var th := Theme.new()
	th.default_font = fv
	get_window().theme = th
	_load_settings()
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_on_song_finished)
	drum_player = AudioStreamPlayer.new()
	add_child(drum_player)
	tex_hero = load("res://assets/characters/david.png")
	tex_claro = load("res://assets/characters/%s_claro.png" % ENEMY_ARMY)
	tex_oscuro = load("res://assets/characters/%s_oscuro.png" % ENEMY_ARMY)
	tex_boss = load("res://assets/characters/goliat.png")
	for fr in ["idle", "correr_1", "correr_2", "correr_3", "correr_4", "atacar_preparacion", "atacar_lanzamiento",
			"atacar_seguimiento", "honda_girando", "cayado_1", "cayado_2", "patada_1", "patada_2", "saltar",
			"recibir_dano", "victoria", "derrota"]:
		var path := "res://assets/characters/%s/%s.png" % [HERO_NAME, fr]
		if ResourceLoader.exists(path):
			hero_frames[fr] = load(path)
	_load_army(LEVELS[0])
	for s in ["kick", "snare", "golpe_jefe"]:
		var pool: Array = []
		for k in 4:
			var p := AudioStreamPlayer.new()
			p.stream = load("res://assets/sfx/%s.wav" % s)
			add_child(p)
			pool.append(p)
		sfx[s] = pool
		sfx_idx[s] = 0
	_load_background(LEVELS[0])
	_build_ui()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--bot="):
			bot = a.substr(6)
		elif a.begins_with("--shots="):
			for s in a.substr(8).split(","):
				shots.append(float(s))
		elif a.begins_with("--screen="):
			screen_arg = a.substr(9)
	if screen_arg == "cards":
		_show_cards()
		_shot_and_quit()
	elif screen_arg == "levels":
		_show_levels()
		_shot_and_quit()
	elif screen_arg == "menu":
		_show_menu()
		_shot_and_quit()
	elif autotest or OS.get_cmdline_user_args().has("--play"):
		var start_idx := 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--level="):
				start_idx = int(a.substr(8))
		_start_level(start_idx)
	else:
		_show_menu()


func _shot_and_quit() -> void:
	await get_tree().create_timer(0.8).timeout
	await _take_shot(900.0 if screen_arg == "levels" else (902.0 if screen_arg == "cards" else 901.0))
	get_tree().quit()


# =====================================================================
# UI (Controles)
# =====================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# --- Menú principal ---
	var m := _center_panel(layer)
	menu_root = m[0]
	var v: VBoxContainer = m[1]
	v.add_child(_label("RITMO DE VICTORIA", 56, Color(1.0, 0.84, 0.35)))
	v.add_child(_label("Prototipo · Mundo 1: David", 24, Color.WHITE))
	var play := _button("JUGAR", 36)
	play.pressed.connect(_show_levels)
	v.add_child(play)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	var minus := _button("−10 ms", 20)
	minus.pressed.connect(func(): _set_offset(offset_ms - 10))
	var plus := _button("+10 ms", 20)
	plus.pressed.connect(func(): _set_offset(offset_ms + 10))
	offset_label = _label("", 20, Color.WHITE)
	h.add_child(minus)
	h.add_child(offset_label)
	h.add_child(plus)
	v.add_child(h)
	v.add_child(_label("Ajuste de latencia: también se aplica desde los resultados.", 15, Color(0.75, 0.75, 0.75)))
	drum_btn = _button("", 20)
	drum_btn.pressed.connect(func():
		drum_mode = "golpe" if drum_mode == "pista" else "pista"
		_refresh_drum_btn()
		_save_settings())
	v.add_child(drum_btn)
	_refresh_drum_btn()

	# --- Selección de niveles ---
	var lv := _center_panel(layer)
	levels_root = lv[0]
	var lvb: VBoxContainer = lv[1]
	lvb.add_child(_label("MUNDO 1 · DAVID", 40, Color(1.0, 0.84, 0.35)))
	levels_grid = GridContainer.new()
	levels_grid.columns = 3
	levels_grid.add_theme_constant_override("h_separation", 18)
	levels_grid.add_theme_constant_override("v_separation", 18)
	lvb.add_child(levels_grid)
	levels_info = _label("", 18, Color(0.9, 0.9, 0.9))
	lvb.add_child(levels_info)
	var lh := HBoxContainer.new()
	lh.alignment = BoxContainer.ALIGNMENT_CENTER
	lh.add_theme_constant_override("separation", 20)
	var lcards := _button("Colección de tarjetas", 22)
	lcards.pressed.connect(_show_cards)
	var lback := _button("Volver", 22)
	lback.pressed.connect(_show_menu)
	lh.add_child(lcards)
	lh.add_child(lback)
	lvb.add_child(lh)

	# --- Colección de tarjetas ---
	var cz := _center_panel(layer)
	cards_root = cz[0]
	var cvb: VBoxContainer = cz[1]
	cvb.add_child(_label("TARJETAS · MUNDO 1 · DAVID", 34, Color(1.0, 0.84, 0.35)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_list = VBoxContainer.new()
	cards_list.add_theme_constant_override("separation", 12)
	cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_list)
	cvb.add_child(scroll)
	var cback := _button("Volver a niveles", 22)
	cback.pressed.connect(_show_levels)
	cvb.add_child(cback)

	# --- Pausa ---
	var pz := _center_panel(layer)
	pause_root = pz[0]
	var pv: VBoxContainer = pz[1]
	pv.add_child(_label("PAUSA", 44, Color.WHITE))
	var cont := _button("Continuar", 30)
	cont.pressed.connect(_resume)
	var quit := _button("Salir al menú de niveles", 24)
	quit.pressed.connect(_show_levels)
	pv.add_child(cont)
	pv.add_child(quit)

	# --- Resultados ---
	var r := _center_panel(layer)
	results_root = r[0]
	var rv: VBoxContainer = r[1]
	results_label = _label("", 22, Color.WHITE)
	rv.add_child(results_label)
	results_card = _label("", 20, Color(1.0, 0.88, 0.45))
	results_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_card.custom_minimum_size = Vector2(760, 0)
	rv.add_child(results_card)
	apply_btn = _button("Aplicar ajuste", 20)
	apply_btn.pressed.connect(func():
		_set_offset(offset_ms + int(round(avg_delta * 1000.0)))
		apply_btn.text = "Ajuste aplicado: %d ms" % offset_ms
		apply_btn.disabled = true)
	rv.add_child(apply_btn)
	var rh := HBoxContainer.new()
	rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_theme_constant_override("separation", 20)
	var retry := _button("Reintentar", 26)
	retry.pressed.connect(func(): _start_level(level_idx))
	var back := _button("Niveles", 26)
	back.pressed.connect(_show_levels)
	rh.add_child(retry)
	rh.add_child(back)
	rv.add_child(rh)

	_set_offset(offset_ms)
	_hide_panels()

	# --- Cartel "girá el teléfono" (por encima de todo) ---
	var rl := CanvasLayer.new()
	rl.layer = 20
	add_child(rl)
	rotate_root = ColorRect.new()
	(rotate_root as ColorRect).color = Color(0.08, 0.12, 0.18, 0.97)
	rotate_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_root.mouse_filter = Control.MOUSE_FILTER_STOP
	rl.add_child(rotate_root)
	var rc := CenterContainer.new()
	rc.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_root.add_child(rc)
	var rlab := _label("⟳\nGirá el teléfono\nRitmo de Victoria se juega en horizontal", 44, Color(1, 0.88, 0.45))
	rlab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rlab.custom_minimum_size = Vector2(600, 0)
	rc.add_child(rlab)
	rotate_root.visible = false


func _center_panel(parent: Node) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.16, 0.24, 0.9)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(32)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(3)
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	pc.add_child(v)
	return [root, v]


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, size + 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.78, 0.25)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(12)
	sb.border_color = Color(0.25, 0.42, 0.1)
	sb.set_border_width_all(3)
	var sh := sb.duplicate()
	sh.bg_color = Color(0.65, 0.88, 0.32)
	var sd := sb.duplicate()
	sd.bg_color = Color(0.45, 0.5, 0.55, 0.7)
	sd.border_color = Color(0.3, 0.33, 0.36)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.85, 0.88, 0.9))
	b.add_theme_color_override("font_outline_color", Color(0.15, 0.25, 0.05))
	b.add_theme_constant_override("outline_size", 6)
	return b


func _refresh_drum_btn() -> void:
	if drum_btn:
		drum_btn.text = "Batería: pista sincronizada" if drum_mode == "pista" else "Batería: sonido al tocar (cuantizado)"


func _hide_panels() -> void:
	menu_root.visible = false
	levels_root.visible = false
	pause_root.visible = false
	results_root.visible = false
	if cards_root:
		cards_root.visible = false


func _show_menu() -> void:
	state = State.MENU
	player.stop()
	drum_player.stop()
	_hide_panels()
	menu_root.visible = true


func _show_levels() -> void:
	state = State.LEVELS
	player.stop()
	drum_player.stop()
	_hide_panels()
	for c in levels_grid.get_children():
		c.queue_free()
	for i in LEVEL_SLOTS:
		var lvl: Dictionary = LEVELS[i] if i < LEVELS.size() else {"name": "Nivel %d" % (i + 1)}
		var is_boss: bool = lvl.get("boss", false)
		var head := "JEFE" if is_boss else "%d" % (i + 1)
		var b: Button
		if not _is_unlocked(i):
			var why := "bloqueado"
			if is_boss:
				why = "%d / %d ★" % [_stars_before_boss(), BOSS_STARS_NEEDED]
			b = _button("%s\n%s" % [head, why], 22)
			b.disabled = true
		elif not lvl.has("audio"):
			b = _button("%s\nPróximamente" % head, 22)
			b.disabled = true
		else:
			b = _button("%s\n%s" % [head, _stars_text(int(stars_by_level.get(i, 0)))], 30)
			var idx := i
			b.pressed.connect(func(): _start_level(idx))
		b.custom_minimum_size = Vector2(200, 120)
		levels_grid.add_child(b)
	levels_info.text = "Estrellas: %d / %d   ·   Jefe: se desbloquea con %d ★ de los niveles 1-5   ·   Tarjetas: %d / %d" % [
		_total_stars(), LEVEL_SLOTS * 3, BOSS_STARS_NEEDED, _cards_unlocked(), LEVELS.size()]
	levels_root.visible = true


func _boss_index() -> int:
	for i in LEVELS.size():
		if LEVELS[i].get("boss", false):
			return i
	return -1


func _stars_before_boss() -> int:
	var total := 0
	var bi := _boss_index()
	for i in LEVELS.size():
		if i != bi:
			total += int(stars_by_level.get(i, 0))
	return total


func _total_stars() -> int:
	var total := 0
	for i in LEVELS.size():
		total += int(stars_by_level.get(i, 0))
	return total


func _cards_unlocked() -> int:
	var n := 0
	for i in LEVELS.size():
		if int(stars_by_level.get(i, 0)) > 0 and LEVELS[i].has("card"):
			n += 1
	return n


func _is_unlocked(i: int) -> bool:
	if i >= LEVELS.size():
		return false
	if LEVELS[i].get("boss", false):
		return _stars_before_boss() >= BOSS_STARS_NEEDED
	return i == 0 or int(stars_by_level.get(i - 1, 0)) > 0


func _show_cards() -> void:
	state = State.LEVELS
	_hide_panels()
	for c in cards_list.get_children():
		c.queue_free()
	for i in LEVELS.size():
		var lvl: Dictionary = LEVELS[i]
		if not lvl.has("card"):
			continue
		var card: Dictionary = lvl.card
		var won := int(stars_by_level.get(i, 0)) > 0
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.88, 0.7, 0.95) if won else Color(0.3, 0.33, 0.38, 0.8)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(14)
		sb.border_color = Color(0.55, 0.38, 0.14) if won else Color(0.2, 0.22, 0.25)
		sb.set_border_width_all(3)
		pc.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(840, 0)
		l.add_theme_font_size_override("font_size", 18)
		if won:
			l.text = "%s  ·  %s\n%s\nTema: %s" % [card.title, card.ref, card.text, lvl.name]
			l.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		else:
			l.text = "Tarjeta %d  ·  bloqueada — ganá «%s» para descubrirla" % [i + 1, lvl.name]
			l.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
		pc.add_child(l)
		cards_list.add_child(pc)
	cards_root.visible = true


func _stars_text(n: int) -> String:
	var s := ""
	for k in 3:
		s += "★" if k < n else "☆"
	return s


func _set_offset(v: int) -> void:
	offset_ms = clampi(v, -300, 300)
	if offset_label:
		offset_label.text = "Latencia: %+d ms" % offset_ms
	_save_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "offset_ms", offset_ms)
	cfg.set_value("audio", "modo_bateria", drum_mode)
	for k in stars_by_level:
		cfg.set_value("estrellas", "nivel_%d" % (int(k) + 1), stars_by_level[k])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		offset_ms = int(cfg.get_value("audio", "offset_ms", 0))
		drum_mode = str(cfg.get_value("audio", "modo_bateria", "pista"))
		if cfg.has_section("estrellas"):
			for key in cfg.get_section_keys("estrellas"):
				stars_by_level[int(key.trim_prefix("nivel_")) - 1] = int(cfg.get_value("estrellas", key))


# =====================================================================
# Partida
# =====================================================================
func _start_level(idx: int) -> void:
	level_idx = idx
	var lvl: Dictionary = LEVELS[idx]
	_load_background(lvl)
	_load_army(lvl)
	player.stream = load(lvl.audio)
	song_len = player.stream.get_length()
	notes = MidiLoader.load_notes(lvl.midi)
	boss_total = 0
	boss_first_t = 0.0
	first_note_t = notes[0].t if notes.size() > 0 else 0.0
	first_h_t = -1.0
	has_honda = false
	honda_charge = 0
	press_t = {"A": -10.0, "B": -10.0}
	# chequeo de diseño: entre hondas tiene que haber golpes suficientes para cargar la barra
	var since := 0
	for cn in notes:
		if cn.type == "H":
			if since < HONDA_CHARGE:
				push_warning("Honda en %.2f s: solo %d golpes desde la anterior (se necesitan %d para cargarla)" % [cn.t, since, HONDA_CHARGE])
			since = 0
		elif cn.type == "A" or cn.type == "B" or cn.type == "BOSS":
			since += 1
	# cada honda (F) apunta al próximo enemigo claro u oscuro: ese enemigo trae escudo
	for hi in notes.size():
		var hn: Dictionary = notes[hi]
		if hn.type != "H":
			continue
		has_honda = true
		if first_h_t < 0.0:
			first_h_t = hn.t
		for ti in range(hi + 1, notes.size()):
			var tn: Dictionary = notes[ti]
			if tn.t - hn.t > HONDA_LINK:
				break
			if tn.type == "A" or tn.type == "B":
				if not tn.get("shield", false):
					tn.shield = true
					tn.shield_broken = false
					hn.target = tn
				break
	for n in notes:
		n.judged = false
		n.result = ""
		n.hit_t = 0.0
		if n.type == "BOSS":
			if boss_total == 0:
				boss_first_t = n.t
			boss_total += 1
	score = 0
	combo = 0
	max_combo = 0
	health = 100.0
	counts = {"Perfecto": 0, "Bien": 0, "Justo": 0, "Fallo": 0}
	deltas.clear()
	popups.clear()
	stones.clear()
	boss_hits = 0
	goliath_state = "hidden"
	failed = false
	last_a = -10.0
	last_b = -10.0
	last_hit = -10.0
	last_throw_t = -10.0
	honda_spin_t = -10.0
	last_kind_a = "cayado"
	last_hurt = -10.0
	max_time_seen = -100.0
	now = -1.0
	_hide_panels()
	state = State.PLAYING
	start_usec = Time.get_ticks_usec()
	player.stream_paused = false
	pending_sfx.clear()
	clock_init = false
	clock_offset = 0.0
	last_audio_pos = -1.0
	drums_active = drum_mode == "pista" and lvl.has("drums")
	hit_sfx = lvl.get("hit_sfx", true)
	drum_player.stream_paused = false
	drum_player.volume_db = 0.0
	if drums_active:
		drum_player.stream = load(lvl.drums)
		drum_player.play()
	player.play()


func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	pause_usec = Time.get_ticks_usec()
	player.stream_paused = true
	drum_player.stream_paused = true
	pause_root.visible = true


func _resume() -> void:
	start_usec += Time.get_ticks_usec() - pause_usec   # el reloj no avanza durante la pausa
	pause_root.visible = false
	player.stream_paused = false
	drum_player.stream_paused = false
	state = State.PLAYING


func _notification(what: int) -> void:
	# Si el usuario sale de la app (llamada, notificación), pausar.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and not autotest:
		_pause()


func _update_time() -> void:
	var t: float
	if autotest:
		t = (Time.get_ticks_usec() - start_usec) / 1000000.0
	else:
		# Reloj continuo (Time) corregido contra la posición real del audio, pero solo cuando
		# esa posición avanza. Si el audio no informa posición (p. ej. Safari en la web),
		# el juego sigue con el reloj continuo en lugar de quedarse congelado.
		var wall := (Time.get_ticks_usec() - start_usec) / 1000000.0
		var pos := player.get_playback_position()
		if player.playing and pos > 0.0 and pos != last_audio_pos:
			var audio_t := pos + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
			var err := audio_t - (wall + clock_offset)
			if not clock_init:
				clock_offset += err
				clock_init = true
			elif absf(err) > 0.08:
				clock_offset += err
			else:
				clock_offset += err * 0.04
		last_audio_pos = pos
		t = wall + clock_offset
	t -= offset_ms / 1000.0
	if t > max_time_seen:
		max_time_seen = t
	now = max_time_seen


func _process(delta: float) -> void:
	var vsz := get_viewport_rect().size
	var portrait := vsz.y > vsz.x
	if rotate_root and rotate_root.visible != portrait:
		rotate_root.visible = portrait
	if portrait and state == State.PLAYING and not autotest:
		_pause()
	if celebrating and (state != State.RESULTS or bg_time - celebrate_start > CELEBRATE_SECS):
		celebrating = false
		if state == State.RESULTS:
			results_root.visible = true
	if state != State.PAUSED:
		bg_time += delta
	if state == State.PLAYING:
		_update_time()
		if autotest:
			_bot_play()
		_judge_misses()
		var k := pending_sfx.size() - 1
		while k >= 0:
			if now >= pending_sfx[k].t:
				_play_sfx(pending_sfx[k].name)
				pending_sfx.remove_at(k)
			k -= 1
		if goliath_state == "hidden" and boss_total > 0 and now >= boss_first_t - 3.5:
			goliath_state = "alive"
			goliath_enter_t = now
		if autotest and now > song_len + 0.3:
			_end_game()
		if autotest and not shots.is_empty() and now >= shots[0]:
			_take_shot(shots.pop_front())
	queue_redraw()


func _pause_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x - 110, 10, 100, 100)


func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch and event.pressed:
		if _pause_rect().has_point(event.position):
			_pause()
			return
		var w := get_viewport_rect().size.x
		_press("A" if event.position.x < w * 0.5 else "B")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F, KEY_LEFT, KEY_Z:
				_press("A")
			KEY_J, KEY_RIGHT, KEY_X:
				_press("B")
			KEY_ESCAPE, KEY_P:
				_pause()


func _press(action: String) -> void:
	_update_time()
	if action == "A":
		last_a = now
		last_kind_a = "cayado"
	else:
		last_b = now
	press_t[action] = now
	# ¿hay una honda pendiente en ventana? Los toques se reservan para ella.
	for hn in notes:
		if hn.judged or hn.type != "H":
			continue
		if hn.t - now > WIN_OK:
			break
		if absf(now - hn.t) <= WIN_OK:
			var other := "B" if action == "A" else "A"
			if absf(now - press_t[other]) <= HONDA_TOGETHER:
				_fire_honda(hn, (now + press_t[other]) * 0.5 - hn.t)
			return
	var best = null
	var best_abs := 1e9
	for n in notes:
		if n.judged:
			continue
		if n.t - now > WIN_OK:
			break
		var match_ok: bool = (action == "B" and n.type == "B") or (action == "A" and n.type != "B")
		if not match_ok:
			continue
		var ad: float = absf(now - n.t)
		if ad <= WIN_OK and ad < best_abs:
			best = n
			best_abs = ad
	if best != null:
		_judge(best, now - best.t)


func _fire_honda(h: Dictionary, d: float) -> void:
	if honda_charge < HONDA_CHARGE:
		h.judged = true
		h.hit_t = now
		h.result = "Fallo"
		counts["Fallo"] += 1
		combo = 0
		popups.append({"text": "¡Honda sin carga!", "col": Color(1, 0.5, 0.3), "pos": Vector2(HIT_X, GROUND_Y - 230), "t": now})
		return
	honda_charge = 0
	_judge(h, d)


func _judge(n: Dictionary, d: float) -> void:
	if n.get("shield", false) and not n.get("shield_broken", false):
		# el escudo absorbe el golpe: cuenta como fallo
		n.judged = true
		n.hit_t = now
		n.result = "Fallo"
		counts["Fallo"] += 1
		combo = 0
		last_hurt = now
		health -= 8.0
		popups.append({"text": "¡Escudo!", "col": Color(1, 0.45, 0.3), "pos": Vector2(HIT_X, GROUND_Y - 230), "t": now})
		if health <= 0.0:
			health = 0.0
			failed = true
			_end_game()
		return
	n.judged = true
	n.hit_t = now
	var ad := absf(d)
	var res := "Justo"
	var pts := 50
	var col := Color(1.0, 0.8, 0.4)
	if ad <= WIN_PERFECT:
		res = "Perfecto"
		pts = 300
		col = Color(1.0, 0.95, 0.3)
	elif ad <= WIN_GOOD:
		res = "Bien"
		pts = 100
		col = Color(0.55, 1.0, 0.6)
	n.result = res
	counts[res] += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	score += pts * _mult()
	health = minf(100.0, health + 1.5)
	deltas.append(d)
	popups.append({"text": res, "col": col, "pos": Vector2(HIT_X, GROUND_Y - 230), "t": now})
	if n.type == "BOSS":
		boss_hits += 1
		stones.append({"t": now})
		goliath_flinch_t = now + 0.35
		last_throw_t = now
		_hit_sound(n, d, "golpe_jefe")
	elif n.type == "H":
		last_throw_t = now
		if n.has("target"):
			stones.append({"t": now, "target": n.target})
			n.target.shield_broken = true
			n.target.shield_break_t = now + 0.3
		_hit_sound(n, d, "golpe_jefe")
	else:
		last_hit = now
		_hit_sound(n, d, "snare" if n.type == "A" else "kick")
	if has_honda and n.type != "H" and res != "Justo":
		honda_charge = mini(HONDA_CHARGE, honda_charge + 1)
	_check_boss_done()


func _hit_sound(n: Dictionary, d: float, name: String) -> void:
	if not hit_sfx:
		return
	if drums_active:
		drum_player.volume_db = 0.0   # acierto: la pista de batería vuelve a sonar
		return
	if d < 0.0:
		pending_sfx.append({"t": n.t, "name": name})   # tocó antes: suena en el tiempo exacto
	else:
		_play_sfx(name)


func _play_sfx(name: String) -> void:
	var pool: Array = sfx[name]
	var i: int = sfx_idx[name]
	pool[i].play()
	sfx_idx[name] = (i + 1) % pool.size()


func _mult() -> int:
	if combo >= 50:
		return 4
	if combo >= 25:
		return 3
	if combo >= 10:
		return 2
	return 1


func _judge_misses() -> void:
	for n in notes:
		if n.judged:
			continue
		if n.t > now:
			break
		if now - n.t > WIN_OK:
			n.judged = true
			n.result = "Fallo"
			n.hit_t = now
			counts["Fallo"] += 1
			combo = 0
			if drums_active:
				drum_player.volume_db = -80.0   # fallo: se silencia la batería hasta el próximo acierto
			last_hurt = now
			health -= 4.0 if (n.type == "BOSS" or n.type == "H") else 8.0
			popups.append({"text": "Fallo", "col": Color(1, 0.35, 0.3), "pos": Vector2(HIT_X, GROUND_Y - 230), "t": now})
			_check_boss_done()
			if health <= 0.0:
				health = 0.0
				failed = true
				_end_game()
				return


func _check_boss_done() -> void:
	if goliath_state != "alive":
		return
	for n in notes:
		if n.type == "BOSS" and not n.judged:
			return
	if boss_hits >= ceili(boss_total * BOSS_REQUIRED):
		goliath_state = "fallen"
		goliath_fall_t = now + 0.35
	else:
		goliath_state = "standing"


func _bot_play() -> void:
	if bot == "none":
		return
	var lag := 0.04 if bot == "late" else 0.0
	for n in notes:
		if n.judged:
			continue
		if n.t + lag > now:
			break
		if n.type == "H":
			_press("A")
			_press("B")
		else:
			_press("B" if n.type == "B" else "A")


func _on_song_finished() -> void:
	if not autotest:
		_end_game()


func _end_game() -> void:
	if state != State.PLAYING:
		return
	state = State.RESULTS
	player.stop()
	drum_player.stop()
	var total := notes.size()
	var acc := 0.0
	if total > 0:
		acc = (counts["Perfecto"] + counts["Bien"] * 0.66 + counts["Justo"] * 0.33) / total
	# Estrellas: 1 = terminar y vencer a Goliat · 2 = precisión ≥ 80 % · 3 = ≥ 95 %
	var stars := 0
	if not failed and (boss_total == 0 or goliath_state == "fallen"):
		stars = 1
		if acc >= 0.80: stars = 2
		if acc >= 0.95: stars = 3
	last_won = stars > 0
	var prev_stars := int(stars_by_level.get(level_idx, 0))
	var lvl_data: Dictionary = LEVELS[level_idx]
	results_card.text = ""
	if stars > 0 and prev_stars == 0 and lvl_data.has("card"):
		results_card.text = "¡Nueva tarjeta desbloqueada!  %s (%s)\n%s" % [lvl_data.card.title, lvl_data.card.ref, lvl_data.card.text]
	var bi := _boss_index()
	var boss_was_locked := bi >= 0 and not _is_unlocked(bi)
	if stars > int(stars_by_level.get(level_idx, 0)):
		stars_by_level[level_idx] = stars
		_save_settings()
	avg_delta = 0.0
	for d in deltas:
		avg_delta += d
	if deltas.size() > 0:
		avg_delta /= deltas.size()
	var title := "¡VICTORIA! Goliat cayó" if boss_total > 0 else "¡Nivel superado!"
	if boss_was_locked and bi >= 0 and _is_unlocked(bi):
		results_card.text += ("\n\n" if results_card.text != "" else "") + "¡Desbloqueaste al JEFE: %s!" % LEVELS[bi].name
	if failed:
		title = "Te quedaste sin corazones… probá de nuevo"
	elif boss_total > 0 and goliath_state != "fallen":
		title = "Goliat sigue en pie"
	var timing := "Timing promedio: %+d ms %s" % [int(round(avg_delta * 1000)), "(tarde)" if avg_delta > 0.008 else ("(temprano)" if avg_delta < -0.008 else "(justo)")]
	var boss_line := ("Piedras a Goliat: %d / %d\n" % [boss_hits, boss_total]) if boss_total > 0 else ""
	results_label.text = "%s\n%s\n\nPuntaje: %d    Precisión: %d%%    Combo máx.: %d\nPerfecto %d · Bien %d · Justo %d · Fallo %d\n%s%s" % [
		title, _stars_text(stars), score, int(acc * 100), max_combo,
		counts["Perfecto"], counts["Bien"], counts["Justo"], counts["Fallo"],
		boss_line, timing]
	results_label.add_theme_font_size_override("font_size", 22)
	apply_btn.visible = deltas.size() >= 10 and absf(avg_delta) >= 0.008
	apply_btn.disabled = false
	apply_btn.text = "Aplicar ajuste de latencia (%+d ms)" % int(round(avg_delta * 1000))
	_hide_panels()
	# Si ganó: David salta y festeja antes de mostrar los resultados
	celebrating = last_won
	celebrate_start = bg_time
	results_root.visible = not celebrating
	if autotest:
		print("RESULT bot=%s score=%d stars=%d acc=%.3f counts=%s boss=%d/%d goliath=%s failed=%s avg_ms=%.1f notes=%d" % [bot, score, stars, acc, str(counts), boss_hits, boss_total, goliath_state, str(failed), avg_delta * 1000, total])
		if last_won and OS.get_cmdline_user_args().has("--shot-results"):
			await get_tree().create_timer(0.75).timeout
			await _take_shot(998.0)
			await get_tree().create_timer(CELEBRATE_SECS - 0.4).timeout
		else:
			await get_tree().create_timer(CELEBRATE_SECS + 0.3 if last_won else 0.3).timeout
		if OS.get_cmdline_user_args().has("--shot-results"):
			await _take_shot(999.0)
		get_tree().quit()


func _take_shot(tag: float) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot_%d.png" % int(tag))
	print("shot ", tag)


# =====================================================================
# Dibujo (placeholder vectorial — se reemplaza por arte final)
# =====================================================================
func _draw() -> void:
	var vs := get_viewport_rect().size
	var in_game := state == State.PLAYING or state == State.PAUSED or state == State.RESULTS
	var scroll := bg_time * SPEED * 0.55
	_draw_background(vs, scroll)
	if in_game:
		_draw_goliath()
		_draw_notes()
		_draw_stones()
	_draw_david()
	if state == State.PLAYING or state == State.PAUSED:
		_draw_thumb_buttons(vs)
		_draw_hud(vs)
		_draw_tutorial(vs)
	_draw_popups()
	if celebrating:
		_draw_celebration(vs)


func _draw_celebration(vs: Vector2) -> void:
	var t := bg_time - celebrate_start
	var cols := [Color(1, 0.84, 0.3), Color(0.95, 0.4, 0.45), Color(0.45, 0.8, 1.0), Color(0.6, 0.9, 0.45), Color(1, 1, 1)]
	for i in 70:   # confeti
		var seed := float(i) * 12.9898
		var x0 := fposmod(sin(seed) * 43758.5, 1.0) * vs.x
		var spd := 220.0 + fposmod(sin(seed * 1.7) * 9871.3, 1.0) * 260.0
		var y := -20.0 + t * spd - fposmod(sin(seed * 2.3) * 5113.7, 1.0) * 300.0
		if y < -20.0 or y > vs.y:
			continue
		var x := x0 + sin(t * 3.0 + seed) * 30.0
		var c: Color = cols[i % cols.size()]
		draw_set_transform(Vector2(x, y), t * 4.0 + seed)
		draw_rect(Rect2(-6, -3, 12, 6), c)
		draw_set_transform(Vector2.ZERO)
	var a := clampf(t / 0.3, 0, 1)
	var sc := 1.0 + 0.08 * sin(t * 6.0)
	_text(Vector2(0, 240), "¡NIVEL SUPERADO!", int(56 * sc), Color(1, 0.88, 0.35, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _load_background(lvl: Dictionary) -> void:
	bg_far = null
	bg_ground = null
	if lvl.has("bg"):
		var base := "res://assets/backgrounds/%s" % lvl.bg
		if ResourceLoader.exists(base + "_lejos.png"):
			bg_far = load(base + "_lejos.png")
		if ResourceLoader.exists(base + "_suelo.png"):
			bg_ground = load(base + "_suelo.png")


func _tile_h(tex: Texture2D, y: float, off: float, vs: Vector2) -> void:
	var w := float(tex.get_width())
	var x := -fposmod(off, w)
	while x < vs.x:
		draw_texture(tex, Vector2(x, y))
		x += w


func _draw_background(vs: Vector2, scroll: float) -> void:
	if bg_far:
		# Parallax: paisaje lento + suelo rápido (tiras sin costura: imagen + espejo)
		_tile_h(bg_far, 0.0, scroll * 0.12, vs)
		if bg_ground:
			_tile_h(bg_ground, 720.0 - bg_ground.get_height(), scroll, vs)
		if vs.y > 720.0:
			draw_rect(Rect2(0, 720, vs.x, vs.y - 720), Color(0.55, 0.36, 0.2))
		return
	# Cielo con rayos de sol
	var bands := 10
	for i in bands:
		var c := Color(0.36, 0.7, 0.93).lerp(Color(0.78, 0.92, 0.98), float(i) / bands)
		draw_rect(Rect2(0, GROUND_Y * i / bands, vs.x, GROUND_Y / bands + 1), c)
	var center := Vector2(vs.x * 0.5, -60)
	for k in 14:
		var a0 := bg_time * 0.05 + k * TAU / 14.0
		var p1 := center + Vector2(cos(a0), sin(a0)) * 2000
		var p2 := center + Vector2(cos(a0 + 0.12), sin(a0 + 0.12)) * 2000
		draw_colored_polygon(PackedVector2Array([center, p1, p2]), Color(1, 1, 1, 0.07))
	# Nubes
	for k in 4:
		var cx := fposmod(k * 420.0 - scroll * 0.05, vs.x + 300) - 150
		var cy := 120.0 + (k % 2) * 70
		for o in [Vector2(0, 0), Vector2(40, -18), Vector2(80, 0), Vector2(40, 10)]:
			draw_circle(Vector2(cx, cy) + o, 34, Color(1, 1, 1, 0.85))
	# Montañas lejanas y colinas
	_hills(vs, 360.0, 50.0, 0.004, scroll * 0.08, Color(0.55, 0.72, 0.78))
	_hills(vs, 450.0, 28.0, 0.009, scroll * 0.25, Color(0.45, 0.66, 0.5))
	# Pasto con flores
	draw_rect(Rect2(0, GROUND_Y - 6, vs.x, 26), Color(0.42, 0.74, 0.28))
	draw_rect(Rect2(0, GROUND_Y - 6, vs.x, 6), Color(0.55, 0.85, 0.35))
	for i in 40:
		var fx := fposmod(i * 61.0 - scroll, vs.x + 60) - 30
		draw_circle(Vector2(fx, GROUND_Y - 6 + (i % 3) * 3), 4, Color(1.0, 0.95, 0.6) if i % 4 == 0 else Color(0.98, 0.7, 0.8))
	# Tierra con piedras
	draw_rect(Rect2(0, GROUND_Y + 20, vs.x, vs.y - GROUND_Y - 20), Color(0.78, 0.6, 0.4))
	for i in 22:
		var x := fposmod(i * 157.0 - scroll, vs.x + 200) - 100
		var y := GROUND_Y + 50 + (i * 37 % 4) * 34
		var r := 7.0 + (i % 3) * 4
		draw_colored_polygon(PackedVector2Array([Vector2(x - r, y), Vector2(x - r * 0.3, y - r * 0.8), Vector2(x + r, y - r * 0.4), Vector2(x + r * 0.6, y + r * 0.5)]), Color(0.55, 0.38, 0.24))


func _hills(vs: Vector2, base: float, amp: float, freq: float, off: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= vs.x + 40:
		pts.append(Vector2(x, base + sin((x + off) * freq) * amp + sin((x + off) * freq * 2.7) * amp * 0.4))
		x += 40
	pts.append(Vector2(vs.x + 40, GROUND_Y + 2))
	pts.append(Vector2(0, GROUND_Y + 2))
	draw_colored_polygon(pts, col)


func _c(col: Color, alpha: float = 1.0, red: float = 0.0) -> Color:
	var c := col.lerp(Color(1, 0.15, 0.15), red)
	c.a = col.a * alpha
	return c


func _music_note(p: Vector2, col: Color) -> void:
	draw_circle(p, 6, col)
	draw_line(p + Vector2(5, 0), p + Vector2(5, -20), col, 2.5)
	draw_line(p + Vector2(5, -20), p + Vector2(13, -14), col, 2.5)


func _outline_circle(p: Vector2, r: float, fill: Color, line: Color = Color(0.15, 0.1, 0.08)) -> void:
	draw_circle(p, r + 3, line)
	draw_circle(p, r, fill)


func _eye(p: Vector2, look: float, angry: bool, alpha: float) -> void:
	draw_circle(p, 10, _c(Color(0.15, 0.1, 0.08), alpha))
	draw_circle(p, 8, _c(Color.WHITE, alpha))
	draw_circle(p + Vector2(look * 3, 0), 4, _c(Color(0.1, 0.07, 0.05), alpha))
	if angry:
		draw_line(p + Vector2(-10, -14 - look * 3), p + Vector2(10, -14 + look * 3), _c(Color(0.15, 0.1, 0.08), alpha), 4)


# ----- David (mira a la derecha, pies en el origen) -----
func _frame_or(name: String, fallback: String) -> String:
	return name if hero_frames.has(name) else fallback


func _hero_frame() -> String:
	var playing := state == State.PLAYING or state == State.PAUSED
	if state == State.RESULTS:
		if celebrating:
			var ph := fmod(bg_time - celebrate_start, JUMP_PERIOD)
			return _frame_or("saltar", "victoria") if ph < JUMP_PERIOD * 0.6 else "victoria"
		return "victoria" if last_won else "derrota"
	if not playing:
		return "idle"
	if now - last_hurt >= 0.0 and now - last_hurt < 0.3:
		return "recibir_dano"
	var th := now - last_throw_t
	if th >= 0.0 and th < 0.25:
		return "atacar_lanzamiento" if th < 0.09 else "atacar_seguimiento"
	var a := now - last_a
	var b := now - last_b
	if a >= 0.0 and a < 0.18 and (b < 0.0 or a <= b):
		return _frame_or("cayado_2", "atacar_lanzamiento")
	if b >= 0.0 and b < 0.2:
		return _frame_or("patada_2", "saltar")
	# anticipación según lo que se acerca
	for n in notes:
		if n.judged:
			continue
		if n.t - now > 0.13:
			break
		match n.type:
			"A":
				return _frame_or("cayado_1", "atacar_preparacion")
			"B":
				return _frame_or("patada_1", "idle")
			"BOSS", "H":
				return _frame_or("honda_girando", "atacar_preparacion")
	return "correr_1" if int(bg_time * 9.0) % 2 == 0 else "correr_2"


func _draw_hero_sprite() -> void:
	var playing := state == State.PLAYING or state == State.PAUSED
	var dash := 0.0
	var age := now - last_hit
	if playing and age >= 0.0 and age < 0.22:
		dash = sin(age / 0.22 * PI)
	var run := absf(sin(bg_time * 9.0 * PI)) if playing else 0.0
	var pos := Vector2(HERO_X - 20 + dash * 70, GROUND_Y - dash * 30 - run * 6)
	if celebrating:
		var ph := fmod(bg_time - celebrate_start, JUMP_PERIOD) / (JUMP_PERIOD * 0.6)
		if ph < 1.0:
			pos.y -= sin(ph * PI) * 130.0
	var fr: String = _hero_frame()
	var tex: Texture2D = hero_frames.get(fr, tex_hero)
	var size := tex.get_size() * HERO_PX
	if not hero_frames.has(fr):
		size = Vector2(205.0 * tex.get_width() / tex.get_height(), 205.0)
	draw_set_transform(pos)
	draw_texture_rect(tex, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false)
	draw_set_transform(Vector2.ZERO)
	# estela del golpe (blanca = escudo de acero, marrón = escudo de bronce)
	for d in [[last_a, Color(1, 1, 1)], [last_b, Color(0.55, 0.33, 0.15)]]:
		var a: float = now - d[0]
		if playing and a >= 0.0 and a < 0.15:
			var col: Color = d[1]
			col.a = 1.0 - a / 0.15
			draw_arc(pos + Vector2(70, -95), 75 + a * 120, -1.3, 1.1, 18, col, 10)


func _draw_david() -> void:
	if tex_hero:
		_draw_hero_sprite()
		return
	var playing := state == State.PLAYING or state == State.PAUSED
	var red := clampf(1.0 - (now - last_hurt) / 0.3, 0, 1) if playing else 0.0
	var dash := 0.0
	var age := now - last_hit
	if playing and age >= 0.0 and age < 0.22:
		dash = sin(age / 0.22 * PI)
	var pos := Vector2(HERO_X + dash * 70, GROUND_Y - dash * 40)
	var run := sin(bg_time * 14.0)
	var bob := absf(run) * 4.0
	draw_set_transform(pos + Vector2(0, -bob), dash * 0.25, Vector2(CHAR_SCALE, CHAR_SCALE))
	var skin := Color(0.95, 0.78, 0.6)
	var line := Color(0.15, 0.1, 0.08)
	# piernas
	for side in [-1, 1]:
		var foot := Vector2(side * 8 + run * 10 * side, 0)
		draw_line(Vector2(side * 7, -30), foot, _c(line, 1, red), 12)
		draw_line(Vector2(side * 7, -30), foot, _c(skin, 1, red), 7)
		_outline_circle(foot + Vector2(4, -2), 6, _c(Color(0.5, 0.32, 0.18), 1, red))
	# túnica
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -24), Vector2(27, -24), Vector2(20, -82), Vector2(-20, -82)]), _c(line, 1, red))
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -27), Vector2(24, -27), Vector2(17, -79), Vector2(-17, -79)]), _c(Color(0.55, 0.78, 0.98), 1, red))
	draw_line(Vector2(-21, -48), Vector2(21, -48), _c(Color(0.55, 0.36, 0.2), 1, red), 5)
	# cabeza grande
	_outline_circle(Vector2(4, -118), 38, _c(skin, 1, red))
	for hp in [Vector2(-26, -132), Vector2(-14, -150), Vector2(4, -156), Vector2(22, -150), Vector2(-32, -112)]:
		_outline_circle(hp, 15, _c(Color(0.42, 0.25, 0.12), 1, red), _c(Color(0.42, 0.25, 0.12), 1, red))
	_eye(Vector2(20, -116), 1.0, false, 1.0)
	draw_arc(Vector2(18, -98), 7, 0.3, PI - 0.3, 8, line, 2.5)
	# Honda
	var shoulder := Vector2(6, -70)
	var sa := now - last_a
	if playing and sa >= 0.0 and sa < 0.25:
		var ang := lerpf(-2.6, 0.2, sa / 0.25)
		var hand := shoulder + Vector2(cos(ang), sin(ang)) * 32
		draw_line(shoulder, hand, _c(skin, 1, red), 8)
		var cord := hand + Vector2(cos(ang * 2.5), sin(ang * 2.5)) * 26
		draw_line(hand, cord, Color(0.45, 0.3, 0.15), 3)
		draw_circle(cord, 6, Color(0.5, 0.5, 0.5))
	else:
		draw_line(shoulder, shoulder + Vector2(14, 26), _c(skin, 1, red), 8)
	# Arpa
	var sb := now - last_b
	if playing and sb >= 0.0 and sb < 0.35:
		var hp := Vector2(46, -62)
		var gold := Color(1.0, 0.8, 0.3, 1.0 - sb / 0.35)
		draw_arc(hp + Vector2(0, -10), 26, -PI * 0.9, PI * 0.1, 16, gold, 6)
		draw_line(hp + Vector2(-24, -20), hp + Vector2(-18, 22), gold, 6)
		for k in 4:
			draw_line(hp + Vector2(-14 + k * 8, -28 + k * 2), hp + Vector2(-14 + k * 8, 16), Color(1, 1, 0.85, gold.a), 1.5)
		_music_note(hp + Vector2(36, -44 - sb * 120), gold)
		_music_note(hp + Vector2(62, -14 - sb * 160), gold)
	draw_set_transform(Vector2.ZERO)


# ----- Soldados (miran a la izquierda, pies en el origen) -----
func _load_army(lvl: Dictionary) -> void:
	# Variantes por lado. "filisteo/claro" = poses <dir>/claro_correr_N.png + claro_derrotado.png;
	# "oso_blanco" = carpeta con pose.png (una sola pose) y opcionalmente correr_N.png / derrotado.png.
	army = {"A": [], "B": []}
	for side in ["A", "B"]:
		var names: Array = lvl.get("claro" if side == "A" else "oscuro", DEFAULT_CLARO if side == "A" else DEFAULT_OSCURO)
		for nm in names:
			var parts: PackedStringArray = str(nm).split("/")
			var dir := "res://assets/characters/" + parts[0] + "/"
			var pre := (parts[1] + "_") if parts.size() > 1 else ""
			var v := {"run": [], "down": null}
			for k in range(1, 5):
				var rp := dir + pre + "correr_%d.png" % k
				if ResourceLoader.exists(rp):
					v.run.append(load(rp))
			if v.run.is_empty() and ResourceLoader.exists(dir + pre + "pose.png"):
				v.run.append(load(dir + pre + "pose.png"))
			if ResourceLoader.exists(dir + pre + "derrotado.png"):
				v.down = load(dir + pre + "derrotado.png")
			elif not v.run.is_empty():
				v.down = v.run[0]
			if not v.run.is_empty():
				army[side].append(v)


func _draw_soldier(kind: String, alpha: float, shield: bool = true, boss: bool = false, defeated: bool = false, phase: float = 0.0) -> void:
	if not boss and not army.get(kind, []).is_empty():
		var vars: Array = army[kind]
		var v: Dictionary = vars[int(absf(phase) * 1000.0) % vars.size()]
		var et: Texture2D = v.down if defeated else v.run[int((bg_time + phase) * 10.0) % v.run.size()]
		var es := et.get_size() * ENEMY_PX
		if v.run.size() == 1 and not defeated:
			# una sola pose: se anima con rebote, inclinación y estiramiento
			var w := sin((bg_time + phase) * 14.0)
			var bob := absf(w) * 8.0
			var sq := 1.0 + absf(w) * 0.04
			var pts := Rect2(-es.x * 0.5 * sq, -es.y / sq - bob, es.x * sq, es.y / sq)
			draw_texture_rect(et, pts, false, Color(1, 1, 1, alpha))
			return
		draw_texture_rect(et, Rect2(-es.x * 0.5, -es.y, es.x, es.y), false, Color(1, 1, 1, alpha))
		return
	var tex: Texture2D = tex_boss if boss else (tex_claro if kind == "A" else tex_oscuro)
	if tex:
		var h := 150.0
		var w := h * tex.get_width() / tex.get_height()
		var bob := absf(sin(bg_time * 14.0)) * 6.0
		draw_texture_rect(tex, Rect2(-w * 0.5, -h - bob, w, h), false, Color(1, 1, 1, alpha))
		return
	var run := sin(bg_time * 16.0)
	var skin := Color(0.88, 0.66, 0.5)
	var line := _c(Color(0.15, 0.1, 0.08), alpha)
	for side in [-1, 1]:
		var foot := Vector2(side * 8 - run * 10 * side, 0)
		draw_line(Vector2(side * 7, -30), foot, line, 12)
		draw_line(Vector2(side * 7, -30), foot, _c(skin, alpha), 7)
		draw_circle(foot + Vector2(-4, -2), 7, _c(Color(0.35, 0.22, 0.12), alpha))
	var tunic := COL_A if kind == "A" else COL_B
	if boss:
		tunic = Color(0.7, 0.55, 0.28)
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -24), Vector2(27, -24), Vector2(20, -82), Vector2(-20, -82)]), line)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -27), Vector2(24, -27), Vector2(17, -79), Vector2(-17, -79)]), _c(tunic, alpha))
	if boss:
		for row in 3:
			draw_line(Vector2(-20 + row, -40 - row * 13), Vector2(20 - row, -40 - row * 13), _c(Color(0.45, 0.33, 0.15), alpha), 2)
	draw_circle(Vector2(-4, -116), 39, line)
	draw_circle(Vector2(-4, -116), 36, _c(skin, alpha))
	_eye(Vector2(-20, -116), -1.0, true, alpha)
	draw_line(Vector2(-26, -96), Vector2(-12, -98), line, 3)
	if boss:
		draw_arc(Vector2(-4, -122), 37, PI, TAU, 16, _c(Color(0.78, 0.6, 0.25), alpha), 14)
		draw_line(Vector2(-4, -160), Vector2(-4, -176), _c(Color(0.78, 0.6, 0.25), alpha), 6)
		for bx in [-30, -20, -10, 0]:
			draw_line(Vector2(bx, -92), Vector2(bx + 2, -78), _c(Color(0.35, 0.2, 0.1), alpha), 6)
		draw_line(Vector2(30, 0), Vector2(30, -190), _c(Color(0.42, 0.28, 0.14), alpha), 6)
		draw_colored_polygon(PackedVector2Array([Vector2(30, -190), Vector2(23, -172), Vector2(37, -172)]), _c(Color(0.75, 0.75, 0.8), alpha))
		_outline_circle(Vector2(-30, -55), 28, _c(Color(0.78, 0.58, 0.22), alpha), line)
	elif kind == "A":
		for k in 7:  # tocado de plumas filisteo
			var a := -PI * 0.5 + (k - 3) * 0.2
			draw_line(Vector2(-4, -150), Vector2(-4, -150) + Vector2(cos(a), sin(a)) * 28, line, 8)
			draw_line(Vector2(-4, -150), Vector2(-4, -150) + Vector2(cos(a), sin(a)) * 26, _c(Color(0.98, 0.9, 0.62), alpha), 5)
		draw_line(Vector2(16, -50), Vector2(-56, -74), _c(Color(0.45, 0.3, 0.15), alpha), 5)
		draw_colored_polygon(PackedVector2Array([Vector2(-56, -74), Vector2(-72, -82), Vector2(-54, -66)]), _c(Color(0.75, 0.75, 0.8), alpha))
	else:
		# escudero oscuro: capucha y máscara oscuras
		draw_arc(Vector2(-4, -120), 30, PI * 0.95, TAU + 0.15, 20, _c(COL_B.darkened(0.15), alpha), 18)
		draw_colored_polygon(PackedVector2Array([Vector2(-40, -104), Vector2(28, -104), Vector2(24, -86), Vector2(-36, -86)]), _c(COL_B.darkened(0.1), alpha))
		if shield:
			_outline_circle(Vector2(-30, -52), 30, _c(Color(0.5, 0.33, 0.18), alpha), line)
			draw_arc(Vector2(-30, -52), 20, 0, TAU, 24, _c(Color(0.32, 0.2, 0.1), alpha), 4)
			draw_circle(Vector2(-30, -52), 6, _c(Color(0.75, 0.55, 0.3), alpha))


func _draw_notes() -> void:
	var vs := get_viewport_rect().size
	var sc := Vector2(CHAR_SCALE, CHAR_SCALE)
	for n in notes:
		if n.type == "H":
			_draw_honda_cue(n)
			continue
		var x: float = HIT_X + 40 + (n.t - now) * SPEED
		if not n.judged:
			if x > vs.x + 140:
				break
			if n.type == "BOSS":
				var p := Vector2(x - 40, GROUND_Y - 45)
				var pulse := 0.5 + 0.5 * sin(bg_time * 10.0)
				draw_circle(p, 30, Color(1, 0.85, 0.3, 0.25 + 0.2 * pulse))
				_outline_circle(p, 17, Color(1, 0.82, 0.28))
				draw_arc(p, 30, 0, TAU, 24, Color(1, 0.95, 0.6), 3)
			else:
				draw_set_transform(Vector2(x, GROUND_Y), 0, sc)
				_draw_soldier(n.type, 1.0, true, false, false, n.t * 0.37)
				_draw_enemy_shield(n)
				draw_set_transform(Vector2.ZERO)
			continue
		var age: float = now - n.hit_t
		if age > 1.0 or n.type == "BOSS":
			continue
		if n.result == "Fallo":
			draw_set_transform(Vector2(HERO_X - age * SPEED, GROUND_Y), 0, sc)
			_draw_soldier(n.type, 1.0 - age, true, false, false, n.t * 0.37)
		elif n.type == "A":
			var hp := Vector2(HIT_X + 50 + age * 750, GROUND_Y - age * 700 + 1600 * age * age)
			draw_set_transform(hp, age * 2.5, sc)
			_draw_soldier("A", 1.0 - age, true, false, true, n.t * 0.37)
		else:
			var fp := Vector2(HIT_X + 50 + age * 950, GROUND_Y - age * 320 + 900 * age * age)
			draw_set_transform(fp, -age * 3.0, sc)
			_draw_soldier("B", 1.0 - age, false, false, true, n.t * 0.37)
		draw_set_transform(Vector2.ZERO)


func _draw_honda_cue(h: Dictionary) -> void:
	# anillo que se cierra sobre el escudo del enemigo: marca el momento de los dos pulgares
	if h.judged or not h.has("target"):
		return
	var dt: float = h.t - now
	if dt < 0.0 or dt > 1.0:
		return
	var tg: Dictionary = h.target
	var c := Vector2(HIT_X + 40 + (tg.t - now) * SPEED - 45 * CHAR_SCALE, GROUND_Y - 75 * CHAR_SCALE)
	var ready := honda_charge >= HONDA_CHARGE
	var col := Color(1, 0.92, 0.5, 0.95) if ready else Color(0.9, 0.4, 0.35, 0.9)
	draw_arc(c, 62 + dt * 140, 0, TAU, 40, col, 5)
	draw_arc(c, 62, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35), 3)


func _draw_enemy_shield(n: Dictionary) -> void:
	# se dibuja en coordenadas locales del soldado (ya transformado)
	if not n.get("shield", false):
		return
	var center := Vector2(-45, -75)
	if not n.get("shield_broken", false):
		_draw_shield(center, 52, 0.0, Color(0.86, 0.62, 0.24), Color(0.58, 0.38, 0.14), Color(1.0, 0.86, 0.48))
		return
	var age: float = now - float(n.get("shield_break_t", now))
	if age < 0.0:
		_draw_shield(center, 52, 0.0, Color(0.86, 0.62, 0.24), Color(0.58, 0.38, 0.14), Color(1.0, 0.86, 0.48))
		return
	if age > 0.6:
		return
	var a := 1.0 - age / 0.6
	for k in 5:   # pedazos del escudo volando
		var ang := -PI * 0.5 + (k - 2) * 0.55
		var pp := center + Vector2(cos(ang), sin(ang)) * (age * 420) + Vector2(0, 900 * age * age)
		draw_colored_polygon(PackedVector2Array([pp + Vector2(-14, -10), pp + Vector2(16, -6), pp + Vector2(6, 14)]), Color(0.86, 0.62, 0.24, a))


func _goliath_pos() -> Vector2:
	var k := clampf((now - goliath_enter_t) / 1.5, 0, 1)
	var x := lerpf(get_viewport_rect().size.x + 250, GOLIATH_X, k)
	return Vector2(x, GROUND_Y)


func _draw_goliath() -> void:
	if goliath_state == "hidden":
		return
	var base := _goliath_pos()
	var fl := now - goliath_flinch_t
	if fl >= 0.0 and fl < 0.2:
		base.x += 16
	if goliath_state == "standing":
		base.y -= absf(sin(bg_time * 8.0)) * 10  # se ríe
	var rot := 0.0
	if goliath_state == "fallen" and now > goliath_fall_t:
		rot = clampf((now - goliath_fall_t) / 0.8, 0, 1) * PI * 0.5
	draw_set_transform(base, rot, Vector2(2.0, 2.0))
	_draw_soldier("A", 1.0, true, true)
	draw_set_transform(Vector2.ZERO)
	if goliath_state == "alive":
		var need := maxi(1, ceili(boss_total * BOSS_REQUIRED))
		var frac := clampf(1.0 - float(boss_hits) / need, 0, 1)
		var bar := Rect2(base.x - 120, maxf(base.y - 410, 140), 240, 18)
		draw_rect(bar.grow(3), Color(0.15, 0.1, 0.08))
		draw_rect(bar, Color(0.3, 0.3, 0.3))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(0.9, 0.25, 0.2))
		_text(Vector2(bar.position.x, bar.position.y - 10), "GOLIAT", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)


func _draw_stones() -> void:
	var i := stones.size() - 1
	while i >= 0:
		var p: float = (now - stones[i].t) / 0.35
		if p > 1.0:
			stones.remove_at(i)
		else:
			var a := Vector2(HERO_X + 30, GROUND_Y - 120)
			var b := _goliath_pos() + Vector2(-10, -235)
			if stones[i].has("target"):
				var tg: Dictionary = stones[i].target
				b = Vector2(HIT_X + 40 + (tg.t - now) * SPEED - 45 * CHAR_SCALE, GROUND_Y - 75 * CHAR_SCALE)
			var pos := a.lerp(b, p) + Vector2(0, -sin(p * PI) * 120)
			_outline_circle(pos, 8, Color(0.62, 0.62, 0.62))
		i -= 1


func _text(pos: Vector2, s: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	draw_string_outline(font, pos, s, align, width, size, maxi(4, size / 5), Color(0.1, 0.07, 0.05, col.a))
	draw_string(font, pos, s, align, width, size, col)


# ----- Botones de pulgar (esquinas inferiores) -----
func _draw_thumb_buttons(vs: Vector2) -> void:
	var r := 92.0
	var pa := Vector2(130, vs.y - 125)
	var pb := Vector2(vs.x - 130, vs.y - 125)
	var ha := clampf(1.0 - (now - last_a) / 0.15, 0, 1)
	var hb := clampf(1.0 - (now - last_b) / 0.15, 0, 1)
	# Dos escudos: ACERO (izquierda, enemigos claros) y BRONCE (derecha, enemigos oscuros).
	_draw_shield(pa, r, ha, Color(0.80, 0.83, 0.87), Color(0.52, 0.56, 0.62), Color(0.93, 0.95, 0.98))
	_draw_shield(pb, r, hb, Color(0.86, 0.62, 0.24), Color(0.58, 0.38, 0.14), Color(1.0, 0.86, 0.48))


func _draw_shield(p: Vector2, r: float, h: float, face: Color, rim: Color, shine: Color) -> void:
	var rr := r * (1.0 + h * 0.08)
	var a := 0.82 + h * 0.18
	var line := Color(0.12, 0.09, 0.07, a)
	var lit := face.lerp(Color.WHITE, h * 0.45)
	draw_circle(p + Vector2(4, 6), rr + 6, Color(0, 0, 0, 0.25 * a))       # sombra
	draw_circle(p, rr + 5, line)                                             # contorno
	draw_circle(p, rr, Color(rim.r, rim.g, rim.b, a))                        # borde
	draw_circle(p, rr * 0.82, line)
	draw_circle(p, rr * 0.80, Color(lit.r, lit.g, lit.b, a))                 # cara
	draw_circle(p + Vector2(rr * 0.06, rr * 0.08), rr * 0.66, Color(rim.r, rim.g, rim.b, 0.35 * a))
	draw_circle(p, rr * 0.62, Color(lit.r, lit.g, lit.b, a))
	draw_arc(p, rr * 0.48, 0, TAU, 40, Color(rim.r, rim.g, rim.b, 0.8 * a), 3)
	for k in 8:                                                              # remaches
		var ang := k * TAU / 8.0 + PI / 8.0
		var rp := p + Vector2(cos(ang), sin(ang)) * rr * 0.90
		draw_circle(rp, 6.5, line)
		draw_circle(rp, 5, Color(shine.r, shine.g, shine.b, a))
	draw_circle(p, rr * 0.22, line)                                          # umbo central
	draw_circle(p, rr * 0.20, Color(shine.r, shine.g, shine.b, a))
	draw_circle(p + Vector2(-rr * 0.06, -rr * 0.06), rr * 0.08, Color(1, 1, 1, 0.7 * a))
	draw_arc(p, rr * 0.70, PI * 1.05, PI * 1.45, 16, Color(1, 1, 1, 0.45 * a), 6)   # brillo
	if h > 0.0:
		draw_arc(p, rr + 14 + (1.0 - h) * 22, 0, TAU, 48, Color(shine.r, shine.g, shine.b, h * 0.8), 5)


func _heart(c: Vector2, s: float, fill: float) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var t := k / 32.0 * TAU
		pts.append(c + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * s)
	draw_colored_polygon(pts, Color(0.15, 0.1, 0.08))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.82)
	draw_colored_polygon(inner, Color(0.3, 0.38, 0.45))
	if fill > 0.0:
		var filled := PackedVector2Array()
		for p in inner:
			filled.append(c + (p - c) * clampf(fill, 0.0, 1.0))
		draw_colored_polygon(filled, Color(0.95, 0.4, 0.5))


func _draw_hud(vs: Vector2) -> void:
	# barra superior
	draw_rect(Rect2(0, 0, vs.x, 92), Color(0.15, 0.3, 0.4, 0.45))
	draw_rect(Rect2(0, 88, vs.x * clampf(now / song_len, 0, 1), 4), Color(1, 0.85, 0.35))
	# 3 corazones (la "fe": 100 pts repartidos en 3)
	for k in 3:
		var fill := clampf((health - k * 33.34) / 33.34, 0, 1)
		_heart(Vector2(56 + k * 74, 46), 1.8, fill)
	if has_honda:   # barra de honda debajo de los corazones
		var frac := float(honda_charge) / HONDA_CHARGE
		var br := Rect2(24, 104, 210, 18)
		draw_rect(br.grow(3), Color(0.12, 0.09, 0.07, 0.85))
		draw_rect(br, Color(0.3, 0.3, 0.32, 0.8))
		var full := honda_charge >= HONDA_CHARGE
		var pulse := 0.75 + 0.25 * sin(bg_time * 12.0) if full else 1.0
		draw_rect(Rect2(br.position, Vector2(br.size.x * frac, br.size.y)), Color(1.0 * pulse, 0.82 * pulse, 0.3 * pulse))
		_text(Vector2(br.end.x + 12, br.position.y + 17), "HONDA LISTA" if full else "HONDA", 20, Color(1, 0.9, 0.5) if full else Color.WHITE)
	# puntaje centrado
	_text(Vector2(0, 66), "%d" % score, 52, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if combo >= 3:
		_text(Vector2(0, 132), "%d combo  x%d" % [combo, _mult()], 30, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# número de nivel
	var lr := Rect2(vs.x - 210, 18, 58, 58)
	draw_rect(lr.grow(3), Color(0.15, 0.1, 0.08))
	draw_rect(lr, Color(0.55, 0.78, 0.25))
	_text(Vector2(lr.position.x, lr.position.y + 44), "%d" % (level_idx + 1), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
	# pausa
	var pr := _pause_rect()
	var pc := pr.get_center()
	_outline_circle(pc, 40, Color(0.55, 0.78, 0.25))
	draw_rect(Rect2(pc + Vector2(-14, -16), Vector2(10, 32)), Color(0.25, 0.42, 0.1))
	draw_rect(Rect2(pc + Vector2(4, -16), Vector2(10, 32)), Color(0.25, 0.42, 0.1))


func _callout(rect: Rect2, s: String, arrow_to: Vector2, alpha: float) -> void:
	var col := Color(0.25, 0.5, 0.7, 0.85 * alpha)
	draw_rect(rect, col)
	var ax := clampf(arrow_to.x, rect.position.x + 30, rect.end.x - 30)
	draw_colored_polygon(PackedVector2Array([Vector2(ax - 22, rect.end.y), Vector2(ax + 22, rect.end.y), arrow_to]), col)
	var lines := s.split("\n")
	for i in lines.size():
		_text(Vector2(rect.position.x, rect.position.y + 40 + i * 34), lines[i], 28, Color(1, 1, 1, alpha), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_tutorial(vs: Vector2) -> void:
	# Indicaciones hasta que aparece el primer enemigo (como la pantalla de carga del original).
	if now < first_note_t - 0.6 and level_idx == 0:
		var alpha := clampf((first_note_t - 0.6 - now) / 0.5, 0, 1)
		_callout(Rect2(20, vs.y - 330, 230, 100), "Escudo de\nACERO", Vector2(130, vs.y - 225), alpha)
		_callout(Rect2(vs.x - 250, vs.y - 330, 230, 100), "Escudo de\nBRONCE", Vector2(vs.x - 130, vs.y - 225), alpha)
		_text(Vector2(0, 190), "¡Tocá al ritmo de la música!", 40, Color(1, 1, 1, alpha), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_text(Vector2(0, 240), "Enemigos CLAROS → escudo de acero   ·   Enemigos OSCUROS → escudo de bronce", 26, Color(1, 1, 1, alpha), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if first_h_t > 0.0 and now > first_h_t - 3.2 and now < first_h_t:
		_text(Vector2(0, 200), "¡Enemigo con ESCUDO!  Tocá los DOS escudos a la vez: la honda lo rompe… ¡y después golpealo!", 28, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if goliath_state == "alive" and now < boss_first_t:
		_text(Vector2(0, 200), "¡Llegó GOLIAT!  Piedras doradas → escudo de ACERO", 36, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_popups() -> void:
	var i := popups.size() - 1
	while i >= 0:
		var pp: Dictionary = popups[i]
		var age: float = now - pp.t
		if age > 0.6 or age < 0:
			popups.remove_at(i)
		else:
			var col: Color = pp.col
			col.a = 1.0 - age / 0.6
			var pos: Vector2 = pp.pos + Vector2(-110, -age * 60)
			_text(pos, pp.text, 32, col, HORIZONTAL_ALIGNMENT_CENTER, 220)
		i -= 1
