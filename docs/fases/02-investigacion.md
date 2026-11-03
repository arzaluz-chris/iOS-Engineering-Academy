# Fase 2. Informe de investigación verificada (noviembre de 2026)

Informe completo de la investigación previa. El resumen operativo está en `docs/INVESTIGACION.md`.

La base técnica vigente para diseñar la academia es Swift 6.4 (6.4.2 en la página de instalación de swift.org), Xcode 27.2 e iOS 27.2. El hallazgo con mayor impacto en el plan de estudios es que, desde el SDK de iOS 27, las apps UIKit que no adopten el ciclo de vida basado en escenas (UIScene) no arrancan. Para ejecutar código, lo más sensato es no compilar Swift real en el navegador: conviene combinar un editor con ejercicios evaluados localmente mediante Swift Packages (`swift test` y Xcode) y dejar la ejecución en el navegador como una capa experimental opcional.

> **Nota posterior a la investigación (3 nov 2026):** los 20 recursos registrados en `content/resources.yaml` se verificaron con el workflow `links.yml` (20/20 responden). Las URLs candidatas marcadas como «no verificado» en la sección 1.2 que aún no están en `resources.yaml` siguen sin verificar.

## Resumen

- **Versiones vigentes:** Swift 6.4 salió el 15 de septiembre de 2026 y su parche más reciente es 6.4.2, anunciado en Swift Forums el 30 de octubre de 2026 e incluido en Xcode 27.2. Xcode 27.2 (27B52) salió el 29 de octubre de 2026, solo corre en Apple silicon y requiere macOS Tahoe 26.6. iOS 27.2 es del 26 de octubre de 2026. Xcode 27 admite deployment targets de iOS 15 a 27. Recomendación: iOS 17 como mínimo base del curso e iOS 27 para laboratorios de APIs nuevas.
- **Ejecutar Swift en el navegador:** el compilador oficial no corre en el navegador. El Swift SDK for Wasm compila *hacia* Wasm desde una máquina con la toolchain. carton fue archivado el 29 de noviembre de 2025. Los playgrounds en línea compilan en un servidor. MiniSwift corre en el cliente pero es un compilador independiente y no es 100 % compatible. Recomendación: editor + ejercicios como Swift Package con pruebas, ejecutados en Xcode o con `swift test`.
- **Stack recomendado por la investigación:** Astro 6 con islas de React, CodeMirror 6, Shiki, Dexie/IndexedDB, búsqueda local y ts-fsrs 6 con FSRS fijado explícitamente. (La implementación final eligió Vite + React; ver `04-diseno-tecnico.md`.)

## 1. Verificación de fuentes oficiales

Advertencia metodológica: durante la investigación no fue posible cargar directamente la mayoría de las URLs de `developer.apple.com/documentation/...` y `docs.swift.org`. Se separó lo **cargado**, lo **confirmado indirectamente** y lo **no verificado**.

### 1.1 URLs solicitadas

