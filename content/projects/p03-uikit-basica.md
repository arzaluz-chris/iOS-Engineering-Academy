---
id: p03
number: 3
title: Primera app UIKit - lista de lectura
summary: Una app con varias pantallas para registrar libros por leer. Navegación, formularios, listas, validación, estado vacío y manejo de errores en UIKit con UI programática.
prerequisites: [m22, m23, m24, m25]
objectives:
  - Construir pantallas UIKit programáticas con Auto Layout.
  - Pasar datos entre pantallas y devolver resultados.
  - Diseñar estados vacíos y de error.
requirements:
  - Lista de libros con UICollectionView, diffable data source y layout de lista.
  - Pantalla para agregar un libro con validación de título obligatorio.
  - Pantalla de detalle con opción de marcar como leído.
  - Estado vacío con instrucción clara para agregar el primer libro.
  - Soporte de Dynamic Type y VoiceOver en todas las pantallas.
acceptance:
  - La app adopta el ciclo de vida por escenas.
  - Guardar sin título muestra un error junto al campo, no una alerta genérica.
  - Con el tamaño de texto más grande, ningún texto se corta.
  - Al cerrar el detalle, ningún view controller queda en memoria (verificado con Memory Graph).
milestones:
  - id: p03-h1
    title: Proyecto y escena
    tasks: ["Crea el proyecto con ciclo de vida por escenas y sin Storyboard principal.", "Configura la ventana con un UINavigationController."]
    concepts: [UIWindowScene, UIWindow]
  - id: p03-h2
    title: Lista con diffable data source
    tasks: ["Muestra libros de ejemplo con UICollectionView en modo lista.", "Agrega el estado vacío."]
    concepts: [Diffable data sources, Compositional layout]
  - id: p03-h3
    title: Formulario y validación
    tasks: ["Presenta el formulario de forma modal.", "Devuelve el libro creado con un delegate o un closure."]
    concepts: [Devolución de resultados, Validación]
  - id: p03-h4
    title: Detalle y accesibilidad
    tasks: ["Muestra el detalle con push.", "Revisa VoiceOver y Dynamic Type con Accessibility Inspector."]
    concepts: [Accesibilidad, Dynamic Type]
---

## Alcance

Sin red ni persistencia todavía: los datos viven en memoria. La persistencia llega en el proyecto 4. Concéntrate en una navegación limpia y en interfaces accesibles.
