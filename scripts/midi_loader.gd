class_name MidiLoader
## Lee un archivo MIDI (formato 0 o 1) y devuelve las notas en segundos,
## respetando el mapa de tempo. Convención General MIDI por clase de nota (cualquier octava):
##   C (kick, 36)  = "B" enemigo OSCURO → pandero oscuro, suena kick
##   D (snare, 38) = "A" enemigo CLARO  → pandero claro, suena snare
##   E (40)        = "BOSS" piedra contra Goliat → escudo de acero
##   F (41)        = HONDA de doble toque contra el campeón: el inicio de la nota es el 1.er toque
##                   ("H1", gira la honda) y el final de la nota el 2.º toque ("H2", lanza la piedra)
## Así se puede exportar tal cual la pista de batería del DAW.

static func load_notes(path: String) -> Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("No se pudo leer el MIDI: " + path)
		return []
	if bytes.slice(0, 4).get_string_from_ascii() != "MThd":
		push_error("Archivo MIDI inválido")
		return []
	var hlen := _u32(bytes, 4)
	var ntracks := _u16(bytes, 10)
	var division := _u16(bytes, 12)
	if division & 0x8000:
		push_error("MIDI con división SMPTE no soportado")
		return []
	var p := 8 + hlen

	var tempos: Array = []    # [tick, us_por_negra]
	var raw_notes: Array = [] # [tick, nota]
	var honda_pairs: Array = [] # [tick_inicio, tick_fin]
	var honda_open := {}        # nota → tick de inicio
	for _t in ntracks:
		if p + 8 > bytes.size():
			break
		var tag := bytes.slice(p, p + 4).get_string_from_ascii()
		var tlen := _u32(bytes, p + 4)
		p += 8
		var end := p + tlen
		if tag != "MTrk":
			p = end
			continue
		var tick := 0
		var status := 0
		while p < end:
			var r := _vlq(bytes, p)
			tick += r[0]
			p = r[1]
			var b: int = bytes[p]
			if b == 0xFF:
				var mtype: int = bytes[p + 1]
				var lr := _vlq(bytes, p + 2)
				var mlen: int = lr[0]
				var dp: int = lr[1]
				if mtype == 0x51 and mlen == 3:
					tempos.append([tick, (bytes[dp] << 16) | (bytes[dp + 1] << 8) | bytes[dp + 2]])
				p = dp + mlen
			elif b == 0xF0 or b == 0xF7:
				var sr := _vlq(bytes, p + 1)
				p = sr[1] + sr[0]
			else:
				if b & 0x80:
					status = b
					p += 1
				var kind := status & 0xF0
				var nd := 1 if (kind == 0xC0 or kind == 0xD0) else 2
				if kind == 0x90 and bytes[p + 1] > 0:
					if bytes[p] % 12 == 5:
						honda_open[bytes[p]] = tick
					else:
						raw_notes.append([tick, bytes[p]])
				elif (kind == 0x80 or (kind == 0x90 and bytes[p + 1] == 0)) and honda_open.has(bytes[p]):
					honda_pairs.append([honda_open[bytes[p]], tick])
					honda_open.erase(bytes[p])
				p += nd
		p = end

	if tempos.is_empty() or tempos[0][0] != 0:
		tempos.push_front([0, 500000])
	tempos.sort_custom(func(a, b): return a[0] < b[0])

	var notes: Array = []
	for n in raw_notes:
		var kind := ""
		match int(n[1]) % 12:
			0: kind = "B"
			2: kind = "A"
			4: kind = "BOSS"
		if kind != "":
			notes.append({"t": _tick_to_sec(n[0], tempos, division), "type": kind})
	for k in honda_open:   # nota F sin note-off: segundo toque una corchea después
		honda_pairs.append([honda_open[k], honda_open[k] + division / 2])
	var pid := 0
	for hp in honda_pairs:
		var t1 := _tick_to_sec(hp[0], tempos, division)
		var t2 := _tick_to_sec(maxi(hp[1], hp[0] + division / 8), tempos, division)
		notes.append({"t": t1, "type": "H1", "pair": pid, "t2": t2})
		notes.append({"t": t2, "type": "H2", "pair": pid, "t1": t1})
		pid += 1
	notes.sort_custom(func(a, b): return a.t < b.t)
	return notes


static func _tick_to_sec(tick: int, tempos: Array, division: int) -> float:
	var sec := 0.0
	for i in tempos.size():
		var start: int = tempos[i][0]
		var stop: int = tempos[i + 1][0] if i + 1 < tempos.size() else 1 << 60
		if tick <= start:
			break
		var seg: int = mini(tick, stop) - start
		sec += float(seg) / division * tempos[i][1] / 1000000.0
	return sec


static func _u32(b: PackedByteArray, i: int) -> int:
	return (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]


static func _u16(b: PackedByteArray, i: int) -> int:
	return (b[i] << 8) | b[i + 1]


static func _vlq(b: PackedByteArray, i: int) -> Array:
	var v := 0
	while true:
		var c: int = b[i]
		i += 1
		v = (v << 7) | (c & 0x7F)
		if not (c & 0x80):
			break
	return [v, i]