| URL | Estado en la investigación | Tipo | Notas |
| --- | --- | --- | --- |
| docs.swift.org/swift-book/…/the-swift-programming-language/ | Confirmada indirectamente | Documentación oficial | Posible integración en docs.swift.org/latest/documentation desde Swift 6.4. Verificada 200 el 3 nov 2026. |
| www.swift.org | Cargada | Sitio oficial | Navegación muestra «Install (6.4.2)». |
| developer.apple.com/documentation/ | Confirmada indirectamente | Documentación oficial | Vigente. |
| developer.apple.com/tutorials/develop-in-swift | Confirmada indirectamente | Tutorial oficial | Cubre SwiftUI, modelos observables, SwiftData, ML, Apple Intelligence y visionOS. |
| developer.apple.com/documentation/uikit | Confirmada indirectamente | Documentación oficial | Documentación de escenas actualizada para iOS 27. |
| developer.apple.com/documentation/swiftui | Confirmada indirectamente | Documentación oficial | Vigente. |
| developer.apple.com/documentation/foundation | No verificado | Documentación oficial | — |
| docs.swift.org/…/concurrency/ | Confirmada indirectamente | Documentación oficial | Complementar con la Migration Guide. |
| developer.apple.com/design/human-interface-guidelines/ | Confirmada indirectamente | Guía oficial | Verificada 200 el 3 nov 2026. |
| developer.apple.com/documentation/testing | No verificado | Documentación oficial | Swift 6.4 añadió interoperabilidad con XCTest (ST-0021). Verificada 200 el 3 nov 2026. |
| developer.apple.com/documentation/foundation/urlsession | No verificado | Documentación oficial | — |
| developer.apple.com/documentation/swiftdata | No verificado | Documentación oficial | — |
| developer.apple.com/documentation/observation | No verificado | Documentación oficial | — |
| developer.apple.com/tutorials/instruments | **Probablemente no existe** | — | Sustituir por documentación de texto de Xcode sobre rendimiento. |
| developer.apple.com/app-store/review/guidelines/ | Confirmada indirectamente | Guía oficial | Verificada 200 el 3 nov 2026. |

### 1.2 URLs candidatas por tema

| Tema | URL candidata | Estado |
| --- | --- | --- |
| UITableView | developer.apple.com/documentation/uikit/uitableview | No verificado |
| Diffable data source | developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource | No verificado |
| Compositional layout | developer.apple.com/documentation/uikit/uicollectionviewcompositionallayout | No verificado |
| Ciclo de vida por escenas | developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle y TN3187 | Confirmada; TN3187 verificada 200 |
| NavigationStack | developer.apple.com/documentation/swiftui/navigationstack | No verificado |
| NavigationView (heredada) | developer.apple.com/documentation/swiftui/navigationview | Confirmada; disponibilidad «iOS 13.0–27.2» (deprecada) |
| @Observable | developer.apple.com/documentation/observation/observable() | No verificado |
| ObservableObject | developer.apple.com/documentation/combine/observableobject | Confirmada; disponibilidad abierta (no deprecada) |
| Swift 6 migration guide | www.swift.org/migration/documentation/migrationguide/ | No verificado |
| Sendable | developer.apple.com/documentation/swift/sendable | No verificado |
| Keychain Services | developer.apple.com/documentation/security/keychain-services | Verificada 200 el 3 nov 2026 |
| Core Data | developer.apple.com/documentation/coredata | No verificado |
| WidgetKit, ActivityKit, App Intents | developer.apple.com/documentation/widgetkit, /activitykit, /appintents | App Intents confirmada indirectamente; resto no verificado |
| UIViewRepresentable | developer.apple.com/documentation/swiftui/uiviewrepresentable | No verificado |
| XCTest | developer.apple.com/documentation/xctest | No verificado |
| TestFlight, App Store Connect | developer.apple.com/testflight/, developer.apple.com/help/app-store-connect/ | Confirmadas indirectamente |
| Requisitos de subida | developer.apple.com/news/upcoming-requirements/ | Confirmada |
| Requisitos de Xcode | developer.apple.com/xcode/system-requirements/ | Confirmada; verificada 200 |
| Swift en Wasm | www.swift.org/documentation/articles/wasm-getting-started.html | Confirmada (usa 6.4.2) |

Recomendación de diseño adoptada: cada recurso guarda `status` y `verifiedAt`, y un workflow verifica los enlaces.

## 2. Actualización tecnológica

### 2.1 Versiones

