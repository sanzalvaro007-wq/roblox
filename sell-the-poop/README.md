# 💩 Sell the Poop

Versión con caca de *Sell Lemons 🍋* (Roblox). Haz caca, véndela, compra mejoras, acepta tratos de un comprador misterioso y reinicia con el **Laxante Cósmico** para multiplicar todo.

## Qué incluye

- **Hacer caca** con un botón (+caca por click) y **vender** en el botón o en el puesto del mapa.
- **Tienda**: 💪 Intestino Fuerte (más caca por click), ✨ Caca Premium (+25% precio), 🚽 Váter Automático (caca por segundo), 🚚 Camión de Caca (vende solo).
- **Tratos** 👽: cada 1–2 minutos un comprador ofrece x2–x5 durante 30 s.
- **Rebirth** 🌌 Laxante Cósmico: reinicia dinero y mejoras, +x1 permanente a todo.
- **Ganancias offline** al 100% (hasta 24 h) y **guardado automático** con DataStore.
- Leaderboard con Cash, Poop y Rebirths. Anti-autoclicker básico.

Todos los números (precios, multiplicadores, tiempos) están en `src/shared/Config.luau`.

## Estructura

```
src/shared/Config.luau          -> ReplicatedStorage/Shared/Config   (ModuleScript)
src/server/Main.server.luau     -> ServerScriptService/Server/Main   (Script)
src/client/UI.client.luau       -> StarterPlayer/StarterPlayerScripts/Client/UI (LocalScript)
default.project.json            -> proyecto de Rojo
```

## Opción A: con Rojo (recomendado)

1. Instala Rojo (https://rojo.space) y el plugin de Rojo en Roblox Studio.
2. En esta carpeta: `rojo serve`
3. En Studio, abre un Baseplate, pulsa **Connect** en el plugin de Rojo.

## Opción B: a mano en Roblox Studio

1. Abre un **Baseplate** nuevo.
2. En **ReplicatedStorage** crea una **Folder** llamada `Shared` y dentro un **ModuleScript** llamado `Config`. Pega `src/shared/Config.luau`.
3. En **ServerScriptService** crea un **Script** y pega `src/server/Main.server.luau`.
4. En **StarterPlayer > StarterPlayerScripts** crea un **LocalScript** y pega `src/client/UI.client.luau`.
5. Para que se guarde el progreso en Studio: **Game Settings > Security > Enable Studio Access to API Services** (el juego tiene que estar publicado).
6. Pulsa **Play**.
