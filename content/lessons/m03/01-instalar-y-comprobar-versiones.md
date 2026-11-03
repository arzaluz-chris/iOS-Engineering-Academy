---
id: m03-l01
title: "Instalar Xcode y comprobar qué versiones tienes"
description: Qué incluye Xcode, cómo instalarlo, cómo saber con certeza qué versión de Xcode y de Swift tienes y cómo leer la tabla oficial de requisitos. Sin suposiciones sobre tu máquina.
module: m03
order: 1
level: inicial
minutes: 35
prerequisites: [m01-l03]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Enumerar qué incluye Xcode y qué son las Command Line Tools.
  - Instalar Xcode y los componentes de simulador que necesitas.
  - Comprobar desde la terminal qué versión de Xcode y de Swift está activa.
  - Consultar la tabla oficial de requisitos para saber qué macOS, SDK y deployment targets corresponden a una versión de Xcode.
terms:
  - term: Xcode
    definition: El entorno de desarrollo de Apple. Incluye editor, compilador de Swift, SDKs, simulador, depurador e Instruments.
  - term: Command Line Tools
    definition: Paquete de herramientas de línea de comandos de Apple (compiladores, git, etc.) que también existe sin Xcode completo. No incluye el simulador ni el editor.
  - term: SDK
    definition: Conjunto de frameworks y herramientas para compilar para una plataforma y versión concretas, como el SDK de iOS 27.2.
  - term: Runtime de simulador
    definition: La imagen del sistema operativo que ejecuta el simulador, por ejemplo iOS 27.2. Se descarga por separado de Xcode.
  - term: Deployment target
    definition: La versión mínima del sistema operativo en la que tu app puede instalarse.
  - term: Versión de compilador y modo de lenguaje
    definition: El compilador de Swift 6.x puede compilar código en modo Swift 5 o Swift 6. La versión del compilador y el modo de lenguaje son cosas distintas.
mastery:
  - Ejecutar xcodebuild -version, swift --version y xcode-select -p e interpretar lo que muestra cada uno.
  - Decir, consultando la tabla oficial, qué versión de macOS necesita una versión dada de Xcode y qué versión de Swift incluye.
  - Instalar un runtime de simulador de iOS desde los ajustes de Xcode.
  - Explicar por qué una lección que dice «Swift 6.4» puede seguir funcionando con un compilador 6.3, y cuándo no.
resources: [xcode-requirements, xcode-overview, xcode-components, swift-install]
cards:
  - id: m03-l01-c1
    front: ¿Con qué comando ves qué versión de Xcode está activa?
    back: "`xcodebuild -version`. Muestra la versión de Xcode y su número de build."
  - id: m03-l01-c2
    front: ¿Qué muestra `xcode-select -p`?
    back: La carpeta de herramientas de desarrollo activa. Si apunta a las Command Line Tools y no a Xcode.app, los comandos usarán esas herramientas y no las de Xcode.
  - id: m03-l01-c3
    front: ¿Dónde consultas qué macOS necesita una versión de Xcode y qué Swift incluye?
    back: En la página oficial Xcode system requirements de Apple Developer.
  - id: m03-l01-c4
    front: ¿Qué diferencia hay entre la versión del compilador de Swift y el modo de lenguaje?
    back: "La versión del compilador es la herramienta instalada (por ejemplo, 6.4.2). El modo de lenguaje (Swift 5 o Swift 6) es el conjunto de reglas con el que compila tu código; un compilador 6.x acepta ambos."
---

## La idea en una frase

Antes de escribir código necesitas saber **qué herramientas tienes exactamente**, porque la respuesta a «¿por qué no compila?» a veces es «porque tu versión no tiene eso».

## Qué incluye Xcode

Xcode no es solo un editor. Es un paquete que reúne todo lo necesario para crear apps para plataformas de Apple:

| Pieza | Para qué sirve |
| --- | --- |
| Editor de código | Escribir y navegar tu proyecto |
| Compilador de Swift | Traducir tu código, como viste en la lección «Del código fuente al programa» |
| SDKs | Los frameworks de iOS, macOS y demás plataformas |
| Simulador | Ejecutar apps de iOS en tu Mac sin un iPhone |
| Depurador (LLDB) | Pausar un programa e inspeccionar sus valores |
| Instruments | Medir rendimiento, memoria y energía |

