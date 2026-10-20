# Mimic Manor

Juego de terror asimétrico y escondite para Roblox: una Anomalía que se transforma en muebles contra Investigadores que intentan escapar de una mansión victoriana. Clasificación objetivo: 13+.

## Estado: Fases 1 a 4 en código (placeholders grises, sin modelos de Blender todavía)

### Fase 1: prototipo jugable

- **Ronda**: lobby → cuenta atrás → 15 s de preparación (la Anomalía se esconde, los Investigadores a oscuras) → 10 min de partida → resultados → lobby.
- **Victoria**: los Investigadores ganan si escapa al menos 1. La Anomalía gana si nadie escapa (todos eliminados o tiempo agotado).
- **Mansión semi-procedural**: rejilla de módulos con conectores N/S/E/O (pared, puerta o abierta). Crece de forma orgánica, fusiona salas grandes y une todo con un árbol aleatorio más bucles. Se valida la conectividad y, si algo falla, se usa un layout seguro.
- **Anomalía**: 10 formas (armario, silla, mesa, reloj de pie, cómoda, baúl, lámpara, busto, jarrón, estantería) idénticas a los muebles de la mansión. Atacar transformada ≥2 s es una emboscada con muerte instantánea y kill cam.
- **Investigadores**: linterna con batería (y pilas por la mansión), cámara con 6 fotos (el flash revela y aturde a la Anomalía), detector EMF de 5 niveles y sprint con aguante.
- **Cordura**: baja con la oscuridad, la soledad y la Anomalía cerca, y sube en grupo y con luz. Por debajo de 60/35/15 aparecen pasos falsos, figuras, muebles que se acercan y un EMF que miente, **solo en el cliente de ese jugador**.
- **Objetivo**: recoger fusibles (3 + 1 por cada 3 Investigadores), colocarlos en la caja, restaurar la energía y escapar por la puerta principal.

### Fase 2: ruido y voz
- **Voz posicional** opcional con la Audio API de Roblox (13+, verificación de edad de Roblox). El volumen de tu micro se convierte en ruido.
- **Sin voz** se juega igual: el ruido sale de los pasos (quieto, sigilo, andar o correr) y de los gritos (¡Ayuda!, ¡Por aquí! y ¡Corred!), que tus compañeros ven como bocadillos.
- La Anomalía recibe una **posición aproximada** del ruido (marca 3D y flecha en pantalla), nunca la exacta.

### Fase 3: fantasma vengativo
- Al morir vuelves como fantasma: invisible e inaudible para los vivos, y tu voz solo la oyen otros fantasmas.
- Puedes apagar una lámpara cercana (Z) o dejar un susurro de niebla fría como pista (X). Las dos acciones tienen cooldown largo y las ve todo el mundo.

### Fase 4: economía, tienda, gacha y Robux
- **DataService**: guardado con bloqueo de sesión, reintentos, autoguardado y guardado al cerrar el servidor. En Studio sin acceso a APIs funciona en memoria.
- **Monedas** que solo se ganan jugando: participación, fusibles, fotos, escape, eliminaciones y victoria.
- **Tienda** (B en el lobby) con mejoras laterales: farol, linterna táctica, EMF mejorado, carrete extra y campana trampa consumible.
- **Gacha "Cofre maldito"**: reloj de cuco, espejo maldito y estatua sangrienta, cada uno con su kill cam. Las probabilidades se ven siempre antes de abrirlo, y las repetidas devuelven monedas. Como las monedas no se venden por Robux, no cuenta como "paid random item"; si algún día se venden, el cofre se bloquea donde `PolicyService` lo exija. Las formas cosméticas aparecen como muebles en todas las mansiones, así que no delatan a nadie.
- **Luz UV** (tecla 3) que revela las huellas de la Anomalía a costa de batería. El gamepass **Luz UV Pro** amplía el alcance.
- **Revive Token** (DevProduct): con R, siendo fantasma, vuelves al vestíbulo; máximo uno por partida. Para activarlos, pon los ids en `ShopCatalog.Monetization`.

Todo es autoritativo en el servidor: el cliente solo pide acciones y el servidor valida rol, estado, cooldowns, distancia y línea de visión. El cliente nunca recibe la posición de la Anomalía, solo el nivel del EMF.

## Controles

