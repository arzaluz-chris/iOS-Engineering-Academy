---
id: m03-l02
title: "Tu primer proyecto en Xcode: la ventana, compilar, ejecutar y el simulador"
description: Creas un proyecto de línea de comandos y uno de app para iOS, recorres las áreas de la ventana de Xcode, compilas, ejecutas, lees la consola y abres el simulador.
module: m03
order: 2
level: inicial
minutes: 45
prerequisites: [m03-l01]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Crear un proyecto de Xcode a partir de una plantilla, para la terminal y para iOS.
  - Identificar el navegador, el editor, los inspectores, el área de depuración y la barra de herramientas.
  - Distinguir proyecto, target, esquema y destino de ejecución.
  - Compilar y ejecutar un programa, y encontrar su salida en la consola.
  - Ejecutar una app en el simulador de iOS.
terms:
  - term: Proyecto
    definition: El archivo .xcodeproj que agrupa archivos fuente, recursos y configuración de compilación.
  - term: Target
    definition: Un producto que el proyecto construye, como una app o una herramienta de línea de comandos, con su propia lista de archivos y ajustes.
  - term: Esquema
    definition: Configuración que dice qué target compilar y cómo ejecutarlo, probarlo o analizarlo. Se elige en la barra de herramientas.
  - term: Destino de ejecución
    definition: Dónde se ejecuta el programa, por ejemplo «My Mac», un simulador de iPhone o un iPhone conectado.
  - term: Bundle identifier
    definition: Identificador único de una app en el sistema, normalmente con forma de dominio invertido, como com.tunombre.MiApp. Xcode lo forma con el identificador de organización y el nombre del producto.
  - term: Consola
    definition: Parte del área de depuración donde aparece lo que el programa imprime con print y los mensajes de error en ejecución.
mastery:
  - Crear desde cero un proyecto Command Line Tool, ejecutarlo y señalar en la consola su salida.
  - Crear un proyecto de app de iOS y ejecutarlo en un simulador elegido en el destino de ejecución.
  - Nombrar en voz alta las cinco áreas de la ventana de Xcode y para qué sirve cada una.
  - Explicar qué es un target y por qué un proyecto puede tener varios.
resources: [xcode-create-project, xcode-components, xcode-overview]
cards:
  - id: m03-l02-c1
    front: ¿Qué atajos compilan, ejecutan y detienen un programa en Xcode?
    back: "⌘B compila, ⌘R compila y ejecuta, ⌘. (Comando y punto) detiene la ejecución."
  - id: m03-l02-c2
    front: ¿Dónde aparece lo que imprime `print` en Xcode?
    back: "En la consola, dentro del área de depuración en la parte inferior. Se muestra u oculta con ⇧⌘Y."
  - id: m03-l02-c3
    front: ¿Qué diferencia hay entre proyecto y target?
    back: El proyecto agrupa archivos y configuración. Un target es un producto concreto que se construye a partir de él; un proyecto puede tener varios, por ejemplo la app y sus pruebas.
  - id: m03-l02-c4
    front: ¿Qué es el destino de ejecución?
    back: Dónde se ejecuta lo que compilas, por ejemplo «My Mac», un simulador de iPhone o un dispositivo físico. Se elige en la barra de herramientas, junto al esquema.
---

## La idea en una frase

Un proyecto de Xcode es una carpeta organizada con código y configuración; Xcode lo compila para un destino y te muestra lo que pasa en la consola.

> [!version]
> Los menús de esta lección siguen la documentación de Apple para las versiones recientes de Xcode. En versiones anteriores algunos nombres cambian; si algo no aparece donde se indica, consulta la documentación de tu versión.

## Primer proyecto: una herramienta de línea de comandos

Para los módulos de Swift esencial, la mayoría de los programas imprimen en la consola. La plantilla más directa es **Command Line Tool**, un programa para macOS sin interfaz gráfica.

