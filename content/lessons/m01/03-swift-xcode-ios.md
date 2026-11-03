---
id: m01-l03
title: Aplicaciones, sistemas operativos y el ecosistema Swift, Xcode e iOS
description: Qué es una aplicación, qué hace el sistema operativo, qué significa frontend y backend, y cómo encajan Swift, Xcode, el SDK de iOS y el ciclo de desarrollo de una app.
module: m01
order: 3
level: inicial
minutes: 35
prerequisites: [m01-l02]
codeStatus: sin-codigo
objectives:
  - Explicar qué hace el sistema operativo por una aplicación.
  - Distinguir frontend, backend y sistema operativo en una app real.
  - Describir la relación entre Swift, Xcode, el SDK de iOS y el simulador.
  - Ordenar las etapas del ciclo de desarrollo de una app iOS.
terms:
  - term: Aplicación
    definition: Programa con un propósito para la persona usuaria, empaquetado para instalarse y ejecutarse en un sistema operativo.
  - term: Sistema operativo
    definition: Software que administra el hardware y ofrece servicios a las aplicaciones, como pantalla, red, archivos y permisos. En el iPhone es iOS.
  - term: Frontend
    definition: La parte de un sistema con la que interactúa la persona usuaria. En este curso, la app iOS.
  - term: Backend
    definition: Los servidores y servicios remotos que guardan datos compartidos y ejecutan la lógica que no debe vivir en el dispositivo.
  - term: IDE
    definition: Entorno de desarrollo integrado; reúne editor, compilador, depurador y otras herramientas. Para iOS es Xcode.
  - term: Terminal
    definition: Programa para dar órdenes a la computadora escribiendo comandos de texto.
  - term: SDK
    definition: Kit de desarrollo de software; conjunto de frameworks y herramientas para construir apps para una plataforma.
  - term: Framework
    definition: Biblioteca de código reutilizable con un propósito, como UIKit o SwiftUI para construir interfaces.
mastery:
  - Señalar, en una app bancaria que uses, qué ocurre en el frontend, qué en el backend y qué resuelve iOS.
  - Explicar qué aporta cada pieza entre Swift, Xcode, el SDK de iOS y el simulador.
  - Enumerar en orden las etapas desde escribir código hasta publicar una app.
resources: [xcode-overview, xcode-requirements, apple-documentation, develop-in-swift]
cards:
  - id: m01-l03-c1
    front: ¿Qué relación hay entre Swift, Xcode y el SDK de iOS?
    back: "Swift es el lenguaje. Xcode es el IDE que incluye el compilador, el depurador y el simulador. El SDK de iOS es el conjunto de frameworks (UIKit, SwiftUI, Foundation…) con los que tu código usa las capacidades del sistema."
  - id: m01-l03-c2
    front: En una app bancaria, ¿dónde se valida que tengas saldo para una transferencia?
    back: En el backend. La app puede verificar antes para dar una buena experiencia, pero la decisión que vale es la del servidor, porque el dispositivo no es confiable.
  - id: m01-l03-c3
    front: ¿Qué hace el sistema operativo por una aplicación?
    back: "Administra el hardware y le ofrece servicios: dibujar en pantalla, red, archivos, notificaciones, permisos y aislamiento entre apps (sandbox)."
---

## La idea en una frase

Una app iOS es un programa que vive dentro de iOS, usa los servicios del sistema a través de frameworks, suele hablar con un backend y se construye con Swift en Xcode.

## Qué hace el sistema operativo

Tu app no controla el hardware directamente. No enciende píxeles ni maneja la antena de red. Le pide esos servicios a **iOS**, el sistema operativo, que además decide qué puede y qué no puede hacer cada app.

Algunos servicios que iOS da a cualquier app:

- Dibujar en pantalla y entregar los toques de la persona usuaria.
- Acceso a red, archivos, cámara, ubicación y notificaciones.
- **Permisos**: la app pide, por ejemplo, acceso a la cámara, y la persona decide.
- **Aislamiento** (sandbox): cada app tiene su propio espacio de archivos y no puede leer los de otra.
- Ciclo de vida: iOS decide cuándo tu app pasa a segundo plano o se suspende para ahorrar batería.