Existe además un paquete más pequeño, las **Command Line Tools**, con compiladores y herramientas de terminal pero sin editor ni simulador. Algunas herramientas te ofrecerán instalarlas. Para este curso necesitas **Xcode completo**.

## Versiones vigentes al escribir esta lección

La investigación del curso, verificada en noviembre de 2026, registró:

| Componente | Versión | Fecha |
| --- | --- | --- |
| Xcode | 27.2 (build 27B52) | 29 de octubre de 2026 |
| Swift incluido en Xcode 27.2 | 6.4.2 | 30 de octubre de 2026 (anuncio) |
| SDK de iOS | 27.2 | 26 de octubre de 2026 |
| macOS mínimo para Xcode 27.2 | macOS Tahoe 26.6 | — |
| Procesador | Xcode 27.2 solo corre en Mac con Apple silicon | — |
| Deployment targets de iOS que admite Xcode 27 | iOS 15 a iOS 27 | — |

> [!version]
> Estas cifras envejecen. La fuente que manda es la tabla oficial **Xcode system requirements** de Apple, enlazada en los recursos de esta lección. Ahí aparece, para cada versión de Xcode, el macOS mínimo, la versión de Swift incluida, los SDK y los deployment targets.

El curso no supone qué versión tienes instalada. La comprobarás tú en un momento.

## Instalar Xcode

1. Revisa en la tabla oficial qué versión de Xcode admite tu versión de macOS. Si tu Mac no puede correr la versión más reciente, instala la más reciente que sí admita.
2. Instala Xcode desde la **Mac App Store** o, con tu cuenta de Apple, desde la página de descargas de Apple Developer, que también ofrece versiones anteriores.
3. Abre Xcode una vez. La primera vez puede pedirte permiso para instalar componentes adicionales.
4. Instala el **runtime del simulador de iOS**. Según la documentación de Apple, se administra en *Xcode → Settings… → Components*; si abres un proyecto para una plataforma sin runtime instalado, Xcode también muestra un botón *Get* junto al destino de ejecución.

La descarga de Xcode pesa varios gigabytes, y cada runtime de simulador también. Asegúrate de tener espacio en disco.

## Comprobar tus versiones

Abre la app **Terminal** y ejecuta estos tres comandos, uno a la vez.

```bash
xcodebuild -version
```

Muestra la versión de Xcode activa y su número de build, en dos líneas. Con Xcode 27.2, por ejemplo, la primera línea diría `Xcode 27.2` y la segunda `Build version 27B52`. **Lo que importa es lo que muestre tu terminal**, no este ejemplo.

```bash
swift --version
```

Muestra la versión del compilador de Swift activo. En macOS aparece como `Apple Swift version …` seguida de detalles de compilación y la arquitectura (por ejemplo `arm64-apple-macosx…`). La versión de Swift que trae cada Xcode está en la tabla oficial.

```bash
xcode-select -p
```

Muestra qué carpeta de herramientas está activa. Lo normal, con Xcode instalado en Aplicaciones, es:

```plaintext
/Applications/Xcode.app/Contents/Developer
```

Si en cambio muestra `/Library/Developer/CommandLineTools`, tu terminal está usando las Command Line Tools y no Xcode. `xcodebuild` puede fallar con un mensaje que dice que requiere Xcode. Para seleccionar Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

`sudo` pide tu contraseña de usuario porque el cambio afecta a todo el sistema.

### Comprobar desde un programa

También puedes preguntarle al compilador su versión desde el código. Guarda esto en `version.swift` y ejecútalo con `swift version.swift`:

```swift
#if compiler(>=6.0)
print("Tu compilador es Swift 6 o posterior.")
#else
print("Tu compilador es anterior a Swift 6. Actualiza Xcode.")
#endif
```

```output
Tu compilador es Swift 6 o posterior.
```

Línea por línea:

1. `#if compiler(>=6.0)` es una **condición de compilación**: el compilador la evalúa antes de generar el programa y solo compila una de las dos ramas.
2. Si tu compilador es 6.0 o posterior, se compila esta línea.
3. `#else` introduce la rama alternativa.
4. Con un compilador anterior, se compilaría esta otra línea.
5. `#endif` cierra la condición.

No necesitas escribir esto en tus programas. Sirve para ver que la versión del compilador es un dato concreto que el propio compilador conoce.

## Versión del compilador y modo de lenguaje

Dos números se confunden con frecuencia:

- **Versión del compilador**: la herramienta instalada. Con Xcode 27.2, Swift 6.4.2.
- **Modo de lenguaje**: las reglas con las que se compila tu código, Swift 5 o Swift 6. El modo Swift 6 activa, entre otras cosas, la verificación estricta de concurrencia, que estudiarás mucho más adelante.

Un compilador 6.x puede compilar proyectos en modo Swift 5 o Swift 6. Por eso un proyecto antiguo puede abrirse en un Xcode nuevo sin reescribirse.

Las lecciones del curso indican la versión de Swift con la que se escribieron (6.4). El código de las primeras etapas usa solo características que existen desde mucho antes, y las pruebas automáticas del curso lo ejecutan con Swift 6.3. Cuando una lección use algo exclusivo de una versión, lo dirá con un aviso de disponibilidad.

## Errores frecuentes

> [!error] xcode-select: error: tool 'xcodebuild' requires Xcode
> La terminal está usando las Command Line Tools. Instala Xcode completo y selecciónalo con `sudo xcode-select -s /Applications/Xcode.app`.

> [!error] Seguir un tutorial escrito para otra versión
> Menús, plantillas y nombres cambian entre versiones de Xcode. Si algo no aparece donde el tutorial dice, comprueba tu versión con `xcodebuild -version` y busca la documentación de esa versión.

> [!error] Confundir la versión de iOS del simulador con la de tu iPhone
> El simulador ejecuta el runtime que instalaste en Xcode, no la versión de tu teléfono. Puedes tener varios runtimes a la vez.

> [!error] Instalar un Xcode que tu macOS no admite
> La Mac App Store normalmente ofrece la versión más reciente. Si tu macOS no la admite, consulta la tabla oficial y descarga la versión adecuada desde Apple Developer.

````exercise
id: m03-l01-e1
type: comprension
prompt: Ejecutas `xcode-select -p` y la terminal muestra `/Library/Developer/CommandLineTools`. ¿Qué significa?
choices:
  - text: Xcode está bien configurado.
    correct: false
    why: Con Xcode activo, la ruta estaría dentro de Xcode.app.
  - text: La terminal está usando las Command Line Tools y no Xcode.
    correct: true
    why: Esa carpeta es la de las Command Line Tools independientes.
  - text: Xcode no puede instalarse en esta Mac.
    correct: false
    why: La ruta solo dice qué herramientas están activas, no qué se puede instalar.
  - text: Swift no está instalado.
    correct: false
    why: Las Command Line Tools incluyen un compilador de Swift.