| Componente | Versión | Fecha | Fuente |
| --- | --- | --- | --- |
| Swift | 6.4; 6.4.1; 6.4.2 | 15 sep, 13 oct, 30 oct 2026 | Blog de swift.org; Swift Forums |
| Swift anterior | 6.3 (24 mar 2026); 6.3.3 (30 jun 2026, en Xcode 26.6) | — | Swift Forums |
| Xcode | 27.2 (27B52); Xcode 27 (27A266a) del 14 sep 2026 | 29 oct 2026 | Apple Developer Releases |
| iOS SDK | 27.2 | 26 oct 2026 | Apple Developer Releases |
| Deployment targets de Xcode 27 | iOS 15–27, macOS 12–27, watchOS 9–27, visionOS 1–27 | — | Xcode system requirements |
| Requisito App Store vigente | Xcode 26+ con SDK de iOS 26 | Desde 28 abr 2026 | Upcoming Requirements |
| Requisito anunciado | SDK de iOS 27 | Desde abril de 2027 | Apple Developer News (9 sep 2026) |
| Swift Testing | En la toolchain de 6.4 | — | Interop con XCTest (ST-0021), `CustomTestReflectable` (ST-0022), repetición por caso (ST-0024) |

Observación de la Fase 7: el runner `macos-latest` de GitHub Actions usaba Xcode 26.6 con Swift 6.3.3 el 3 de noviembre de 2026.

### 2.2 Cambios en Swift 6.x

- **6.0 (sep 2024):** concurrencia estricta por defecto en modo Swift 6; Swift Testing; typed throws (SE-0413, a reconfirmar contra el changelog).
- **6.2 (sep 2025):** Approachable Concurrency y aislamiento por defecto en `@MainActor` (SE-0466).
- **6.3 (mar 2026):** `@c`, module selectors, SDK oficial de Android, vista previa de Swift Build en SwiftPM.
- **6.4 (sep 2026):** `some P?` sin paréntesis (SE-0521); `@diagnose` (SE-0522); selector `::` (SE-0491); `await` en `defer` (SE-0493); `withTaskCancellationShield` (SE-0504); observación continua de `@Observable` (SE-0506); `~Sendable` (SE-0518); `UniqueArray`, `UniqueBox`, `Iterable`; Subprocess 1.0; Swift Build por defecto en SwiftPM.
- *Source break* de Xcode 27 relacionado con SE-0508: reportado por terceros, sin verificar.

### 2.3 WWDC26 (iOS 27)

- **SwiftUI:** API de documentos (`WritableDocument`, `DocumentWriter`); reordenamiento en cualquier contenedor; `swipeActions` fuera de `List`; nuevas APIs de toolbar; transición `.crossFade`; `Tab(role: .prominent)`; caché HTTP en `AsyncImage`; `@ContentBuilder`; `@State` como macro con inicialización perezosa; Liquid Glass actualizado. La mayoría no es retrocompatible.
- **UIKit:** ciclo de vida por escenas obligatorio con el SDK más reciente. Observation tracking automático (sin verificar en notas oficiales).
- **SwiftData:** fetch requests seccionados y `ResultsObserver`.
- **Xcode 27:** agent skills; formato de proyecto JSON en 27.2 beta (sin verificar).

### 2.4 APIs actuales, heredadas y deprecadas

| Área | Actual | Heredada que se enseña | Deprecada | Disponibilidad |
| --- | --- | --- | --- | --- |
| Estado | `@Observable`, `@State`, `@Bindable`, `@Environment` | `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` | — | Observation: iOS 17+ |
| Navegación SwiftUI | `NavigationStack`, `NavigationSplitView`, `NavigationLink(value:)` | — | `NavigationView` y `NavigationLink(destination:tag:selection:)` desde iOS 16 | iOS 16+ |
| Ciclo de vida UIKit | `UIScene` / `UIWindowSceneDelegate` | `UIApplicationDelegate` | Sin escenas: no arranca con SDK de iOS 27 | Escenas desde iOS 13 |
| Concurrencia | async/await, tareas, actors, `Sendable`, `@MainActor`, AsyncSequence | GCD, completion handlers, `OperationQueue`, continuations | — | iOS 13+ con back-deployment |
| Listas UIKit | Collection view + compositional + diffable + cell registration | `UITableView` clásico | — | iOS 13/14+ |
| Persistencia | SwiftData | Core Data, `UserDefaults`, Keychain | — | SwiftData: iOS 17+ |
| UI | SwiftUI; UIKit programático | Storyboards, XIB | — | — |
| Pruebas | Swift Testing | XCTest, XCUITest | — | Interoperables desde 6.4 |
| Reactividad | Observation + AsyncSequence | Combine | — | — |
| Experimentales | Embedded Swift, Wasm en navegador, `UniqueArray` | — | — | Fuera del núcleo |