Esta última idea es importante desde ya: en iOS, **tu app no es dueña de su propio ciclo de vida**. El sistema lo es. Lo estudiarás en detalle en la etapa de fundamentos de iOS.

## Frontend, backend y sistema operativo

Toma una app bancaria y una transferencia:

| Pieza | Qué hace en una transferencia |
| --- | --- |
| Frontend (la app iOS) | Muestra el formulario, valida que el monto tenga formato correcto, pide confirmación con Face ID y muestra el resultado. |
| Backend (servidores del banco) | Verifica identidad y saldo, aplica reglas antifraude, mueve el dinero y registra la operación. |
| Sistema operativo (iOS) | Dibuja la interfaz, ofrece Face ID, cifra la comunicación de red y guarda credenciales en el llavero (Keychain). |

Una regla que vas a escuchar en cualquier equipo de banca: **el cliente no es confiable**. La app puede validar para dar buena experiencia, pero toda decisión que importe se toma en el backend, porque un dispositivo puede estar comprometido.

## Swift, Xcode, el SDK y el simulador

Son piezas distintas que se usan juntas:

- **Swift** es el lenguaje: las reglas para escribir el código. Es de código abierto y también corre fuera de las plataformas de Apple, por ejemplo en Linux.
- **Xcode** es el IDE de Apple. Incluye el editor, el compilador de Swift, el depurador, el simulador e Instruments para medir rendimiento. Solo corre en macOS; cada versión exige una versión mínima de macOS y trae una versión concreta de Swift y del SDK.
- **El SDK de iOS** es el conjunto de frameworks que te deja usar lo que ofrece iOS: Foundation para tipos básicos y red, UIKit y SwiftUI para interfaces, y muchos más.
- **El simulador** ejecuta tu app en la Mac imitando un iPhone. Es rápido para desarrollar, pero no es idéntico a un dispositivo físico: algunas capacidades, como ciertos sensores, solo se prueban de verdad en un iPhone.

> [!version] Versiones vigentes al escribir esta lección (noviembre de 2026)
> Swift 6.4, Xcode 27 e iOS 27. Las versiones cambian cada año; la tabla oficial de requisitos de Xcode, enlazada al final, es la fuente que debes consultar.

Un detalle útil para no confundirte: **qué pertenece al lenguaje y qué al SDK**. `print`, `Int` y `Array` son parte de Swift y existen en cualquier plataforma. `UIViewController` o `NavigationStack` pertenecen a frameworks de Apple y solo existen donde ese SDK está disponible.

## La terminal

Además de Xcode, vas a usar la **terminal**: una ventana donde escribes comandos. Con ella clonarás repositorios con Git, crearás paquetes con `swift package init` y ejecutarás pruebas con `swift test`. Muchas tareas profesionales, como la integración continua, ocurren sin interfaz gráfica, así que conviene perderle el miedo pronto.

## El ciclo de desarrollo de una app

Las etapas, en orden:

1. **Definir** qué debe hacer la funcionalidad y cómo sabrás que está bien (criterios de aceptación).
2. **Escribir** el código en Xcode.
3. **Compilar**: el compilador traduce y revisa.
4. **Ejecutar** en el simulador o en un iPhone.
5. **Probar**: pruebas automatizadas y revisión manual.
6. **Depurar** lo que falle, con breakpoints y la consola.
7. **Firmar**: Apple exige que toda app instalada esté firmada con un certificado de desarrollador.
8. **Distribuir para pruebas** con TestFlight.
9. **Publicar** en App Store después de la revisión de Apple.

Los pasos 2 a 6 se repiten muchas veces al día. Los últimos tres ocurren cuando una versión está lista.

## Errores frecuentes

> [!error] Confundir Swift con iOS
> Swift es un lenguaje; iOS es un sistema operativo. Puedes escribir Swift en Linux sin iOS, y hay apps iOS escritas en otros lenguajes, como Objective-C.

> [!error] Confiar en el simulador para todo
> El simulador corre en la arquitectura de tu Mac y no reproduce todo el hardware. Antes de dar algo por terminado, pruébalo en un dispositivo físico.

> [!error] Tomar decisiones de seguridad en la app
> Si la app decide sola si una operación está permitida, alguien con un dispositivo modificado puede saltarse esa decisión. Las reglas que importan viven en el backend.

