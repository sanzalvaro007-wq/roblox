# Mimic Manor

Juego de terror asimétrico y escondite para Roblox: una Anomalía que se transforma en muebles contra Investigadores que intentan escapar de una mansión victoriana. Clasificación objetivo: 13+.

## Estado: Fase 1 (prototipo gris jugable)

Ronda completa de principio a fin con placeholders grises (sin modelos de Blender todavía):

- **Ronda**: lobby → cuenta atrás → 15 s de preparación (la Anomalía se esconde, los Investigadores a oscuras) → 10 min de partida → resultados → lobby.
- **Victoria**: los Investigadores ganan si escapa al menos 1. La Anomalía gana si nadie escapa (todos eliminados o tiempo agotado).
- **Mansión semi-procedural**: rejilla de módulos con conectores N/S/E/O (pared, puerta o abierta). Crece de forma orgánica, fusiona salas grandes y une todo con un árbol aleatorio más bucles. Se valida la conectividad y, si algo falla, se usa un layout seguro.
- **Anomalía**: 10 formas (armario, silla, mesa, reloj de pie, cómoda, baúl, lámpara, busto, jarrón, estantería) idénticas a los muebles de la mansión. Atacar transformada ≥2 s es una emboscada con muerte instantánea y kill cam.
- **Investigadores**: linterna con batería (y pilas por la mansión), cámara con 6 fotos (el flash revela y aturde a la Anomalía), detector EMF de 5 niveles y sprint con aguante.
- **Cordura**: baja con la oscuridad, la soledad y la Anomalía cerca, y sube en grupo y con luz. Por debajo de 60/35/15 aparecen pasos falsos, figuras, muebles que se acercan y un EMF que miente, **solo en el cliente de ese jugador**.
- **Objetivo**: recoger fusibles (3 + 1 por cada 3 Investigadores), colocarlos en la caja, restaurar la energía y escapar por la puerta principal.

Todo es autoritativo en el servidor: el cliente solo pide acciones y el servidor valida rol, estado, cooldowns, distancia y línea de visión. El cliente nunca recibe la posición de la Anomalía, solo el nivel del EMF.

## Controles

| Acción | Investigador | Anomalía |
|---|---|---|
| Linterna | F | |
| Cámara / EMF | 1 / 2 | |
| Hacer foto | Clic (con la cámara) | |
| Correr | Shift | |
| Menú de formas | | Q (y 1-9 dentro del menú) |
| Volver a la forma normal | | E |
| Atacar | | Clic |
| Cambiar espectador | ← / → | |

En móvil aparecen botones táctiles, y también funciona con mando.

## Probar

1. Instala [Rojo](https://rojo.space) 7.4+ y su plugin de Studio.
2. `rojo serve` en la raíz y conéctate desde Studio (o `rojo build -o MimicManor.rbxlx` y abre el archivo).
3. **Solo en Studio**: con 1 jugador la ronda arranca igualmente con el rol de `Config.Debug.SoloRole` (Investigador por defecto; cámbialo a `"Anomaly"` para probar la transformación).
4. Con 2 o más jugadores (Test → Clients and Servers en Studio) hay ronda real con 1 Anomalía.

Todos los números de equilibrio están en `src/shared/Config.luau`.

## Tests

```bash
luau tests/MansionLayout.spec.luau                         # 2000 semillas del generador
rojo build -o build/MimicManor.rbxlx && lune run tests/run_mansion.luau build/MimicManor.rbxlx   # 200 mansiones construidas de verdad
```

## Estructura

- `src/shared`: `Config`, `Enums`, `Remotes` (lista única de remotes) y `PropCatalog` (formas y muebles).
- `src/server/Services`: `RoundService`, `RoleService`, `CharacterService`, `MansionService`, `MorphService`, `CombatService`, `ToolService`, `SanityService`, `ObjectiveService`, `AtmosphereService`.
- `src/server/Mansion`: `MansionLayout` (lógica pura y testeable) y `MansionBuilder` (piezas de Roblox).
- `src/client/Controllers`: `UIController` (HUD), `InvestigatorController`, `AnomalyController`, `SanityController` (alucinaciones), `CameraController` (kill cam y espectador) y `AmbienceController` (parpadeo de luces).
- `docs/`: documentación del juego; ábrela como vault de Obsidian.

## Próximas fases

- **Fase 2**: voz posicional (el ruido delata tu dirección a la Anomalía) con alternativa sin voz (pasos, correr, emotes de pánico).
- **Fase 3**: fantasma vengativo (pistas menores, luces con cooldown).
- **Fase 4**: DataService (guardado), monedas, tienda, gacha de formas cosméticas con probabilidades visibles y respetando las políticas de Roblox.