## 3. Currículos externos

| Referencia | Secuencia | Proyectos | Vacíos |
| --- | --- | --- | --- |
| Stanford CS193p (primavera 2025) | SwiftUI desde el día 1, MVVM, enums, layout, animación, persistencia | Memorize y apps multipantalla | Previo a iOS 26; poco UIKit y testing; supone experiencia |
| Apple Develop in Swift | Hello SwiftUI → contenedores → modelos observables → SwiftData → ML → visionOS | Chat Prototype, Alphabetizer, GratefulMoments | Sin UIKit, poca concurrencia, sin algoritmos |
| Hacking with Swift | Teoría + proyecto + consolidación; *Concurrency by Example* | Muchos proyectos pequeños | 100 Days of Swift (UIKit) sin verificar actualización |
| Kodeco | Libros por tema con proyecto continuo | Apps de bolsa en tiempo real | Ediciones ligadas a Swift 5.5 |
| Udemy, Coursera | No verificado | — | — |
| Swift.org, Forums, Evolution | Propuestas SE-xxxx | — | Documentos para expertos |

Vacíos comunes: UIKit profundo; concurrencia estricta y migración desde GCD; testing; accesibilidad; Instruments; arquitectura y SPM; algoritmos en Swift; mobile system design; distribución.

La matriz curricular propuesta (M0–M20) se transformó en el mapa de 15 etapas y 49 módulos de `content/curriculum.yaml` (ver `03-diseno-curricular.md`).

## 4. Algoritmos y entrevistas

### 4.1 Patrones NeetCode 150

150 problemas en 18 categorías (superconjunto de Blind 75). Reparto por dificultad discrepante entre terceros: 28/97/25 (crackr.dev), 28/101/21 (copilotinterview.com, crackedprep.com, thita.ai), 28/100/22 (leetcode-py); no verificado en neetcode.io.

| # | Categoría | Representativos |
| --- | --- | --- |
| 1 | Arrays & Hashing | Contains Duplicate, Valid Anagram, Two Sum, Group Anagrams, Top K Frequent, Product of Array Except Self |
| 2 | Two Pointers | Valid Palindrome, Two Sum II, 3Sum, Container With Most Water, Trapping Rain Water |
| 3 | Sliding Window | Best Time to Buy/Sell Stock, Longest Substring Without Repeating, Minimum Window Substring |
| 4 | Stack | Valid Parentheses, Min Stack, Daily Temperatures, Generate Parentheses |
| 5 | Binary Search | Binary Search, Search in Rotated Sorted Array, Koko Eating Bananas |
| 6 | Linked List | Reverse Linked List, Linked List Cycle, Reorder List, LRU Cache |
| 7 | Trees | Invert Tree, Max Depth, LCA of BST, Level Order, Validate BST |
| 8 | Tries | Implement Trie, Word Search II |
| 9 | Heap | Kth Largest, Find Median from Data Stream |
| 10 | Backtracking | Subsets, Permutations, Combination Sum, Word Search |
| 11 | Graphs | Number of Islands, Max Area of Island, Pacific Atlantic, Course Schedule |
| 12 | Advanced Graphs | Network Delay Time, Min Cost to Connect Points |
| 13 | 1-D DP | Climbing Stairs, House Robber, Coin Change, LIS |
| 14 | 2-D DP | Unique Paths, LCS, Edit Distance |
| 15 | Greedy | Jump Game, Maximum Subarray |
| 16 | Intervals | Merge Intervals, Insert Interval, Meeting Rooms |
| 17 | Math & Geometry | Rotate Image, Spiral Matrix |
| 18 | Bit Manipulation | Single Number, Number of 1 Bits |

