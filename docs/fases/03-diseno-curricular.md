# Fase 3. Diseño curricular

Entregables pedidos por la especificación y dónde viven:

| Entregable | Ubicación |
| --- | --- |
| 1. Mapa completo del curso | `content/curriculum.yaml` (15 etapas, 49 módulos con objetivos y temas); resumen en `docs/CURRICULO.md` |
| 2. Secuencia de prerrequisitos | `prerequisites` de cada módulo; tabla en `docs/CURRICULO.md`. El validador impide prerrequisitos inexistentes o posteriores |
| 3. Esquema de contenido | `src/content/schema.ts`; guía en `docs/CONTENIDO.md` |
| 4. Criterios de evaluación | `docs/CURRICULO.md`, sección «Criterios de evaluación» |
| 5. Catálogo de proyectos | `content/projects/` (8 proyectos); tabla en `docs/CURRICULO.md` |
| 6. Banco inicial de coding challenges | 5 escritos en `content/challenges/` + lista planificada en `docs/CURRICULO.md` |
| 7. Estrategia de persistencia | `docs/ARQUITECTURA.md`, «Modelo de datos» y «Respaldo» |
| 8. Criterios de calidad | Abajo |

## Matriz de competencias

| Competencia | Etapas y módulos | Prerrequisitos | Ejercicios y evaluación | Proyecto | Recursos oficiales | Resultado observable |
| --- | --- | --- | --- | --- | --- | --- |
| Pensamiento computacional | E1: M1–M3 | Ninguno | Diseño de algoritmos (H), clasificación de errores (A) | — | Swift Book, Xcode | Escribe algoritmos precisos con casos límite |
| Swift esencial | E2: M4–M8 | M3 | Predicción (B), completar (C), errores (D), resolver (E) | P1 | Swift Book | Programas de consola correctos |
| Modelado y abstracción | E3: M9–M13 | M8 | Refactorización (G), explicar (F) | P1 | Swift Book, Swift Evolution | Elige struct/class/enum, diseña con protocolos, evita ciclos |
| Ingeniería de software | E4: M14 | M13 | Revisión de código, diseño (H) | P2 | Swift Package Manager | Trabaja con Git, paquetes y PR |
| Algoritmos | E5: M15–M20 | M7, M8, M10 | Retos con pruebas Swift | P2 | — | Resuelve mediums y defiende complejidad |
| Plataforma iOS | E6: M21 | M14 | Comprensión y diseño | P3 | UIKit, TN3187 | Explica ciclo de vida de app y escena |
| UIKit | E7: M22–M27 | M21 | Resolver y depurar en Xcode | P3, P4 | UIKit, HIG | Construye y mantiene apps UIKit |
| Concurrencia | E8: M28–M29 | M26, M13 | Encontrar errores de data races, refactorizar a async/await | P4, P7 | Swift Book (Concurrency), Migration Guide | Código libre de data races en Swift 6 |
| Datos, arquitectura, testing | E9: M30–M33 | M29 | Diseño de capas, pruebas con dobles | P4 | URLSession, SwiftData, Swift Testing | Capa de datos testeable |
| SwiftUI | E10: M34–M39 | M27, M29 | Ubicación del estado, navegación por valores | P5 | SwiftUI, Observation | Apps SwiftUI con estado correcto |
| Interoperabilidad | E11: M40 | M39 | Integración | P6 | SwiftUI, UIKit | App híbrida sin fugas |
| Calidad y seguridad | E12: M41–M43 | M33, M31, M40 | Checklist de calidad, MASVS | P7 | OWASP MASVS/MASTG, Keychain, Review Guidelines | App lista para producción y auditoría |
| Entrevistas | E14: M46–M48 | M20, M42, M43 | Simulaciones, seguimientos, system design | P8 | — | Defiende decisiones ante seguimientos |
| Ejercicio profesional | E15: M49 | M48 | Proyecto final y revisión | P8 | — | Entrega documentada y defendida |

La etapa 13 (tecnologías del sistema) es opcional y no es prerrequisito del recorrido principal.

## Revisión de vacíos

- Entre fundamentos y avanzado: cubiertos con M13 (memoria) antes de UIKit, M21 (cómo funciona una app) antes de UIKit, y M28 (hilos, GCD, conceptos de concurrencia) antes de Swift Concurrency.
- Orden ajustado: concurrencia (E8) antes de networking (E9), porque networking usa `async/await`.
- Agregado a pedido: Módulo 42, Desarrollo seguro en iOS, y categoría de entrevistas «Seguridad».

## Criterios de calidad del contenido

- Cada lección: objetivos, prerrequisitos válidos, al menos un ejercicio con solución explicada, sección «Lo que debes poder hacer ahora» con capacidades observables, recursos verificados.
- Cada concepto: definición sencilla, explicación técnica, ejemplo mínimo explicado línea por línea, errores frecuentes.
- Código con `codeStatus` honesto; salidas de predicción verificadas.
- Cada reto: enunciado, restricciones, casos límite, preguntas al entrevistador, pistas, solución ingenua y optimizada, explicación, complejidad, pruebas Swift, errores frecuentes, seguimientos, variante y rúbrica.
- Sin videos, sin relleno, sin preguntas duplicadas.
