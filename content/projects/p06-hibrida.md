---
id: p06
number: 6
title: App híbrida UIKit y SwiftUI
summary: Una app UIKit existente que incorpora pantallas SwiftUI, y una pantalla SwiftUI que necesita un componente UIKit. El escenario más común en empresas con código heredado.
prerequisites: [m40]
objectives:
  - Integrar SwiftUI en una navegación UIKit con UIHostingController.
  - Envolver un componente UIKit con UIViewRepresentable y su coordinator.
  - Compartir estado entre ambos mundos sin duplicarlo.
requirements:
  - Parte del proyecto 3 o 4 y agrega una pantalla nueva en SwiftUI.
  - Integra un componente UIKit dentro de SwiftUI (por ejemplo, un UITextView con formato o un mapa).
  - Un modelo observable compartido por la pantalla UIKit y la SwiftUI.
acceptance:
  - La navegación funciona en ambos sentidos sin pantallas duplicadas.
  - El componente envuelto comunica cambios a SwiftUI mediante su coordinator.
  - No hay fugas de memoria al entrar y salir de las pantallas híbridas.
milestones:
  - id: p06-h1
    title: SwiftUI dentro de UIKit
    tasks: ["Presenta una vista SwiftUI con UIHostingController desde el coordinator existente."]
    concepts: [UIHostingController]
  - id: p06-h2
    title: UIKit dentro de SwiftUI
    tasks: ["Envuelve un componente con UIViewRepresentable y maneja sus eventos con un coordinator."]
    concepts: [UIViewRepresentable, Coordinators]
  - id: p06-h3
    title: Estado compartido
    tasks: ["Comparte un modelo observable entre ambas pantallas y verifica que los cambios se reflejan."]
    concepts: [Observation, Ciclos de vida híbridos]
---

## Cuándo tiene sentido

La interoperabilidad tiene sentido arquitectónico cuando migras de forma incremental o cuando un componente maduro de UIKit no tiene equivalente en SwiftUI. Documenta por qué elegiste cada integración.
