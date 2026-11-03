---
id: p05
number: 5
title: La misma app en SwiftUI
summary: Reimplementa el catálogo del proyecto 4 con SwiftUI y Observation, reutilizando la capa de datos. Identifica qué cambia y qué principios se conservan.
prerequisites: [m36, m37]
objectives:
  - Reutilizar dominio y datos sin cambios al cambiar de framework de interfaz.
  - Ubicar el estado en el dueño correcto con Observation.
  - Navegar por valores con NavigationStack.
requirements:
  - Las mismas funcionalidades del proyecto 4.
  - Modelos con @Observable y estado local con @State.
  - Navegación con NavigationStack y NavigationPath.
  - Un documento corto que compare ambas implementaciones.
acceptance:
  - La capa de datos del proyecto 4 se usa sin modificaciones.
  - El documento comparativo explica al menos tres diferencias y tres principios que se conservan.
  - Las vistas no realizan llamadas de red directamente.
milestones:
  - id: p05-h1
    title: Reutilizar la capa de datos
    tasks: ["Extrae dominio y datos del proyecto 4 a un Swift Package local."]
    concepts: [Modularización]
  - id: p05-h2
    title: Lista y detalle
    tasks: ["Construye la lista con List o LazyVStack y la navegación por valores."]
    concepts: [NavigationStack, Observation]
  - id: p05-h3
    title: Estados y paginación
    tasks: ["Implementa carga, error, vacío y paginación con task y refreshable."]
    concepts: [task, refreshable]
  - id: p05-h4
    title: Comparación
    tasks: ["Escribe el documento comparativo."]
    concepts: [Arquitectura]
---

## Qué observar

La capa de datos no debería cambiar en absoluto. Si tienes que modificarla para SwiftUI, había dependencias de UIKit donde no correspondía: esa es la lección más valiosa del proyecto.
