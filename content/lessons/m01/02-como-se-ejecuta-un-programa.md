---
id: m01-l02
title: Del código fuente al programa que se ejecuta
description: Qué pasa entre que escribes una línea de Swift y que la computadora la ejecuta. Código fuente, compilador, código máquina y runtime, y por qué Swift detecta tantos errores antes de ejecutar.
module: m01
order: 2
level: inicial
minutes: 40
prerequisites: [m01-l01]
codeStatus: ilustrativo
swiftVersion: "6.4"
objectives:
  - Distinguir código fuente de código máquina.
  - Explicar qué hace un compilador y en qué se diferencia de un intérprete.
  - Clasificar un error como de compilación o de ejecución.
  - Describir qué es el runtime de un lenguaje.
terms:
  - term: Código fuente
    definition: El texto que escribes en un lenguaje de programación, legible para personas.
  - term: Código máquina
    definition: Instrucciones binarias que el procesador ejecuta directamente. Dependen de la arquitectura, por ejemplo arm64 en los iPhone y Mac con Apple silicon.
  - term: Compilador
    definition: Programa que traduce código fuente a código ejecutable y, en el camino, verifica reglas del lenguaje como los tipos.
  - term: Intérprete
    definition: Programa que lee el código fuente y lo ejecuta mientras lo lee, sin producir antes un ejecutable completo.
  - term: Runtime
    definition: Código de apoyo que acompaña al programa mientras se ejecuta, por ejemplo para administrar memoria.
  - term: Error de compilación
    definition: Problema que el compilador detecta antes de que el programa exista. El programa no se genera.
  - term: Error de ejecución
    definition: Problema que ocurre mientras el programa corre, como dividir entre cero con un valor calculado o acceder a una posición inexistente de una lista.
mastery:
  - Explicar en voz alta, en menos de un minuto, el camino de un archivo .swift hasta el procesador.
  - Clasificar errores comunes como de compilación o de ejecución y justificar la clasificación.
  - Decir qué ventaja concreta tiene que el compilador revise los tipos antes de ejecutar.
resources: [swift-book, swift-book-basics, swift-org]
cards:
  - id: m01-l02-c1
    front: ¿Qué hace un compilador?
    back: Traduce código fuente a código ejecutable y verifica las reglas del lenguaje (tipos, nombres, sintaxis) antes de que el programa exista.
  - id: m01-l02-c2
    front: Diferencia entre error de compilación y error de ejecución.
    back: El de compilación lo detecta el compilador y el programa no se genera. El de ejecución ocurre mientras el programa corre, con datos concretos.
  - id: m01-l02-c3
    front: ¿Qué es el runtime de Swift?
    back: Código de apoyo que acompaña al programa mientras se ejecuta; entre otras cosas participa en la administración de memoria por conteo de referencias (ARC).
---

## La idea en una frase

Tú escribes texto; el procesador solo entiende números. Entre ambos hay un traductor, el **compilador**, que además revisa tu trabajo antes de que exista el programa.

## Código fuente y código máquina

El **código fuente** es lo que escribes:

```swift
print("Hola")
```

El procesador de un iPhone no sabe qué es `print` ni qué es una palabra entre comillas. Ejecuta **código máquina**: instrucciones binarias muy elementales, como «carga este valor en un registro» o «salta a esta dirección». Cada familia de procesadores tiene su propio código máquina. Los iPhone actuales y las Mac con Apple silicon usan la arquitectura **arm64**.

Escribir directamente en código máquina es posible y casi nadie lo hace: es lento, propenso a errores y no se puede llevar a otra arquitectura. Los lenguajes de programación existen para escribir en un nivel que las personas entienden y dejar que una herramienta haga la traducción.

## Compilar o interpretar

Hay dos estrategias generales para ejecutar código fuente:

| Estrategia | Qué hace | Consecuencia |
| --- | --- | --- |
| Compilación anticipada | Traduce todo el programa a un ejecutable antes de correrlo. | Muchos errores se detectan antes de ejecutar; el programa resultante arranca rápido. |
| Interpretación | Un programa lee el código fuente y lo va ejecutando mientras avanza. | Puedes probar algo de inmediato, pero ciertos errores solo aparecen al llegar a esa línea. |

Swift es un lenguaje **compilado**. Cuando presionas Run en Xcode, el compilador de Swift (`swiftc`, construido sobre LLVM) traduce tu código a código máquina para el dispositivo de destino, y luego se ejecuta el resultado. La herramienta `swift` también permite correr un archivo directamente desde la terminal (`swift archivo.swift`); aun así, el código pasa por el compilador antes de ejecutarse.

La distinción compilado/interpretado describe implementaciones, no lenguajes de forma absoluta: hay lenguajes con ambas. Lo que importa para Swift es la consecuencia práctica: **el compilador revisa mucho antes de que el programa corra.**

## El compilador como primer revisor

Además de traducir, el compilador de Swift verifica reglas. Si escribes un nombre que no existe, si mezclas tipos incompatibles o si olvidas cerrar unas comillas, no obtienes un programa: obtienes un **error de compilación** con la línea y una explicación.