1. En la ventana de bienvenida de Xcode, o desde *File → New → Project…*, elige crear un proyecto a partir de una plantilla (*Choose Template*).
2. Selecciona la plataforma **macOS** y la plantilla **Command Line Tool**.
3. Escribe un nombre de producto, por ejemplo `Practicas`. En **Organization Identifier** escribe algo con forma de dominio invertido, como `com.tunombre`. El lenguaje es **Swift**.
4. Elige una carpeta y crea el proyecto.

Xcode genera un archivo `main.swift` con un programa de ejemplo parecido a este. El encabezado de comentarios, con tu nombre y la fecha, varía:

```swift
//
//  main.swift
//  Practicas
//

import Foundation

print("Hello, World!")
```

```output
Hello, World!
```

Línea por línea:

1. Las líneas con `//` son comentarios. Xcode pone el nombre del archivo y del proyecto; el compilador los ignora.
2. `import Foundation` hace disponible el framework Foundation, con utilidades para fechas, texto y archivos. Este programa no lo necesita, pero la plantilla lo incluye.
3. `print("Hello, World!")` es la única instrucción que hace algo visible.

En un proyecto de línea de comandos, el código que escribes directamente en `main.swift`, fuera de funciones, se ejecuta de arriba hacia abajo cuando arranca el programa.

Presiona **⌘R** o el botón de ejecutar (▶) de la barra de herramientas. Xcode compila, ejecuta y muestra `Hello, World!` en la **consola**, en la parte inferior de la ventana.

## Las áreas de la ventana

| Área | Dónde | Para qué |
| --- | --- | --- |
| Barra de herramientas | Arriba | Ejecutar (▶) y detener (■), elegir esquema y destino, ver el estado de la compilación |
| Navegador | Izquierda | Ver los archivos del proyecto, los errores, los breakpoints, las búsquedas |
| Editor | Centro | Escribir código |
| Inspectores | Derecha | Propiedades del archivo o elemento seleccionado y ayuda rápida |
| Área de depuración | Abajo | Variables y consola mientras el programa corre |

Atajos que conviene memorizar desde el principio:

| Atajo | Acción |
| --- | --- |
| ⌘R | Compilar y ejecutar |
| ⌘B | Solo compilar |
| ⌘. | Detener la ejecución |
| ⇧⌘K | Limpiar la carpeta de compilación (*Clean Build Folder*) |
| ⇧⌘Y | Mostrar u ocultar el área de depuración |
| ⌘0 | Mostrar u ocultar el navegador |
| ⇧⌘O | *Open Quickly*: buscar un archivo o símbolo por nombre |

Si la consola no aparece después de ejecutar, presiona ⇧⌘Y.

## Proyecto, target, esquema y destino

Cuatro palabras que verás en cada proyecto:

- **Proyecto** (`Practicas.xcodeproj`): agrupa archivos y configuración.
- **Target**: un producto que se construye. Tu proyecto tiene un target, la herramienta `Practicas`. Una app real suele tener varios: la app, sus pruebas unitarias, sus pruebas de interfaz, tal vez un widget.
- **Esquema**: qué target se compila y cómo se ejecuta. Se elige en la barra de herramientas.
- **Destino de ejecución**: dónde corre, junto al esquema. Para una herramienta de macOS es *My Mac*; para una app de iOS, un simulador o un iPhone.

Compilar (⌘B) solo traduce y verifica. Ejecutar (⌘R) compila, si hace falta, y arranca el programa en el destino elegido.

## Segundo proyecto: una app de iOS en el simulador

1. Crea un proyecto nuevo con la plantilla **App** para **iOS**. La interfaz por defecto es SwiftUI, que estudiarás en su propia etapa; por ahora no cambies el código.
2. En el destino de ejecución, elige un iPhone simulado. Si no aparece ninguno, Xcode muestra un botón *Get* para descargar el runtime del simulador (lección anterior).
3. Presiona ⌘R. La primera vez el simulador tarda en arrancar.

