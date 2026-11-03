# Fase 1. Auditoría del repositorio

Fecha: 3 de noviembre de 2026.

## Hallazgos

| Aspecto | Estado encontrado |
| --- | --- |
| Repositorio | `arzaluz-chris/iOS-Engineering-Academy`, recién creado |
| Commits | Ninguno (rama `main` vacía) |
| Stack existente | Ninguno |
| Dependencias, scripts, tests, configuración | Ninguno |
| Convenciones o sistema de diseño previo | Ninguno |
| Visibilidad | Privado al inicio; cambiado a **público** durante la sesión (verificado con la API de GitHub) |
| GitHub Pages | Fuente configurada como **GitHub Actions** por el propietario |

Conclusión: no había nada que preservar ni migrar. El stack se eligió desde cero (ver `04-diseno-tecnico.md`).

## Restricciones identificadas en esta fase

- **Publicación en GitHub Pages:** sitio estático, sin servidor ni reescritura de rutas; el sitio vive bajo la subruta `/iOS-Engineering-Academy/`.
- **Costo de CI:** con el repositorio privado, los runners macOS consumían minutos con multiplicador de alrededor de 10x frente a Linux. Según la documentación de facturación de GitHub, los runners estándar son gratuitos en repositorios públicos. Al hacerse público, se habilitó un job macOS para `swift test` sin costo.
- **Entorno de construcción:** sin toolchain de Swift ni acceso de red a developer.apple.com o swift.org. Consecuencias: las pruebas Swift se delegan a CI en macOS y la verificación de enlaces a un workflow.
- **Pedido agregado durante la sesión:** módulo de código seguro, por su peso en entrevistas de banca. Se incorporó como Módulo 42 y categoría «Seguridad» del banco de entrevistas.