Particularidades de Swift: indexar `String` es costoso (convertir a `Array`); sin heap ni deque en la biblioteca estándar (`swift-collections` los tiene, pero suelen no permitirse en entrevistas); `Dictionary(default:)`, `reduce(into:)`, `inout`.

### 4.2 Entrevistas de iOS Engineer

Basado en guías de terceros (tendencia, no garantía):

- **Coding:** LeetCode de nivel medio; variantes móviles como caché LRU, image loader con cancelación, debounce/throttle, paginación.
- **Swift/plataforma:** ARC y ciclos; valor y referencia; GCD frente a async/await; actors y data races (donde más candidatos pierden puntos en los seguimientos); ciclo de vida de UIKit; `@State`, `@Observable`, `ObservableObject`; diffable.
- **Mobile system design:** feed, chat con imágenes, caché de imágenes, App Store, ticker de bolsa, sincronización offline-first. Marco: requisitos → API y comunicación → modelos → capas → offline, sync y conflictos → rendimiento, accesibilidad, privacidad y observabilidad. En Apple se describe como «on-device first».
- **Recursos de texto:** *Cracking the Mobile System Design Interview* (themobileinterview.com), mobiledesignrounds.com, repositorio weeeBox/mobile-system-design (no verificado), *App Architecture* (objc.io), *33 Engineering Challenges of Building Mobile Apps at Scale*.

## 5. Ejecución de Swift en el navegador

| Opción | Mantenimiento | Compila código del usuario en el cliente | Limitaciones |
| --- | --- | --- | --- |
| Swift SDK for Wasm | Activo; puente JavaScriptKit hasta 40 veces más rápido en 6.4 según swift.org | No | Sin UIKit/SwiftUI; Foundation parcial |
| JavaScriptKit + PackageToJS | Activo | No | Igual |
| carton | Archivado (29 nov 2025) | No | No usar |
| swiftc/LLVM a Wasm | Sin proyecto mantenido | En teoría | Cientos de MB (estimación) |
| MiniSwift | Proyecto personal (2026) | Sí, subconjunto | Semántica no garantizada |
| SwiftFiddle | Activo | No (servidor) | Dependencia externa, sin uso sin conexión |
| pad.swiftwasm.org | Comunidad | No | Igual |
| Godbolt | No verificado | No | Orientado a ensamblador |
| Runner en localhost | Propio | Compila en la Mac | Rompe «sin backend» en sentido estricto |

Recomendación adoptada: ejercicios con pruebas Swift Testing ejecutadas en Xcode o con `swift test`; sin portar el compilador ni depender de playgrounds de terceros.

## 6. Recomendaciones de stack (investigación)

| Decisión | Recomendación de la investigación | Decisión final |
| --- | --- | --- |
| Framework | Astro 6 + islas React | Vite 8 + React 19 (npm mostró Astro 7.x; se evitó depender de APIs no verificadas y la app es casi toda cliente) |
| Validación | Content collections + Zod 4 | Zod 4 con validador propio compartido por navegador, script y pruebas |
| Editor | CodeMirror 6 (`@codemirror/legacy-modes`, modo Swift) | Igual, cargado bajo demanda |
| Resaltado | Shiki en build | highlight.js en cliente (Swift, bash, JSON) |
| Búsqueda | Pagefind o MiniSearch | MiniSearch |
| Persistencia | IndexedDB con Dexie + exportación JSON | Igual |
| Repaso | ts-fsrs 6, fijar FSRS-6 o FSRS-7, guardar log completo | ts-fsrs 6 con FSRS-7 y tabla `revlog` |

