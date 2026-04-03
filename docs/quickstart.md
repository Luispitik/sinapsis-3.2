# Sinapsis — Guia de Configuracion Post-Instalacion

> Acabas de instalar Sinapsis. Esta guia te explica que tienes, que hace cada parte, y como configurarlo para que funcione al 100%.

---

## Paso 1: Entiende que se ha instalado

Despues de ejecutar `install.sh` o `install.bat`, tienes esto en tu ordenador:

```
~/.claude/
  CLAUDE.md                ← Tu "carta de presentacion" para Claude
  skills/
    skill-router/          ← El cerebro que decide que skills cargar
    synapis-learning/      ← El motor que aprende de ti (en segundo plano)
    synapis-instincts/     ← La base de datos de lo que ha aprendido
    synapis-researcher/    ← Investigacion profunda con multiples fuentes
    synapis-optimizer/     ← Controla que no gastes tokens de mas
    _library/              ← Skills dormidas (se activan cuando las necesitas)
    _archived/             ← Skills retiradas (recuperables)
    _catalog.json          ← Registro de todas las skills disponibles
    _passive-rules.json    ← Reglas que se aplican solas (seguridad, calidad)
    _operator-state.json   ← TU identidad, decisiones, memoria entre proyectos
    _projects.json         ← Registro de tus proyectos
  commands/                ← Comandos que puedes ejecutar (/evolve, /clone, etc.)
```

**No necesitas tocar ninguno de estos archivos manualmente.** Claude los gestiona por ti.

---

## Paso 2: Abre Claude Code y haz el onboarding

1. Abre tu terminal
2. Navega a cualquier carpeta de proyecto: `cd mi-proyecto`
3. Ejecuta: `claude`
4. Sinapsis detecta que es tu primera vez y te pregunta

### Que te va a preguntar

Sinapsis busca primero si ya tienes informacion guardada (CLAUDE.md previo, proyectos anteriores, archivos de configuracion). Si encuentra algo, te lo muestra:

```
He encontrado informacion sobre ti:
- Nombre: [detectado de git config]
- Proyectos: 3 encontrados
- Stack: Next.js (detectado de package.json)

¿Es correcto? (S/n)
```

Si no encuentra nada, te ofrece dos caminos:

```
[A] Rapida — 3 preguntas y empezamos (30 segundos)
[B] Completa — Cuentame todo y no te vuelvo a preguntar
```

### Opcion A: Rapida

Te pregunta:
1. **Tu nombre** — para dirigirse a ti
2. **A que te dedicas** — para saber que tipo de proyectos haces
3. **Que tecnologias usas** — para sugerirte las skills correctas

### Opcion B: Completa (recomendada)

Cuentale todo lo que quieras: quien eres, que empresa tienes, que proyectos manejas, que herramientas usas, como te gusta trabajar, que errores has cometido antes, que cosas quieres evitar.

**Todo lo que le digas se guarda en el Operator State y se aplica en TODOS tus proyectos futuros.** No tendras que repetirlo.

---

## Paso 3: Elige tu modo de trabajo

Despues del onboarding, cada vez que abras una sesion veras:

```
[1] Skills on Demand — Carga automatica de skills segun tu proyecto
[2] Skill Picker — Tu eliges que skills instalar
[3] Freestyle — Claude normal, sin sistema de skills
```

### Cuando usar cada uno

| Modo | Para quien | Ejemplo |
|------|-----------|---------|
| **[1] Skills on Demand** | Quieres que Claude sea inteligente automaticamente | "Quiero hacer una landing page" → carga las skills de web |
| **[2] Skill Picker** | Quieres control total sobre que se carga | Sabes exactamente que skills necesitas |
| **[3] Freestyle** | No quieres que Sinapsis interfiera | Tarea rapida, prueba, o prefieres Claude vanilla |

**Puedes cambiar de modo en cualquier momento** diciendo "launcher".

---

## Paso 4: Configura tus reglas pasivas (opcional)

Las reglas pasivas son "guardianes" que se activan solos. Por defecto tienes 5:

| Regla | Que hace | Cuando salta |
|-------|---------|-------------|
| **env-never-commit** | Evita que subas secrets a git | Al hacer git commit |
| **html-twin** | Genera version HTML de documentos | Al crear .docx, .pdf, .pptx |
| **git-commit-triage** | Verifica errores antes de commit | Al hacer git commit |
| **decision-capture** | Guarda decisiones estrategicas | Cuando dices "a partir de ahora..." |
| **pattern-observer** | Detecta patrones que repites | Siempre (en segundo plano) |

### Como anadir mas reglas

Usa `/evolve` despues de varias sesiones. Sinapsis te sugerira nuevas reglas basadas en tus patrones. Tu decides cuales activar.

### Como activar las reglas en settings.json

Para que las reglas funcionen automaticamente (sin que Claude las lea cada vez), necesitas configurar hooks en Claude Code:

1. Abre `~/.claude/settings.json` (o crealo si no existe)
2. Anade esta seccion:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$TOOL_INPUT\" | grep -qi 'git commit\\|git add'; then echo '[SYNAPIS] Verificar: .env en .gitignore, lint limpio, sin secrets en staged files'; fi"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$TOOL_INPUT\" | grep -qi '\\.docx\\|\\.pdf\\|\\.pptx'; then echo '[SYNAPIS] Recuerda: generar version HTML del entregable'; fi"
          }
        ]
      }
    ]
  }
}
```

**No quieres tocar settings.json?** No pasa nada. Las reglas siguen funcionando porque Sinapsis las lee al inicio de cada sesion. Los hooks simplemente las hacen mas fiables.

---

## Paso 5: Aprende los comandos basicos

Estos son los comandos que mas vas a usar:

### /system-status
Muestra el estado completo de tu sistema: skills instaladas, tokens, proyectos, salud.

```
Escribe: /system-status
```

### /evolve
Analiza los patrones que Sinapsis ha detectado y te propone convertirlos en skills, reglas, o comandos.

```
Escribe: /evolve
```

Te mostrara algo como:
```
Hay 3 candidatos. Que hacemos con cada uno?

1. patron-detectado-1  → [S] Skill  [R] Regla  [X] Skip
2. patron-detectado-2  → [S] Skill  [E] Enriquecer  [X] Skip
3. patron-detectado-3  → [R] Regla  [X] Skip

Responde: "1S 2E 3R"
```

### /skill-audit
Si ya tenias skills instaladas antes de Sinapsis, este comando las analiza y te propone limpieza:

```
Escribe: /skill-audit
```

Te muestra cuantos tokens gasta cada skill y sugiere fusiones, archivados, y eliminaciones. **Nada se borra sin tu permiso.**

### /clone
Clona un proyecto exitoso como base para uno nuevo:

```
Escribe: /clone
```

Copia las skills, estructura, y configuracion de un proyecto anterior.

---

## Paso 6: Crea tus propias skills (avanzado)

Sinapsis es un sistema que crece contigo. Hay tres formas de crear skills:

### A. Automatica (recomendada)
Trabaja normal. Sinapsis observa. Cuando detecta un patron maduro, `/evolve` te lo propone. Tu aceptas o rechazas.

### B. Semi-automatica
Dile a Claude: "Aprende esto: siempre que haga X, haz Y". Sinapsis lo registra como instinct y lo madura con el tiempo.

### C. Manual
Crea un archivo `.md` en `~/.claude/skills/_library/tu-skill/SKILL.md` con este formato:

```markdown
---
name: mi-skill
description: Que hace esta skill (una linea)
triggers: palabras, que, activan, esta, skill
version: 1.0.0
tokens_estimate: 500
---

# Mi Skill

## Que hace
[Explicacion]

## Cuando se activa
[Triggers y contextos]

## Reglas
[Lo que Claude debe hacer cuando esta skill esta activa]
```

---

## Paso 7: Resuelve problemas comunes

### "Sinapsis no se activa al abrir Claude Code"
- Verifica que `~/.claude/CLAUDE.md` existe y contiene la seccion "Sinapsis"
- Ejecuta `/system-status` para ver si el sistema esta operativo

### "Mis skills no se instalan en el proyecto"
- Verifica que `~/.claude/skills/_catalog.json` tiene la skill registrada
- Ejecuta `/skill-audit` para ver el estado de tus skills

### "Las reglas pasivas no se activan solas"
- Las reglas se aplican de dos formas: por hooks (settings.json) o por lectura directa
- Si no tienes hooks configurados, Sinapsis las lee al inicio de sesion
- Para maxima fiabilidad, configura los hooks (Paso 4)

### "Quiero resetear todo y empezar de cero"
```bash
# Backup primero
cp -r ~/.claude/skills ~/.claude/skills_backup_$(date +%Y%m%d)

# Reinstalar
cd synapis
./install.sh  # o install.bat en Windows
```

### "Quiero desinstalar Sinapsis"
Elimina estas carpetas:
- `~/.claude/skills/skill-router/`
- `~/.claude/skills/synapis-*/`
- Los comandos en `~/.claude/commands/` que instalo Sinapsis

Tu CLAUDE.md y proyectos quedan intactos.

---

## Siguiente paso

Usa Claude Code como siempre. Sinapsis trabaja en segundo plano.

Despues de 3-5 sesiones, ejecuta `/evolve` y mira que ha aprendido. Te sorprendera.

---

## Quieres mas?

Si quieres aprender a crear skills avanzadas, personalizar el sistema para tu negocio, o sacarle el maximo partido:

**[salgadoia.com](https://salgadoia.com)** — Mentorias, cursos y consulting sobre Claude Code + Sinapsis.

---

*Sinapsis: porque tu asistente deberia recordar quien eres.*