````exercise
id: m01-l03-e1
type: comprension
prompt: En una app de pagos, ¿quién debe decidir si el pago de 5,000 pesos procede?
choices:
  - text: La app, porque ya conoce el saldo que mostró en pantalla.
    correct: false
    why: El saldo en pantalla puede estar desactualizado, y la app corre en un dispositivo que puede estar manipulado.
  - text: El backend, con los datos y las reglas del banco.
    correct: true
    why: Es el único lugar confiable para decisiones que mueven dinero.
  - text: iOS, porque administra Face ID.
    correct: false
    why: iOS confirma la identidad de quien usa el dispositivo, pero no conoce las reglas ni el saldo del banco.
solution: |
  Decide el **backend**. La app puede verificar antes, para avisar rápido si falta saldo, pero esa verificación es solo de experiencia de usuario. La decisión válida ocurre en el servidor. iOS aporta la autenticación biométrica y el canal cifrado, no la regla de negocio.
````

````exercise
id: m01-l03-e2
type: comprension
multiple: true
prompt: ¿Cuáles de estas piezas son **parte del lenguaje Swift** y no de un framework de Apple? Selecciona todas.
choices:
  - text: "`print`"
    correct: true
    why: Es una función de la biblioteca estándar de Swift.
  - text: "`Int`"
    correct: true
    why: Es un tipo de la biblioteca estándar de Swift.
  - text: "`UIViewController`"
    correct: false
    why: Pertenece a UIKit, un framework del SDK de iOS.
  - text: "`NavigationStack`"
    correct: false
    why: Pertenece a SwiftUI, un framework de Apple.
solution: |
  `print` e `Int` pertenecen a la **biblioteca estándar de Swift** y existen en cualquier plataforma donde corra Swift, incluido Linux. `UIViewController` (UIKit) y `NavigationStack` (SwiftUI) pertenecen al **SDK de Apple** y solo existen en sus plataformas. Saber distinguirlos te ayuda a leer la documentación correcta y a entender qué código puedes probar fuera de un iPhone.
````

````exercise
id: m01-l03-e3
type: diseno
prompt: |
  Elige una funcionalidad de una app que uses a diario (por ejemplo, «ver mis movimientos del mes» en tu app bancaria) y describe:

  1. Qué hace el frontend.
  2. Qué hace el backend.
  3. Qué servicios de iOS intervienen.
  4. Un criterio de aceptación verificable para esa funcionalidad.
hints:
  - Piensa en qué datos necesitan guardarse en un servidor para que los veas desde otro dispositivo.
  - Un criterio de aceptación verificable dice qué debe pasar en una situación concreta, por ejemplo sin conexión.
rubric:
  - Separé con claridad lo que ocurre en el dispositivo y lo que ocurre en el servidor.
  - Mencioné al menos un servicio concreto de iOS (red, Keychain, notificaciones, biometría, etc.).
  - Ninguna decisión de seguridad o de dinero quedó solo en la app.
  - Mi criterio de aceptación se puede comprobar con un sí o un no.
solution: |
  Ejemplo con «ver mis movimientos del mes»:

  1. **Frontend**: pide los movimientos, muestra un estado de carga, presenta la lista agrupada por día, permite filtrar y muestra un mensaje claro si no hay conexión.
  2. **Backend**: autentica la sesión, consulta los movimientos de la cuenta, aplica permisos (solo las cuentas de esa persona) y responde con datos paginados.
  3. **iOS**: red cifrada (HTTPS con App Transport Security), Keychain para el token de sesión, Face ID si la app protege el acceso, y Dynamic Type para el tamaño de letra.
  4. **Criterio de aceptación**: «Sin conexión, la pantalla muestra los últimos movimientos guardados y un aviso con la hora de la última actualización; nunca una pantalla en blanco».
````

## Resumen

- iOS administra el hardware y el ciclo de vida de tu app; tu app pide servicios a través de frameworks.
- Frontend, backend y sistema operativo tienen responsabilidades distintas; las decisiones que importan van en el backend.
- Swift es el lenguaje, Xcode el IDE, el SDK los frameworks y el simulador una aproximación a un iPhone.
- El ciclo de desarrollo va de definir criterios de aceptación a publicar, con un bucle constante de escribir, compilar, probar y depurar.