## Riesgos y salvedades

- Verificación de URLs incompleta durante la investigación (resuelta después para los recursos registrados).
- Varios detalles de WWDC26 provienen de blogs o agregadores.
- No investigados: syllabi de Udemy y Coursera, Godbolt, mantenimiento de MiniSearch, FlexSearch, Pagefind, Fuse, Dexie y Shiki.
- Cifras de rendimiento de MiniSwift y JavaScriptKit declaradas por sus autores, no medidas de forma independiente.

## Fuentes principales

- Apple Developer Releases: https://developer.apple.com/news/releases/
- Swift 6.4 Released: https://www.swift.org/blog/swift-6.4-released/
- Transitioning to the UIKit scene-based life cycle: https://developer.apple.com/tutorials/data/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle.md
- TN3187: https://developer.apple.com/tutorials/data/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle.md
- NavigationView: https://developer.apple.com/tutorials/data/documentation/swiftui/navigationview.md
- ObservableObject: https://developer.apple.com/tutorials/data/documentation/combine/observableobject.md
- Upcoming requirements: https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- Xcode system requirements: https://developer.apple.com/xcode/system-requirements
- Swift y Wasm: https://www.swift.org/documentation/articles/wasm-getting-started.html
- Announcing Swift 6.3.3: https://forums.swift.org/t/announcing-swift-6-3-3/87888
- What's new in Swift, marzo 2026: https://www.swift.org/blog/whats-new-in-swift-march-2026/
- Xcode 27.2: https://developer.apple.com/news/releases/?id=10292026a
- Xcode 27: https://developer.apple.com/news/releases/?id=09142026h
- Submitting: https://developer.apple.com/app-store/submitting/
- Implementation status update: https://forums.swift.org/t/implementation-status-update-for-recent-language-and-library-proposals/89295
- WWDC26 SwiftUI guide: https://developer.apple.com/wwdc26/guides/swiftui/
- What is new in SwiftUI after WWDC26: https://swiftwithmajid.com/2026/06/08/what-is-new-in-swiftui-after-wwdc26/
- Develop in Swift: https://developer.apple.com/tutorials/develop-in-swift/welcome-to-develop-in-swift-tutorials
- CS193p 2025: https://9to5mac.com/2025/12/19/watch-stanford-university-2025-cs193p-ios-development-course/
- Hacking with Swift, Concurrency: https://www.hackingwithswift.com/quick-start/concurrency
- Kodeco, Modern Concurrency in Swift: https://www.kodeco.com/books/modern-concurrency-in-swift/v1.0/chapters/1-why-modern-swift-concurrency
- Swift Evolution: https://github.com/swiftlang/swift-evolution
- NeetCode 150: https://acehired.com/coding-interview/neetcode-150
- Apple mobile engineer interview: https://spacecomplexity.ai/blog/apple-mobile-engineer-interview
- Mobile design rounds: https://mobiledesignrounds.com/
- Cracking the Mobile System Design Interview: https://themobileinterview.com/cracking-the-mobile-system-design-interview/
- LiveCodes issue sobre Swift en Wasm: https://github.com/live-codes/livecodes/issues/351
- Swift SDKs for WebAssembly: https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405
- carton releases: https://github.com/swiftwasm/carton/releases
- MiniSwift: https://forums.swift.org/t/miniswift-swift-compiler-that-runs-in-the-browser-via-webassembly/85808
- SwiftFiddle: https://swiftfiddle.com/
- Astro 6: https://astro.build/blog/astro-6/
- CodeMirror legacy modes: https://github.com/codemirror/legacy-modes
- Lenguajes Swift y Kotlin para CodeMirror 6: https://discuss.codemirror.net/t/new-codemirror-6-language-packages-for-kotlin-and-swift/9882
