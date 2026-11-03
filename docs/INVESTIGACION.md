# Investigación (Fase 2)

Fecha de la investigación: noviembre de 2026. Los datos marcados como «no verificado» deben confirmarse antes de usarse en una lección.

## Versiones vigentes

| Componente | Versión | Fuente |
| --- | --- | --- |
| Swift | 6.4 (15 sep 2026); parche 6.4.2 (30 oct 2026) | Blog de swift.org «Swift 6.4 Released»; Swift Forums «Announcing Swift 6.4.2» |
| Xcode | 27.2 (27B52, 29 oct 2026); incluye Swift 6.4.2; requiere macOS Tahoe 26.6 y Apple silicon | Apple Developer Releases; Xcode system requirements |
| iOS SDK | 27.2 (26 oct 2026) | Apple Developer Releases |
| Deployment targets admitidos por Xcode 27 | iOS 15 a 27 | Xcode system requirements |
| Requisito App Store vigente | Compilar con Xcode 26+ y SDK de iOS 26 | Upcoming Requirements (28 abr 2026) |
| Requisito anunciado | Desde abril de 2027, compilar con el SDK de iOS 27 | Apple Developer News (9 sep 2026) |

**Deployment target del curso:** iOS 17 como base para proyectos (Observation, SwiftData, NavigationStack); iOS 27 para laboratorios de APIs nuevas con `if #available`.

## Cambios que afectan el currículo

- **UIKit:** con el SDK de iOS 27, las apps que no adoptan el ciclo de vida por escenas no arrancan (documentación de UIKit, TN3187). Por eso el curso enseña escenas desde el primer proyecto UIKit.
- **Concurrencia:** modo de lenguaje Swift 6 con aislamiento estricto; desde Swift 6.2, *approachable concurrency* y aislamiento por defecto en `@MainActor` (SE-0466). Se enseña primero el modelo de hilos y GCD (que siguen en código existente) y después Swift Concurrency.
- **SwiftUI:** `NavigationView` está deprecada desde iOS 16; `ObservableObject` no está deprecado y sigue enseñándose como API heredada importante.
- **Swift Testing:** incluido en la toolchain; desde Swift 6.4 interopera con XCTest.
- No verificado en notas oficiales: observation tracking automático en UIKit (WWDC26), formato de proyecto JSON en Xcode 27.2, *source break* relacionado con SE-0508.

## APIs: actuales, heredadas y deprecadas

| Área | Actual | Heredada que se enseña | Deprecada |
| --- | --- | --- | --- |
| Estado SwiftUI | `@Observable`, `@State`, `@Bindable`, `@Environment` | `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` | — |
| Navegación SwiftUI | `NavigationStack`, `NavigationSplitView` | — | `NavigationView` |
| Ciclo de vida UIKit | Escenas | `UIApplicationDelegate` para eventos de proceso | Ciclo sin escenas (no arranca con SDK de iOS 27) |
| Concurrencia | async/await, tareas, actors, `Sendable` | GCD, completion handlers, `OperationQueue` | — |
| Listas UIKit | Collection view + compositional layout + diffable | `UITableView` clásico | — |
| Persistencia | SwiftData | Core Data, `UserDefaults`, Keychain | — |
| Pruebas | Swift Testing | XCTest, XCUITest | — |

## Ejecución de Swift en el navegador

| Opción | Estado | Compila código del usuario en el cliente | Decisión |
| --- | --- | --- | --- |
| Swift SDK for Wasm (oficial) | Activo | No: compila hacia Wasm desde una máquina con toolchain | Útil para demos precompiladas, no para ejercicios |
| carton | Archivado (nov 2025) | No | Descartado |
| swiftc compilado a Wasm | Sin proyecto mantenido | En teoría | Inviable |
| MiniSwift | Proyecto personal, subconjunto | Sí, aproximado | Descartado: semántica no garantizada |
| SwiftFiddle y playgrounds en línea | Activos | No (servidor) | Descartado: dependencia externa, sin uso sin conexión |

**Decisión:** editor en el navegador, borradores guardados localmente, pruebas Swift Testing para ejecutar en Xcode o con `swift test`, y autoevaluación explícita. Las soluciones de referencia se compilan y prueban en CI (macOS).

## Referencias curriculares (estructura, no contenido)

| Referencia | Qué se tomó | Vacío que cubre la academia |
| --- | --- | --- |
| Stanford CS193p (2025) | SwiftUI con MVVM, progresión por proyecto | UIKit, testing; supone experiencia previa |
| Apple Develop in Swift | Secuencia SwiftUI → Observation → SwiftData | UIKit, concurrencia avanzada, algoritmos |
| Hacking with Swift (100 Days) | Ciclos teoría–proyecto–consolidación | Concurrencia estricta reciente |
| Kodeco | Libros por tema con proyecto continuo | Ediciones antiguas por verificar |
| NeetCode 150 / LeetCode | 18 categorías de patrones | Implementación en Swift y sus particularidades |
| Udemy, Coursera | No verificado | — |

Vacíos comunes que la academia cubre explícitamente: UIKit profundo, concurrencia de Swift 6, testing, accesibilidad, rendimiento con Instruments, arquitectura y modularización, algoritmos en Swift, mobile system design, distribución y **desarrollo seguro** (OWASP MASVS/MASTG), este último a pedido por su peso en entrevistas de banca.

## Patrones algorítmicos (orden NeetCode)

Arrays y hashing; two pointers; sliding window; stack; búsqueda binaria; listas enlazadas; árboles; tries; heaps; backtracking; grafos; grafos avanzados; DP 1-D; DP 2-D; greedy; intervalos; matemáticas y geometría; manipulación de bits. El reparto por dificultad de NeetCode 150 difiere entre fuentes de terceros y no se verificó en neetcode.io.

Particularidades de Swift en entrevistas: indexar `String` no es O(1) (convertir a `Array`); la biblioteca estándar no trae heap ni deque (implementarlos a mano); `Dictionary(_:default:)`, `reduce(into:)`.

## Enlaces

El entorno de construcción no tenía acceso de red a developer.apple.com ni docs.swift.org. Todos los recursos quedan como `no-verificado` hasta que corra `npm run check-links` (workflow semanal `links.yml`). La URL `developer.apple.com/tutorials/instruments` que figuraba en la especificación probablemente no existe; no se incluyó.
