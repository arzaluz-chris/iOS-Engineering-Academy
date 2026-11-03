# iOS Engineering Academy

Academia personal para aprender desarrollo iOS desde cero hasta nivel profesional y prepararse para entrevistas técnicas. Curso en español de México, con términos técnicos en inglés.

Sitio: https://arzaluz-chris.github.io/iOS-Engineering-Academy/

No hay backend ni cuentas. El progreso, las notas, los borradores de código y el repaso espaciado se guardan en el navegador (IndexedDB) y se respaldan con exportación e importación de un JSON validado.

## Qué incluye

- **Currículo:** 15 etapas y 49 módulos, de fundamentos de programación a mobile system design, con UIKit y SwiftUI como etapas completas y un módulo de desarrollo seguro (OWASP MASVS). Mapa en [`content/curriculum.yaml`](content/curriculum.yaml).
- **Lecciones** con objetivos, prerrequisitos, terminología, explicación, errores frecuentes, ejercicios y la sección «Lo que debes poder hacer ahora».
- **Ocho formatos de ejercicio** (A–H). Los de respuesta estructurada se califican automáticamente; los de código y diseño se autoevalúan con rúbrica. Ningún código Swift se marca como correcto comparando texto.
- **Retos de código** con pistas y secciones que se revelan una a una, tres modos de práctica (guiado, independiente, simulación de entrevista con cronómetro opcional) y soluciones de referencia en Swift con pruebas reales.
- **Entrevistas:** banco de preguntas por categoría con respuesta modelo, puntos clave y seguimientos; simulaciones y resultados por categoría.
- **Repaso espaciado** con FSRS (ts-fsrs), alimentado por conceptos de lecciones completadas y por fallos.
- **Proyectos:** ocho proyectos acumulativos con hitos y criterios de aceptación.
- Buscador global sin acentos, notas, marcadores, modo claro y oscuro, diseño adaptable.

El estado real del contenido (qué está escrito y qué falta) está en [`docs/ESTADO.md`](docs/ESTADO.md).

## Ejecutar localmente

Requisitos: Node.js 22 o posterior. Para las pruebas de Swift, Xcode 16 o posterior (o una toolchain de Swift 6).

```bash
npm install
npm run dev          # servidor de desarrollo
npm run validate     # valida el contenido (esquema e integridad)
npm test             # pruebas web (Vitest)
npm run build        # validación + tipos + compilación en dist/
npm run preview      # sirve dist/
npm run check-links  # verifica los enlaces de recursos (requiere red)
```

Pruebas de las soluciones Swift:

```bash
cd swift
swift test                        # todas
swift test --filter TwoSumTests   # un reto
```

## Integración continua

- `.github/workflows/deploy.yml`: valida contenido, tipos y pruebas, compila y publica en GitHub Pages (push a `main`).
- `.github/workflows/swift.yml`: corre `swift test` en macOS cuando cambia `swift/`.
- `.github/workflows/links.yml`: verificación semanal de enlaces.

GitHub Pages debe tener **Settings → Pages → Source: GitHub Actions**.

## Documentación

- [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md): stack, decisiones, modelo de datos, persistencia y pruebas.
- [`docs/CONTENIDO.md`](docs/CONTENIDO.md): cómo escribir lecciones, ejercicios, retos, preguntas y proyectos.
- [`docs/CURRICULO.md`](docs/CURRICULO.md): mapa, secuencia de prerrequisitos y criterios de evaluación.
- [`docs/INVESTIGACION.md`](docs/INVESTIGACION.md): fuentes, versiones vigentes y decisiones técnicas investigadas.
- [`docs/ESTADO.md`](docs/ESTADO.md): progreso de producción, criterios de aceptación pendientes y siguiente paso.
- [`docs/fases/`](docs/fases/README.md): informes de cada fase (auditoría, investigación completa, diseño, construcción, contenido, pruebas, auditoría).
- [`docs/ESPECIFICACION.md`](docs/ESPECIFICACION.md): especificación original del proyecto.