Esto es una ventaja enorme. Un error que el compilador detecta nunca llega a un usuario. Por eso, en Swift, leer y entender los mensajes del compilador es una habilidad central, y el Módulo 3 la practica a fondo.

Otros errores solo pueden descubrirse con datos concretos mientras el programa corre: dividir entre un número que resultó ser cero, pedir el elemento 10 de una lista que tiene 3. Esos son **errores de ejecución**. En Swift suelen detener el programa de inmediato, con un mensaje, en lugar de seguir con datos corruptos.

## El runtime

Un programa compilado no viaja solo. Lo acompaña un **runtime**: código de apoyo que se ejecuta junto con tu programa. El runtime de Swift participa, entre otras cosas, en administrar la memoria de los objetos mediante conteo de referencias (lo estudiarás como ARC en el Módulo 13). No escribes el runtime ni lo llamas directamente, pero conviene saber que existe: explica por qué ciertas tareas ocurren «solas» mientras tu programa corre.

## Ejemplo mínimo, línea por línea

```swift
print("Hola")
print(2 + 3)
```

- Línea 1: llama a la función `print` con el texto `"Hola"`. Imprime `Hola` y un salto de línea.
- Línea 2: el compilador ve que `2 + 3` es una suma de números enteros y la deja lista; al ejecutarse, se imprime `5`.

El programa se ejecuta de arriba hacia abajo: primero `Hola`, luego `5`.

## Errores frecuentes

> [!error] Pensar que si compila, funciona
> El compilador garantiza que el programa respeta las reglas del lenguaje, no que haga lo que querías. Un algoritmo equivocado compila sin problema.

> [!error] Ignorar las advertencias
> Una advertencia (warning) no detiene la compilación, pero casi siempre señala algo real: una variable que nunca usas, código que nunca se ejecuta. Trátalas como errores pequeños.

> [!error] Leer solo la primera palabra del mensaje
> Los mensajes del compilador de Swift suelen decir qué esperaba y qué encontró. Lee el mensaje completo y la línea señalada antes de cambiar nada.

````exercise
id: m01-l02-e1
type: comprension
multiple: true
prompt: ¿Cuáles de estos problemas detecta el compilador de Swift **antes** de que el programa se ejecute? Selecciona todos los que apliquen.
choices:
  - text: "Escribir `prnt(\"Hola\")` en lugar de `print(\"Hola\")`."
    correct: true
    why: El compilador no encuentra ninguna función llamada `prnt` y se niega a generar el programa.
  - text: "Olvidar cerrar las comillas de un texto."
    correct: true
    why: Es un error de sintaxis; el código no se puede traducir.
  - text: "Que el usuario escriba su edad como «veinte» cuando el programa espera un número."
    correct: false
    why: El compilador no conoce los datos que escribirá el usuario. Ese problema se maneja en ejecución, validando la entrada.
  - text: "Que el algoritmo calcule mal un descuento."
    correct: false
    why: Un algoritmo equivocado puede cumplir todas las reglas del lenguaje. Solo las pruebas lo revelan.
solution: |
  El compilador detecta lo que viola las **reglas del lenguaje**: nombres inexistentes y sintaxis rota. No puede detectar lo que depende de **datos en ejecución** (lo que escriba el usuario) ni lo que depende de **tu intención** (si el descuento debía ser 10 % o 15 %). Para eso existen la validación de entradas y las pruebas.
````

````exercise
id: m01-l02-e2
type: prediccion
prompt: Este programa compila sin errores. Escribe exactamente lo que imprime.
code: |
  print("Hola")
  print(2 + 3)
  print("2 + 3")
output: |
  Hola
  5
  2 + 3
solution: |
  ```output
  Hola
  5
  2 + 3
  ```

  La segunda línea imprime **5** porque `2 + 3` es una expresión numérica que se evalúa. La tercera imprime **2 + 3** literalmente, porque está entre comillas: es un texto, no una suma. La diferencia entre un valor y su representación como texto aparecerá todo el tiempo.
````

````exercise
id: m01-l02-e3
type: comprension
prompt: Una app se compila sin errores y, al usarla, se cierra cuando intenta leer el elemento número 10 de una lista que solo tiene 3. ¿Qué tipo de error es?
choices:
  - text: Error de compilación
    correct: false
    why: El compilador no sabe cuántos elementos tendrá la lista mientras la app corre.
  - text: Error de ejecución
    correct: true
    why: Ocurre con datos concretos mientras el programa corre.
  - text: Advertencia
    correct: false
    why: Una advertencia no cierra la app; aparece al compilar.
solution: |
  Es un **error de ejecución**. El tamaño de la lista se conoce solo cuando la app corre. Swift detiene el programa en lugar de leer memoria que no le pertenece, que es una decisión de seguridad deliberada. En módulos posteriores aprenderás a acceder a colecciones de forma segura para que esto no ocurra.
````

## Resumen

- El procesador ejecuta código máquina; tú escribes código fuente.
- Swift es compilado: el compilador traduce tu código y, antes, verifica las reglas del lenguaje.
- Los errores de compilación impiden que el programa exista; los de ejecución ocurren con datos concretos.
- El runtime acompaña al programa mientras corre y se encarga de tareas como la administración de memoria.
