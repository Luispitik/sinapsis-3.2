---
name: session-end
description: >
  Cierra la sesión documentando automáticamente lo que se hizo, lo que queda pendiente
  y las decisiones tomadas. Guarda el resumen en memory/session-logs/ y actualiza MEMORY.md
  si hubo cambios estructurales. USAR cuando el usuario diga "cerramos", "hasta luego",
  "fin de sesión", "session-end", "guarda donde estamos", o cualquier intent de cerrar sesión.
---

# Session End — Documentación automática de sesión

> **Nota**: Este comando extiende `/eod`. Primero ejecuta el flujo EOD (save daily summary),
> luego añade el session log detallado y actualiza MEMORY.md si procede.
> Para solo guardar el contexto multi-proyecto sin session log, usa `/eod` directamente.

Al ejecutar este comando, haz lo siguiente SIN preguntar:

## 1. Generar resumen de sesión

Analiza toda la conversación actual y genera un markdown con esta estructura:

```markdown
# Sesión [FECHA] — [Título descriptivo breve]

## Lo que se hizo
- [Lista de cada tarea completada con detalle suficiente para retomar]

## Pendiente para próxima sesión
- [Lista priorizada de lo que quedó sin hacer]
- [Incluir contexto suficiente para no tener que re-explicar]

## Decisiones tomadas
- [Decisiones técnicas, estratégicas o de producto tomadas en esta sesión]

## Skills/archivos creados o modificados
- [Lista de archivos nuevos o editados con path completo]

## Notas
- [Cualquier contexto relevante que la próxima sesión necesite saber]
```

## 2. Guardar el archivo

Detectar el directorio de memory del proyecto actual. Buscar en este orden:
1. `~/.claude/projects/{project-id}/memory/session-logs/`
2. Si no existe session-logs/, crearlo

Nombre del archivo: `YYYY-MM-DD-HHmm.md` (fecha y hora actual)

## 3. Actualizar MEMORY.md (solo si aplica)

Si durante la sesión se crearon skills nuevas, se modificó la estructura del proyecto,
se tomaron decisiones que afectan a futuras sesiones, o se cambió algo del sistema
Skills on Demand — actualizar la sección correspondiente de MEMORY.md.

NO reescribir todo MEMORY.md. Solo añadir o actualizar las secciones afectadas.

## 4. Confirmar al usuario

Mostrar un resumen breve:
```
📋 Sesión documentada en: [path al archivo]
📝 MEMORY.md: [actualizado / sin cambios]
🔜 Próxima sesión: [1-2 líneas de lo más urgente pendiente]
```

## Reglas

- NO preguntar nada — ejecutar directamente
- Ser conciso pero con suficiente detalle para retomar sin contexto
- Incluir paths completos de archivos creados/modificados
- Si no hubo cambios estructurales, no tocar MEMORY.md
- El título del archivo debe ser descriptivo (no genérico)