La plantilla crea, entre otros, un archivo con el punto de entrada de la app, un archivo con la primera vista y un catálogo de recursos (`Assets`) para íconos, colores e imágenes. Verás la app en una ventana que imita un iPhone.

El simulador ejecuta tu app compilada para tu Mac, no para un iPhone real. Es rápido y cómodo, pero no reproduce todo: rendimiento, cámara, algunos sensores y ciertas funciones del sistema se comportan distinto. Antes de publicar una app hay que probarla en un dispositivo.

## Ejemplo práctico: tu archivo de prácticas

Reemplaza el contenido de `main.swift` del proyecto `Practicas` por:

```swift
print("Proyecto de prácticas")
print("Minutos en un día:")
print(24 * 60)
```

```output
Proyecto de prácticas
Minutos en un día:
1440
```

Ejecuta con ⌘R y compara la consola con la salida de arriba. Este proyecto te servirá para los ejercicios de las siguientes lecciones: cada vez, reemplazas el contenido de `main.swift`, ejecutas y comparas.

## Errores frecuentes

> [!error] La consola está vacía
> Puede estar oculta (⇧⌘Y), o el programa pudo no haberse ejecutado porque la compilación falló. Revisa el estado en la barra de herramientas y el navegador de problemas.

> [!error] Ejecutar el esquema equivocado
> Si tienes varios proyectos o targets, el botón ▶ ejecuta el esquema seleccionado en la barra de herramientas. Revisa que sea el que estás editando.

> [!error] No hay simuladores en el destino de ejecución
> Falta el runtime de iOS. Instálalo en *Xcode → Settings… → Components* o con el botón *Get* junto al destino.

> [!error] Borrar main.swift o moverlo fuera del target
> Si un archivo no pertenece al target, Xcode no lo compila. En el inspector de archivo, la sección *Target Membership* indica a qué targets pertenece.

````exercise
id: m03-l02-e1
type: comprension
prompt: Estás en Xcode con tu proyecto de línea de comandos abierto. ¿Qué hace ⌘B?
choices:
  - text: Compila el proyecto sin ejecutarlo.
    correct: true
    why: B de build. Traduce y verifica, pero no arranca el programa.
  - text: Compila y ejecuta el programa.
    correct: false
    why: Eso es ⌘R.
  - text: Detiene el programa que se está ejecutando.
    correct: false
    why: Eso es ⌘. (Comando y punto).
  - text: Muestra u oculta la consola.
    correct: false
    why: Eso es ⇧⌘Y.
solution: |
  **⌘B compila** sin ejecutar. Es útil para comprobar rápido que no hay errores de compilación. ⌘R compila si hace falta y además ejecuta; ⌘. detiene; ⇧⌘Y muestra u oculta el área de depuración, donde está la consola.
````

````exercise
id: m03-l02-e2
type: prediccion
prompt: Reemplazas `main.swift` por este código y presionas ⌘R. ¿Qué aparece en la consola?
code: |
  print("Segundos en una hora:")
  print(60 * 60)
  print("Horas en una semana:")
  print(24 * 7)
output: |
  Segundos en una hora:
  3600
  Horas en una semana:
  168
hints:
  - Las líneas se ejecutan de arriba hacia abajo.
solution: |
  ```output
  Segundos en una hora:
  3600
  Horas en una semana:
  168
  ```

  Cada `print` escribe una línea. Los textos entre comillas se imprimen tal cual; las multiplicaciones sin comillas se calculan: 60 × 60 = 3600 y 24 × 7 = 168.
````

