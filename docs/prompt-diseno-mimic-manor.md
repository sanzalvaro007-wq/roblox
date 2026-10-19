# Prompt de diseño: Mimic Manor

Copia el bloque de abajo en una sesión nueva con Claude (o en Roblox Studio Assistant) para arrancar el diseño del juego. Está pensado para producir un GDD (Game Design Document) inicial y un plan de construcción por fases.

---

```text
Actúa como game designer senior y arquitecto técnico de Roblox (Luau). Vamos a diseñar
"Mimic Manor", un juego de terror asimétrico y escondite (Prop Hunt + terror psicológico
estilo Doors). Trabajamos en español. Somos dos desarrolladores (yo y mi socio) y usamos
GitHub (Rojo), Obsidian para la documentación y Blender (vía Blender MCP) para los modelos.

## Concepto
- 1 jugador es la "Anomalía": puede transformarse en muebles/estructuras de una mansión
  victoriana y emboscar a los demás.
- 3 a 7 jugadores son "Investigadores": fotografían anomalías, reparan fusibles, encuentran
  pistas y escapan.
- Mansión semi-procedural: salas modulares que se ensamblan distinto en cada partida.
- Hook: jumpscares virales (un armario que te traga vivo) pensados para streamers.

## Mecánicas clave a diseñar
1. Transformación de la Anomalía: catálogo de formas, reglas de camuflaje (tamaño,
   colisiones, "tells" sutiles), cooldowns y ataque/emboscada con kill cam.
2. Herramientas de Investigador: cámara (fotografiar revela/aturde), detector EMF,
   linterna con batería, luz UV (huellas), fusibles y puertas de escape.
3. Chat de voz posicional: el volumen del micrófono genera "ruido" que la Anomalía
   percibe como dirección aproximada. Define cómo se hace en Roblox (VoiceChatService /
   AudioAPI, umbrales, fallback para jugadores sin voz: emotes de pánico, pasos, correr).
4. Cordura: baja con oscuridad, soledad y sustos; a baja cordura aparecen falsos
   monstruos y pasos falsos SOLO en el cliente de ese jugador. Se recupera en grupo y con luz.
5. Espectador vengativo: al morir eres fantasma; puedes dar pistas menores y
   encender/apagar luces con cooldown, sin romper el equilibrio.
6. Condiciones de victoria/derrota, duración de ronda (8-12 min) y equilibrio 1 vs N.

## Economía y monetización (orgánica, no pay-to-win)
- Monedas de Investigación y Cordura como recompensa al sobrevivir/consumir.
- Tienda: EMF mejorado, linternas, trampas, formas cosméticas de Anomalía.
- Gamepass "Luz UV Pro" (revela huellas algo antes; limitado por batería).
- Gacha de formas cosméticas (Reloj de cuco, Espejo maldito, Estatua sangrienta) con
  kill cams propias. Respeta las políticas de Roblox sobre cajas aleatorias (probabilidades
  visibles, restricciones por región/edad).
- DevProduct "Revive Token": 1 revivir por partida.

## Estilo visual y sonido
- Realismo estilizado, iluminación Future, sombras profundas, luces parpadeantes,
  grano de película retro (post-procesado), niebla/Atmosphere.
- Audio 3D: crujidos de madera, respiración, tic-tac, silencios tensos.
- Respeta las guías de Roblox para terror (clasificación de experiencia por edad).

## Lo que necesito que entregues
1. Resumen de una página (pitch, público objetivo, pilares de diseño).
2. Core loop detallado de cada rol, con un diagrama de flujo de la ronda
   (lobby -> selección de rol -> partida -> resultados -> tienda).
3. Especificación de cada mecánica: reglas, números iniciales para tunear, y cómo se
   comunica al jugador (UI, sonido, feedback).
4. Arquitectura técnica en Roblox:
   - Estructura de carpetas para Rojo (src/server, src/client, src/shared).
   - Servicios del servidor (RoundService, RoleService, MorphService, SanityService,
     MansionGenerator, EconomyService, DataService con ProfileStore o similar).
   - Controladores del cliente (Camera/Photo, Flashlight, Sanity/Hallucinations, UI).
   - Remotes y validación server-authoritative (anti-exploit: nada de confiar en el
     cliente para kills, monedas o detección).
   - Cómo representar las salas modulares y los "props" transformables.
5. Pipeline de assets: qué modelar en Blender primero, convenciones de nombres,
   límites de triángulos, exportación FBX a Roblox, y cómo usar Blender MCP.
6. Roadmap por fases con entregables verificables:
   - Fase 0: repo + Rojo + estructura vacía.
   - Fase 1 (prototipo gris): 1 sala, transformación básica, 1 herramienta, ronda simple.
   - Fase 2: mansión modular, cordura, fusibles/escape.
   - Fase 3: voz posicional, fantasma, arte y audio.
   - Fase 4: economía, tienda, monetización, analítica.
   - Fase 5: playtests, balance, lanzamiento.
7. Reparto de tareas sugerido para dos personas.
8. Riesgos principales (equilibrio 1 vs N, rendimiento, moderación de voz, políticas de
   Roblox) y cómo mitigarlos.
9. Lista de preguntas abiertas que debo responder antes de seguir.

Formato: Markdown con encabezados, listo para pegar en Obsidian (usa [[enlaces]] entre
notas sugeridas, por ejemplo [[Mecánica - Cordura]], [[Sistema - Rondas]]).
Antes de escribir el documento completo, hazme las 5 preguntas más importantes que
cambiarían el diseño y espera mis respuestas.
```

---

## Estructura sugerida del vault de Obsidian

```
Mimic Manor/
  00 - Índice.md
  01 - Pitch y pilares.md
  02 - Core loop.md
  Mecánicas/   (Transformación, Cordura, Voz posicional, Fantasma, Herramientas)
  Sistemas/    (Rondas, Generación de mansión, Economía, Datos)
  Arte/        (Guía visual, Lista de props, Pipeline Blender)
  Audio/
  Roadmap.md
  Decisiones.md
```

Si guardas el vault dentro del repositorio (carpeta `docs/`), tu socio y tú compartiréis la documentación por GitHub junto al código.