| Acción | Investigador | Anomalía |
|---|---|---|
| Linterna | F | |
| Cámara / EMF / Luz UV | 1 / 2 / 3 | |
| Sigilo | C | |
| Gritos | G / H / J | |
| Campana trampa | T | |
| Hacer foto | Clic (con la cámara) | |
| Correr | Shift | |
| Menú de formas | | Q (y 1-9 dentro del menú) |
| Volver a la forma normal | | E |
| Atacar | | Clic |
| Fantasma: lámpara / susurro / revivir | Z / X / R | |
| Tienda (lobby) | B | B |
| Cómo jugar | F1 o botón ? | F1 o botón ? |

En móvil aparecen botones táctiles, y también funciona con mando.

## Probar

1. Instala [Rojo](https://rojo.space) 7.4+ y su plugin de Studio.
2. `rojo serve` en la raíz y conéctate desde Studio (o `rojo build -o MimicManor.rbxlx` y abre el archivo).
3. **Solo en Studio**: con 1 jugador la ronda arranca igualmente con el rol de `Config.Debug.SoloRole` (Investigador por defecto; cámbialo a `"Anomaly"` para probar la transformación).
4. Con 2 o más jugadores (Test → Clients and Servers en Studio) hay ronda real con 1 Anomalía.

Todos los números de equilibrio están en `src/shared/Config.luau`.

## Modelos de Blender

`tools/blender/mimic_props.py` genera los 13 muebles (los 10 normales y las 3 formas del gacha) con las mismas medidas que los bloques y los exporta a `assets/models/` (un `.glb` por mueble, `MimicProps.glb` con todos y `MimicProps.blend` para editarlos).

```bash
blender -b -P tools/blender/mimic_props.py -- assets/models   # o: pip install bpy && python tools/blender/mimic_props.py assets/models
```

Para usarlos en el juego:
1. En Studio, **Archivo → Importar 3D** y elige `assets/models/MimicProps.glb`.
2. Crea una carpeta llamada `PropModels` en `ReplicatedStorage` y arrastra dentro lo importado.
3. Publica. El juego busca cada mueble por su nombre (`Wardrobe`, `Chair`…), lo escala a la altura correcta y le pone color y material según el acabado (`Wardrobe_Wood`, `Wardrobe_Brass`…). Si falta alguno, ese mueble se sigue haciendo con bloques.

## Tests

```bash
luau tests/MansionLayout.spec.luau                         # 2000 semillas del generador
luau tests/ShopCatalog.spec.luau                           # probabilidades del gacha
rojo build -o build/MimicManor.rbxlx && lune run tests/run_mansion.luau build/MimicManor.rbxlx   # 200 mansiones construidas de verdad
lune run tests/ImportRotation.spec.luau build/MimicManor.rbxlx   # orientación de los modelos importados
```

## Estructura

- `src/shared`: `Config`, `Enums`, `Remotes` (lista única de remotes), `PropCatalog` (formas y muebles) y `ShopCatalog` (tienda, gacha y recompensas).
- `src/server/Services`: `RoundService`, `RoleService`, `CharacterService`, `MansionService`, `MorphService`, `CombatService`, `ToolService`, `SanityService`, `ObjectiveService`, `NoiseService`, `GhostService`, `DataService`, `EconomyService`, `ShopService`, `MonetizationService`, `FootprintService`, `TrapService` y `AtmosphereService`.
- `src/server/Mansion`: `MansionLayout` (lógica pura y testeable) y `MansionBuilder` (piezas de Roblox).
- `src/client/Controllers`: `UIController` (HUD), `InvestigatorController`, `AnomalyController`, `SanityController` (alucinaciones), `CameraController` (kill cam y espectador), `AmbienceController` (parpadeo de luces), `VoiceController`, `GhostController`, `ProfileController` y `ShopController`.
- `docs/`: documentación del juego; ábrela como vault de Obsidian.

## Siguiente (Fase 5)

- Probar en Studio con varios clientes y ajustar los números de `Config.luau`.
- Sustituir los placeholders por los modelos de Blender (mismos nombres de pieza en `PropCatalog`) y añadir audio propio.
- Crear el gamepass y el DevProduct en el Creator Dashboard y poner sus ids.
- Rellenar el cuestionario de madurez de la experiencia para la clasificación 13+.