````exercise
id: m03-l02-e3
type: comprension
multiple: true
prompt: Una app de iOS tiene en su proyecto la app, sus pruebas unitarias y un widget. ¿Cuáles de estas afirmaciones son correctas? Selecciona todas las que apliquen.
choices:
  - text: El proyecto tiene tres targets.
    correct: true
    why: Cada producto que se construye es un target.
  - text: Un archivo .swift puede pertenecer a más de un target.
    correct: true
    why: Se controla en Target Membership; por ejemplo, un modelo compartido entre la app y el widget.
  - text: Con un solo esquema se ejecutan los tres a la vez.
    correct: false
    why: Un esquema elige qué construir y cómo ejecutarlo; normalmente cada producto ejecutable tiene el suyo.
  - text: El destino de ejecución define en qué dispositivo o simulador corre lo que ejecutas.
    correct: true
    why: Se elige junto al esquema en la barra de herramientas.
solution: |
  El proyecto tiene **tres targets** (app, pruebas y widget). Un archivo puede pertenecer a varios targets mediante *Target Membership*. El **destino de ejecución** decide dónde corre. Un esquema no ejecuta los tres productos a la vez: elige un target para ejecutar y define cómo probarlo y analizarlo.
````

````exercise
id: m03-l02-e4
type: resolver
prompt: |
  Crea el proyecto `Practicas` con la plantilla Command Line Tool y escribe en `main.swift` un programa que imprima exactamente estas tres líneas, calculando los números con multiplicaciones:

  ```output
  Días en 3 semanas:
  21
  Minutos en 2 horas:
  120
  ```

  Ejecútalo con ⌘R y compara la consola con la salida pedida.
starter: |
  print("Días en 3 semanas:")
hints:
  - "Una semana tiene 7 días: 3 * 7."
  - "Una hora tiene 60 minutos: 2 * 60."
rubric:
  - Creé el proyecto con la plantilla Command Line Tool para macOS.
  - El programa imprime exactamente las cuatro líneas pedidas.
  - Los números se calculan con multiplicaciones, no están escritos a mano.
  - Encontré la salida en la consola del área de depuración.
solution: |
  ```swift
  print("Días en 3 semanas:")
  print(3 * 7)
  print("Minutos en 2 horas:")
  print(2 * 60)
  ```

  Si la consola no aparece, presiona ⇧⌘Y. Si aparece un error en lugar de la salida, la siguiente lección de este módulo enseña a leerlo; revisa primero comillas y paréntesis.
````

````exercise
id: m03-l02-e5
type: explicar
prompt: |
  Una compañera dice: «El simulador es igual que un iPhone, así que si mi app funciona en el simulador ya está lista para la App Store». Explica qué tiene de cierto y qué no.
rubric:
  - Expliqué que el simulador ejecuta la app compilada para la Mac, no para un iPhone.
  - Mencioné al menos dos diferencias, como rendimiento, cámara o sensores.
  - Dije que el simulador es útil para desarrollar rápido.
  - Concluí que hay que probar en un dispositivo real antes de publicar.
code: |
  Simulador = iPhone
solution: |
  Tiene de cierto que el simulador es una herramienta excelente para desarrollar: arranca rápido, permite probar varios modelos y versiones de iOS y muestra la interfaz casi igual que un iPhone.

  No es cierto que sea igual. El simulador ejecuta la app compilada **para la Mac**, con el procesador, la memoria y la red de la Mac. El rendimiento no es representativo, y la cámara, algunos sensores y ciertas funciones del sistema no se comportan como en un dispositivo. Antes de publicar, la app debe probarse en al menos un iPhone real.
````

## Resumen

- Command Line Tool es la plantilla más directa para practicar Swift en la consola; App es la de una app de iOS.
- Ventana de Xcode: barra de herramientas, navegador, editor, inspectores y área de depuración con la consola.
- Proyecto agrupa; target es un producto; esquema dice qué construir y cómo; destino dice dónde correr.
- ⌘B compila, ⌘R ejecuta, ⌘. detiene, ⇧⌘Y muestra la consola.
- El simulador sirve para desarrollar; las pruebas finales se hacen en un dispositivo.
