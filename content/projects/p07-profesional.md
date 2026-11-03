---
id: p07
number: 7
title: App profesional con calidad de producción
summary: Una app de finanzas personales con arquitectura definida, concurrencia estricta, persistencia, seguridad, accesibilidad, logging y CI.
prerequisites: [m41, m42, m43]
objectives:
  - Aplicar una arquitectura documentada con decisiones justificadas.
  - Compilar en modo Swift 6 sin advertencias de concurrencia.
  - Proteger datos sensibles según MASVS.
  - Automatizar validaciones en CI.
requirements:
  - Arquitectura documentada (por ejemplo, capas con repositorios y casos de uso solo donde aporten).
  - Configuración por entorno (desarrollo y producción) sin secretos en el repositorio.
  - Datos sensibles en Keychain y base local con Data Protection.
  - Logging con os.Logger sin datos personales.
  - Pruebas unitarias de dominio y datos, y al menos un UI test del flujo principal.
  - Workflow de CI que compila y ejecuta pruebas.
acceptance:
  - Compila en modo de lenguaje Swift 6 sin advertencias.
  - El análisis de un respaldo del dispositivo no revela montos ni tokens.
  - La app es usable con VoiceOver de principio a fin en el flujo principal.
  - CI falla si una prueba falla.
milestones:
  - id: p07-h1
    title: Arquitectura y decisiones
    tasks: ["Escribe un documento de decisiones de arquitectura con alternativas descartadas."]
    concepts: [Arquitectura, Trade-offs]
  - id: p07-h2
    title: Dominio, datos y concurrencia
    tasks: ["Implementa dominio y persistencia con aislamiento correcto de actores."]
    concepts: [Swift Concurrency, Persistencia]
  - id: p07-h3
    title: Seguridad
    tasks: ["Aplica la lista de verificación del módulo de desarrollo seguro."]
    concepts: [Keychain, Data Protection, Logging seguro]
  - id: p07-h4
    title: Accesibilidad y rendimiento
    tasks: ["Audita con Accessibility Inspector y perfila el arranque con Instruments."]
    concepts: [Accesibilidad, Instruments]
  - id: p07-h5
    title: CI
    tasks: ["Configura el workflow de compilación y pruebas."]
    concepts: [GitHub Actions]
---

## Nivel de exigencia

Este proyecto se evalúa como se revisaría un pull request en un equipo de banca: cada decisión debe poder defenderse. Usa la checklist de calidad de la etapa 12.
