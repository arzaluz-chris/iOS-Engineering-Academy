---
id: p04
number: 4
title: App UIKit con API pública
summary: Un catálogo que consume una API pública, con paginación, caché de imágenes, persistencia local y pruebas de la capa de datos.
prerequisites: [m30, m31, m32, m33]
objectives:
  - Construir un cliente HTTP con URLSession y async/await, separado de la interfaz.
  - Manejar estados de carga, error, vacío y paginación.
  - Probar la capa de datos con dobles de prueba.
requirements:
  - Elige una API pública gratuita y sin datos personales (por ejemplo, un catálogo de libros o de arte de un museo) y documenta su licencia de uso.
  - Lista paginada con carga al acercarse al final.
  - Caché de imágenes en memoria con cancelación al reutilizar celdas.
  - Persistencia local de los últimos resultados para mostrar sin conexión.
  - Pruebas del repositorio con un cliente de red falso.
acceptance:
  - Sin conexión se muestran los datos guardados y un aviso con la hora de la última actualización.
  - Un error de decodificación muestra un estado de error recuperable, no un cierre.
  - Ninguna imagen aparece en la celda equivocada al hacer scroll rápido.
  - Las pruebas de la capa de datos pasan sin red.
milestones:
  - id: p04-h1
    title: Cliente de red
    tasks: ["Define un protocolo de cliente HTTP y su implementación con URLSession.", "Modela errores de red, de estado HTTP y de decodificación."]
    concepts: [URLSession, Codable, Manejo de errores]
  - id: p04-h2
    title: Repositorio y estados
    tasks: ["Expón estados de carga, datos, vacío y error.", "Implementa paginación por cursor o página según la API."]
    concepts: [Repository pattern, Paginación]
  - id: p04-h3
    title: Imágenes y rendimiento
    tasks: ["Implementa caché de imágenes y cancelación en prepareForReuse."]
    concepts: [Caché, Reutilización de celdas]
  - id: p04-h4
    title: Persistencia y modo sin conexión
    tasks: ["Guarda la última página con SwiftData o Core Data.", "Muestra datos locales primero y actualiza desde red."]
    concepts: [Persistencia, Offline-first]
  - id: p04-h5
    title: Pruebas
    tasks: ["Prueba el repositorio con un cliente falso: éxito, error, vacío y paginación."]
    concepts: [Test doubles, Tests asíncronos]
---

## Elección de la API

Prefiere APIs con documentación estable y sin clave, o con clave gratuita. Nunca pongas una clave secreta en el código de la app: cualquier persona puede extraerla del binario. Si la API exige clave, documenta el riesgo y usa una de solo lectura.
