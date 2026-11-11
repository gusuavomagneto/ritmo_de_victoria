# Ritmo de Victoria — prototipo (Mundo 1: David vs. Goliat)

## Abrir y jugar
1. Instalá Godot 4.3 o superior (versión estándar, no .NET): https://godotengine.org/download
2. Abrí Godot → Importar → elegí `project.godot` de esta carpeta.
3. Tocá F5 (Ejecutar).

Se juega con los dos pulgares:
- Escudo de ACERO = mitad izquierda de la pantalla (o F / ←) → enemigos claros (snare) y piedras contra Goliat.
- Escudo de BRONCE = mitad derecha (o J / →) → enemigos oscuros (kick).
- Pausa: botón verde arriba a la derecha (o Esc / P). Si salís de la app, se pausa sola.

Pantallas: menú → niveles (8 casilleros, 3 estrellas por nivel, se desbloquea el siguiente al ganar) → partida → resultados.
Estrellas: 1 = vencer a Goliat · 2 = precisión ≥ 80 % · 3 = precisión ≥ 95 %.

## Usar tu propia canción
Reemplazá los dos archivos de `assets/music/`, o agregá niveles a la lista `LEVELS` al principio de `scripts/main.gd`:
- `david_prueba.ogg` → tu tema (OGG o WAV).
- `david_prueba.mid` → MIDI exportado del DAW con la pista de enemigos.

Notas del MIDI (vale cualquier octava):
Mapeo General MIDI: podés exportar directamente la pista de batería del DAW.
- **C (kick, nota 36)** = enemigo OSCURO → escudo de bronce → suena kick
- **D (snare, nota 38)** = enemigo CLARO → escudo de acero → suena snare
- **E (nota 40)** = piedra contra Goliat → escudo de acero → golpe grande

El jugador toca el kick y el snare: sacalos de la mezcla del tema (dejá el resto de la batería).
Sonidos de golpe: `assets/sfx/kick.wav`, `snare.wav`, `golpe_jefe.wav` (reemplazables por tus samples). (Goliat aparece 3,5 s antes de la primera E)

El MIDI tiene que incluir el tempo. Exportalo desde el compás 1, alineado con el audio.
Para derribar a Goliat hay que acertar el 75 % de las piedras (`BOSS_REQUIRED` en `main.gd`).

## Latencia
Al terminar, la pantalla de resultados muestra si tocaste tarde o temprano en promedio.
"Aplicar ajuste de latencia" lo corrige y queda guardado.

## Exportar a celular
Proyecto → Exportar → agregá Android o iOS. En la pestaña Recursos, en "Filtros para exportar
archivos que no son recursos", agregá `*.mid`; si no, el MIDI no viaja dentro de la app.

## Personajes
`assets/characters/`: los 12 personajes limpios. Los enemigos están espejados (miran a la izquierda) y tienen
versiones `_claro` y `_oscuro` generadas automáticamente; `goliat.png` es el filisteo en tono bronce.
El ejército del nivel se elige con `ENEMY_ARMY` en `scripts/main.gd`. Scripts de regeneración en `tools_dev/`.

### Poses del héroe
`assets/characters/david/`: poses normalizadas (misma escala, pies abajo, cabeza centrada) con `tools_dev/prep_hero.py`.
Nombres que usa el juego: idle, correr_1, correr_2, atacar_preparacion, atacar_lanzamiento, atacar_seguimiento,
patada (si falta, usa "saltar"), recibir_dano, victoria, derrota.
Para otro héroe: `python3 -I tools_dev/prep_hero.py <carpeta_poses> assets/characters/<nombre> <nombre>` y cambiar `HERO_NAME`.

### Poses de enemigos
`assets/characters/filisteo/`: claro/oscuro × correr_1..4 + derrotado, procesados con
`python3 -I tools_dev/prep_enemy.py <carpeta_poses> assets/characters/<ejército> <ejército> --reforzar`
(`--reforzar` tiñe toda la figura para separar mejor claro de oscuro; sin el flag se usa el arte tal cual).

## Sincronía de la batería (dos modos, botón en el menú)
- **Pista sincronizada (recomendado):** cada nivel puede tener un stem de kick/snare (`"drums"` en `LEVELS`).
  Suena siempre en tempo exacto; si fallás, se silencia hasta el próximo acierto (como Rock Band).
  Entregá por tema: mezcla SIN kick/snare + stem SOLO kick/snare + MIDI. Mismo largo y mismo inicio.
- **Sonido al tocar:** suena el sample al tocar; si tocás antes de tiempo espera al tiempo exacto.
El reloj del juego es continuo y se corrige suavemente contra el audio (sin saltos).

## Fondos
`assets/backgrounds/<nombre>_lejos.png` (paisaje, se mueve lento) y `<nombre>_suelo.png` (suelo, se mueve rápido),
generados desde una imagen única: se escala a 720 px de alto y se une con su espejo para que se repita sin costura.
El suelo se corta en la línea donde empieza la arena transitable. Se asigna por nivel con `"bg"` en `LEVELS`.
Para pedir fondos nuevos: formato horizontal 2:1, el suelo transitable en el tercio inferior y sin personajes.

## Progresión (Mundo 1 · David)
6 niveles por mundo. Cada nivel se desbloquea ganando el anterior (1 estrella o más).
El jefe (nivel 6, `"boss": true` en `LEVELS`) se desbloquea con `BOSS_STARS_NEEDED` = 10 estrellas de los niveles 1-5.
Un nivel sin `"audio"` aparece como "Próximamente". Cada nivel tiene una tarjeta (`"card"`: título, cita y texto
parafraseado) que se desbloquea al ganarlo; se ven en "Colección de tarjetas" desde la pantalla de niveles.
