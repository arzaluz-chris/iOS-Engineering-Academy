# Cómo escribir contenido

Todo el curso vive en `content/` y en `swift/`. La aplicación no se toca para agregar contenido. Después de cualquier cambio:

```bash
npm run validate && npm test
```

## Lecciones

Archivo `content/lessons/<módulo>/<orden>-<slug>.md`:

```markdown
---
id: m05-l01                 # único en todo el curso
title: …
description: …
module: m05                 # debe existir en curriculum.yaml
order: 1                    # único dentro del módulo
level: inicial              # inicial | intermedio | avanzado
minutes: 40
codeStatus: revisado        # probado | revisado | ilustrativo | sin-codigo
swiftVersion: "6.4"         # cuando aplique
prerequisites: [m04-l03]    # lecciones anteriores en la secuencia
objectives: [ … ]
terms: [{ term: …, definition: … }]
mastery: [ … ]              # «Lo que debes poder hacer ahora»: capacidades observables
resources: [swift-book]     # ids de resources.yaml
cards: [{ id: m05-l01-c1, front: …, back: … }]   # entran al repaso al completar
---

## Secciones con ## …
```

Estructura recomendada de cada concepto: definición sencilla, explicación técnica, analogía con sus límites (si ayuda), ejemplo mínimo, explicación línea por línea, ejemplo práctico, errores frecuentes, ejercicios, resumen.

Avisos disponibles dentro del texto:

```markdown
> [!error] error: cannot find 'Print' in scope
> Explicación…

> [!aviso] …     > [!nota] …     > [!practica] …     > [!version] …
```

`codeStatus` debe ser honesto: `probado` solo si el código se compiló y ejecutó; `revisado` si se revisó sin compilar; `ilustrativo` para fragmentos explicativos.

### Fragmentos ejecutados por las pruebas

El target `swift/Tests/LessonSnippetsTests` lee `content/lessons/` y compila cada fragmento como programa independiente (`swiftc -swift-version 6`), lo ejecuta y compara su salida:

- **Todo ejercicio `prediccion`**, en cualquier lección: `code` debe compilar y su salida debe ser exactamente `output`. Escribe `code` y `output` como bloques literales `|` (o `|-` si la salida no termina en salto de línea). Si la solución repite la salida en un bloque ```` ```output ````, debe coincidir con `output`.
- **En lecciones con `codeStatus: probado`**, cada bloque ```` ```swift ```` del texto y de las soluciones de ejercicios:
  - ```` ```swift ```` debe compilar y ejecutarse sin fallar. Si el siguiente bloque cercado es ```` ```output ````, la salida debe coincidir exactamente.
  - ```` ```swift no-compila <texto del diagnóstico> ```` debe fallar al compilar con un diagnóstico que contenga ese texto. Úsalo para los ejemplos de errores del compilador.
  - ```` ```swift ilustrativo ```` no se ejecuta: fragmentos que dependen de otro bloque o código de frameworks de Apple que no compila fuera de Xcode.

La web solo usa la primera palabra del bloque para el resaltado, así que estos modificadores no se ven. Ejecuta las pruebas con `cd swift && swift test --filter LessonSnippetsTests` (en Linux, por ejemplo, con `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test`). El workflow «Swift · pruebas de los retos» las corre en macOS en cada push que toque `content/lessons/`.

### YAML

Si un valor contiene `: ` (dos puntos y espacio), ponlo entre comillas o el YAML será inválido. El validador lo detecta.

## Ejercicios

Dentro de la lección, en bloques de **cuatro** comillas invertidas para poder usar bloques ``` en sus campos:

`````markdown
````exercise
id: m05-l01-e1
type: comprension | prediccion | completar | errores | resolver | explicar | refactorizar | diseno
prompt: …
hints: [ … ]          # opcional, se revelan una a una
solution: |           # obligatoria, explicada
  …
# campos por tipo:
# comprension: choices [{text, correct, why}], multiple (bool)
# prediccion:  code, output (exacta), accept (alternativas)
# completar:   code con huecos [[1]], blanks [{id: "1", answers: [...]}]
# errores:     code, choices (problemas reales y distractores), rubric
# resolver:    starter, rubric, tests (opcional, Swift Testing)
# explicar / refactorizar: code, rubric
# diseno:      rubric
````
`````

Reglas: la salida de `prediccion` debe estar verificada; los huecos deben coincidir con `blanks`; en selección única debe haber exactamente una opción correcta.

## Retos de código

1. Solución en `swift/Sources/Challenges/<Nombre>.swift` (funciones `public`).
2. Pruebas en `swift/Tests/ChallengesTests/<Nombre>Tests.swift` con Swift Testing (`@Test`, `#expect`).
3. Ficha en `content/challenges/<slug>.md`: frontmatter (dificultad, patrones, `solutionFile`, `testFile`, `starter`, complejidad, casos límite, preguntas al entrevistador, pistas, seguimientos, rúbrica), enunciado, el marcador `<!-- revelar -->` y después secciones `## Enfoque inicial`, `## Solución ingenua`, `## Problemas de la solución ingenua`, `## Solución optimizada` (aquí se inserta el código de `swift/`), `## Explicación línea por línea`, `## Errores frecuentes`, `## Variante`.
4. `cd swift && swift test`. Cuando CI pase, cambia `codeStatus` a `probado`.

## Preguntas de entrevista

En `content/interview/<categoría>.yaml`: `id`, `category`, `difficulty`, `question`, `answer` (Markdown), `keyPoints` (la rúbrica), `followUps` [{question, answer}], `writesCode`, `related`.

## Proyectos

`content/projects/pNN-<slug>.md` con objetivos, requisitos, criterios de aceptación e hitos (`milestones` con `tasks` y `concepts`).

## Recursos

`content/resources.yaml`. Sin videos. Cada recurso con fuente, tipo (`oficial`, `tutorial`, `articulo`, `referencia`), tema, por qué consultarlo y `status`. Marca `verificado` con fecha solo después de comprobarlo (`npm run check-links` o el workflow semanal). Enlaza la documentación concreta de la API, no la portada.