solution: |
  La terminal está usando las **Command Line Tools**. Sirven para compilar desde la terminal, pero no incluyen simulador ni editor, y `xcodebuild` necesita Xcode completo. Si ya instalaste Xcode, selecciónalo:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  ```

  Después `xcode-select -p` debería mostrar `/Applications/Xcode.app/Contents/Developer`.
````

````exercise
id: m03-l01-e2
type: prediccion
prompt: Guardas este código en `hola.swift` y lo ejecutas con `swift hola.swift`. Escribe exactamente lo que aparece en la terminal.
code: |
  print("Comprobando el entorno")
  print(6 * 7)
  print("6 * 7")
  print(10 - 2 - 3)
output: |
  Comprobando el entorno
  42
  6 * 7
  5
hints:
  - Lo que está entre comillas es texto y se imprime tal cual.
  - "Sin comillas, 6 * 7 es una multiplicación que se calcula."
solution: |
  ```output
  Comprobando el entorno
  42
  6 * 7
  5
  ```

  1. Imprime el texto y un salto de línea.
  2. `6 * 7` sin comillas es una expresión: se calcula y se imprime **42**. En Swift, `*` es la multiplicación.
  3. Con comillas es un texto: se imprime `6 * 7` literalmente, como viste en la lección «Del código fuente al programa».
  4. Las restas se hacen de izquierda a derecha: (10 − 2) − 3 = **5**.

  Si ves exactamente esto, tu compilador de Swift funciona desde la terminal.
````

````exercise
id: m03-l01-e3
type: resolver
prompt: |
  Comprueba tu propio entorno y registra el resultado. Ejecuta en la terminal `xcodebuild -version`, `swift --version` y `xcode-select -p`. Después, en la tabla oficial **Xcode system requirements**, busca la fila de tu versión de Xcode.

  Escribe en tus notas: tu versión y build de Xcode, tu versión de Swift, la ruta activa, el macOS mínimo que pide tu Xcode y el rango de deployment targets de iOS que admite.
starter: |
  Xcode:
  Build:
  Swift:
  Ruta activa:
  macOS mínimo (tabla oficial):
  Deployment targets de iOS (tabla oficial):
hints:
  - Si xcodebuild falla, revisa primero la ruta de xcode-select -p.
  - La tabla oficial está en los recursos de esta lección.
rubric:
  - Copié las salidas reales de mi terminal, sin redondear versiones.
  - La ruta activa apunta a Xcode.app; si no, la corregí con xcode-select -s.
  - Encontré mi versión de Xcode en la tabla oficial y anoté macOS mínimo y deployment targets.
  - Comparé mi versión con la de la lección y anoté si es más nueva, igual o más antigua.
solution: |
  No hay una única respuesta correcta: depende de tu Mac. Una respuesta completa tiene esta forma (los valores son los de Xcode 27.2 según la investigación del curso; los tuyos pueden ser otros):

  ```plaintext
  Xcode: 27.2
  Build: 27B52
  Swift: 6.4.2
  Ruta activa: /Applications/Xcode.app/Contents/Developer
  macOS mínimo (tabla oficial): macOS Tahoe 26.6
  Deployment targets de iOS (tabla oficial): iOS 15 a 27
  ```

  Si tu Xcode es más antiguo, todo el código de las primeras etapas funcionará igual. Si una lección usa algo de una versión más reciente, lo marcará con un aviso de disponibilidad. Guarda estas notas: cuando algo no compile como dice un tutorial, tu versión será lo primero que revises.
````

````exercise
id: m03-l01-e4
type: comprension
prompt: |
  Una lección dice «escrita con Swift 6.4». Tu `swift --version` muestra una versión 6.3. ¿Qué es lo más correcto?
choices:
  - text: No podrás ejecutar nada de la lección.
    correct: false
    why: La mayoría del lenguaje existe desde versiones anteriores.
  - text: Puedes seguirla; solo fallará lo que use algo exclusivo de 6.4, y la lección lo marcaría con un aviso.
    correct: true
    why: La versión indica con qué se escribió, no que todo requiera esa versión.
  - text: Debes cambiar el modo de lenguaje a Swift 5.
    correct: false
    why: El modo de lenguaje no tiene que ver con las características nuevas de 6.4.
  - text: Las versiones 6.3 y 6.4 son idénticas.
    correct: false
    why: Cada versión agrega características; la investigación del curso enumera las de 6.4.
solution: |
  Puedes seguir la lección. La versión indica con qué se escribió y verificó, no que cada línea requiera esa versión. Lo exclusivo de una versión se marca con un aviso de disponibilidad. Las pruebas automáticas de este curso ejecutan los ejemplos de las primeras etapas con Swift 6.3 precisamente para comprobarlo.
````

## Resumen

- Xcode incluye editor, compilador, SDKs, simulador, depurador e Instruments; las Command Line Tools son solo una parte.
- `xcodebuild -version`, `swift --version` y `xcode-select -p` dicen exactamente qué tienes activo.
- La tabla oficial Xcode system requirements es la fuente para macOS mínimo, Swift incluido, SDK y deployment targets.
- Los runtimes de simulador se instalan aparte, en *Xcode → Settings… → Components*.
- La versión del compilador y el modo de lenguaje son cosas distintas.
