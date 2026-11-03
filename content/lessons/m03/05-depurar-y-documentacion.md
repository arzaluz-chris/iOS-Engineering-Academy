---
id: m03-l05
title: "Depurar con breakpoints y encontrar respuestas en la documentación"
description: Pausas un programa con breakpoints, avanzas línea por línea, inspeccionas valores en el visor de variables y en la consola de LLDB, y aprendes a leer una página de la documentación oficial.
module: m03
order: 5
level: inicial
minutes: 50
prerequisites: [m03-l04, m02-l04]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Poner, desactivar y quitar breakpoints en Xcode.
  - Avanzar por el código con Continue, Step Over, Step Into y Step Out.
  - Inspeccionar valores con el visor de variables y con los comandos v, p y po de la consola.
  - Abrir la documentación de un símbolo desde Xcode y leer su declaración, descripción y parámetros.
terms:
  - term: Depurador
    definition: Herramienta que ejecuta un programa bajo control, permite pausarlo y muestra sus valores. Xcode usa LLDB.
  - term: Breakpoint
    definition: Marca en una línea donde el depurador pausa el programa antes de ejecutarla.
  - term: Step Over
    definition: Ejecuta la línea actual completa y se detiene en la siguiente, sin entrar a las funciones que llame.
  - term: Step Into
    definition: Si la línea actual llama a una función, entra en ella y se detiene en su primera línea.
  - term: Step Out
    definition: Termina la función actual y se detiene en la línea que la llamó.
  - term: Visor de variables
    definition: Parte del área de depuración que muestra los valores de las variables en el punto donde el programa está pausado.
  - term: Declaración
    definition: La firma de un símbolo en la documentación, por ejemplo los parámetros que recibe una función y sus valores predeterminados.
mastery:
  - Encontrar con un breakpoint y Step Over la línea en la que un acumulador deja de tener el valor esperado.
  - Usar v para ver una variable y p para evaluar una expresión en la consola de LLDB.
  - Abrir la documentación de print desde Xcode y explicar qué significan sus valores predeterminados.
  - Explicar en qué se parece depurar a llenar una tabla de seguimiento.
resources: [xcode-breakpoints, xcode-stepping, lldb-tutorial, apple-documentation, swift-print]
cards:
  - id: m03-l05-c1
    front: ¿Cuándo se detiene el programa en un breakpoint?
    back: Antes de ejecutar la línea marcada. Los valores que ves son los de justo antes de esa línea.
  - id: m03-l05-c2
    front: ¿Qué diferencia hay entre Step Over y Step Into?
    back: Step Over ejecuta la línea completa y se detiene en la siguiente. Step Into, si la línea llama a una función, entra en ella.
  - id: m03-l05-c3
    front: ¿Qué hacen `v`, `p` y `po` en la consola de LLDB?
    back: v (frame variable) muestra variables tal como están en memoria. p evalúa una expresión y muestra el resultado. po evalúa y muestra la descripción del objeto.
  - id: m03-l05-c4
    front: ¿Cómo ves la documentación de un símbolo sin salir del editor de Xcode?
    back: "Con Option (⌥) y clic sobre el símbolo aparece la ayuda rápida (Quick Help). La documentación completa se abre desde Help › Developer Documentation."
---

## La idea en una frase

El depurador es una tabla de seguimiento automática: pausa el programa donde le digas y te muestra los valores reales, para que compares con los que esperabas.

## Por qué depurar en lugar de adivinar

En la lección de tablas de seguimiento encontraste errores comparando, fila por fila, los valores esperados con los que producía el algoritmo. El depurador hace lo mismo con el programa real: en lugar de calcular cada valor a mano, lo pausas y lo lees.

Agregar `print` por todos lados también funciona, y a veces es lo más rápido. Pero el depurador no obliga a modificar el código, deja ver todos los valores a la vez y permite avanzar de una línea a la siguiente.

## Un programa con un error

Este programa debería sumar tres precios. Todavía no conoces `var` ni `for`; los estudiarás en los módulos 4 y 5. Para esta lección basta saber que `total` guarda un número que cambia, y que el bloque entre llaves se repite una vez por cada precio.

```swift
var total = 0
for precio in [120, 80, 45] {
    total = precio
}
print("Total:", total)
```

```output
Total: 45
```

Esperábamos 245. Vamos a encontrar dónde se pierde el valor sin adivinar.

## Breakpoints

1. Pega el programa en `main.swift` de tu proyecto `Practicas`.
2. Haz clic en el **número de la línea 3**, `total = precio`, en el margen izquierdo del editor. Aparece una flecha azul: es el **breakpoint**. Con el cursor en la línea, ⌘\ hace lo mismo.
3. Ejecuta con ⌘R.

El programa se pausa **antes** de ejecutar la línea 3. Xcode resalta la línea y abre el área de depuración con dos partes: a la izquierda el **visor de variables**, a la derecha la **consola**.

Para administrar breakpoints, según la documentación de Apple:

- Arrastra un breakpoint fuera del margen para quitarlo.
- Haz clic en él para desactivarlo sin quitarlo; queda más tenue.
- El botón de breakpoints de la barra de depuración activa o desactiva todos.
- El navegador de breakpoints, a la izquierda, los lista todos.

## Avanzar línea por línea

La barra de depuración, sobre la consola, tiene los botones de control. Sus atajos predeterminados aparecen al pasar el puntero sobre cada botón.

| Botón | Qué hace |
| --- | --- |
| Continue | Sigue hasta el próximo breakpoint o hasta el final |
| Step Over | Ejecuta la línea actual y se detiene en la siguiente |
| Step Into | Si la línea llama a una función, entra en ella |
| Step Out | Termina la función actual y vuelve a quien la llamó |

Con el programa pausado en la línea 3, observa el visor de variables:

| Pausa | precio | total antes de la línea 3 |
| --- | --- | --- |
| 1 | 120 | 0 |
| 2 | 80 | 120 |
| 3 | 45 | 80 |

Presiona **Continue** para llegar a cada pausa. En la segunda ya se ve el problema: `total` vale 120, pero en la tercera vale 80, no 200. La línea 3 **reemplaza** el total en lugar de **sumarle** el precio. Es el mismo error del acumulador que encontraste a mano en la lección de tablas de seguimiento.

La corrección es acumular:

```swift
var total = 0
for precio in [120, 80, 45] {
    total = total + precio
}
print("Total:", total)
```

```output
Total: 245
```

## La consola de LLDB

Mientras el programa está pausado, la consola acepta comandos del depurador. Los tres más útiles, según la documentación de Xcode:

```plaintext
(lldb) v total
(lldb) p total + precio
(lldb) po total
```

1. `v total` (abreviatura de `frame variable`) muestra la variable tal como está en memoria. Es rápido y no ejecuta código.
2. `p total + precio` (abreviatura de `expression`) **evalúa** una expresión. Sirve para probar una hipótesis, como «¿qué valdría si sumara?», sin cambiar el programa.
3. `po total` evalúa y muestra la descripción del valor. Con objetos complejos suele ser más legible que `p`.

Si `p` o `po` dan un error con alguna variable, prueba `v`: no compila código, solo lee memoria.

## Ejemplo práctico: un breakpoint condicional

Si el error aparece en la vuelta 500 de un ciclo, presionar Continue 499 veces no es opción. Haz clic secundario sobre el breakpoint, elige *Edit Breakpoint* y escribe una **condición**, por ejemplo `precio == 45`. El depurador solo se pausará cuando la condición sea verdadera. También puedes indicar cuántas veces ignorarlo antes de pausar.

## La documentación oficial

Cuando no sabes qué hace una función o qué parámetros recibe, la respuesta está en la documentación. Desde Xcode:

- **Ayuda rápida**: mantén presionada la tecla Option (⌥) y haz clic sobre un símbolo, por ejemplo `print`. Aparece un globo con su declaración y un resumen.
- **Inspector de ayuda rápida**: en el panel de inspectores, a la derecha, muestra lo mismo para el símbolo donde está el cursor.
- **Documentación completa**: *Help → Developer Documentation*. Es la misma documentación de developer.apple.com, con buscador.

### Cómo leer una página

La página de `print` en la documentación de Apple tiene esta declaración:

```swift ilustrativo
func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
)
```

Parte por parte:

1. `func print` es una función llamada `print`.
2. `_ items: Any...` es el primer parámetro. El `_` significa que no lleva etiqueta al llamarla; `Any...` significa que acepta **cualquier cantidad** de valores de **cualquier tipo**.
3. `separator: String = " "` lleva la etiqueta `separator`, recibe un texto y, si no lo indicas, vale un espacio.
4. `terminator: String = "\n"` vale por defecto `"\n"`, el salto de línea. Por eso cada `print` termina en una línea nueva.

Debajo de la declaración, una página típica tiene una descripción general (*Overview*), la explicación de cada parámetro, ejemplos y, para frameworks de Apple, la **disponibilidad**: desde qué versión de cada sistema operativo existe.

> [!practica]
> Antes de buscar un tutorial, lee la documentación del símbolo. Es más precisa, está actualizada para tu versión y te dice exactamente qué recibe y qué devuelve.

## Errores frecuentes

> [!error] El programa no se detiene en el breakpoint
> El breakpoint puede estar desactivado (se ve tenue), todos los breakpoints pueden estar desactivados desde la barra de depuración, o esa línea nunca se ejecuta. Revisa los tres casos.

> [!error] Leer los valores como si la línea ya se hubiera ejecutado
> El programa se pausa **antes** de la línea marcada. Para ver el efecto de esa línea, presiona Step Over y vuelve a mirar.

> [!error] Usar Step Into en cada línea
> Step Into entra a cada función que se llama, incluidas las de la biblioteca estándar cuando hay información de depuración. Si solo te interesa tu código, usa Step Over.

> [!error] Olvidar breakpoints viejos
> Un breakpoint olvidado pausa el programa en el peor momento. Revisa de vez en cuando el navegador de breakpoints.

````exercise
id: m03-l05-e1
type: comprension
prompt: |
  El programa está pausado en un breakpoint en la línea `total = total + precio`. El visor muestra `total = 120` y `precio = 80`. Presionas **Step Over** una vez. ¿Qué valor muestra ahora el visor para `total`?
choices:
  - text: "120"
    correct: false
    why: Ese es el valor antes de ejecutar la línea.
  - text: "200"
    correct: true
    why: Step Over ejecuta la línea, 120 + 80, y se detiene en la siguiente.
  - text: "80"
    correct: false
    why: Eso pasaría con la versión con error, total = precio.
  - text: El programa termina.
    correct: false
    why: Step Over avanza una sola línea.
solution: |
  **200.** En un breakpoint el programa se pausa **antes** de la línea marcada; por eso al principio `total` todavía vale 120. Step Over ejecuta `total = total + precio` (120 + 80) y se detiene en la siguiente línea, con `total` en 200.
````

````exercise
id: m03-l05-e2
type: prediccion
prompt: Este programa tiene el mismo error de acumulador de la lección, ahora con cuatro precios. Escribe exactamente lo que imprime.
code: |
  var total = 0
  for precio in [30, 15, 50, 5] {
      total = precio
  }
  print("Total:", total)
  print("Esperado:", 30 + 15 + 50 + 5)
output: |
  Total: 5
  Esperado: 100
hints:
  - La línea dentro de las llaves reemplaza el total en cada vuelta.
  - "print con dos valores los separa con un espacio."
solution: |
  ```output
  Total: 5
  Esperado: 100
  ```

  `total = precio` reemplaza el valor en cada vuelta, así que al terminar `total` es el **último** precio, 5. La segunda línea calcula la suma real, 100. Con un breakpoint en `total = precio` verías `total` valer 0, 30, 15 y 50 antes de cada vuelta: nunca crece de forma acumulada.
````

````exercise
id: m03-l05-e3
type: resolver
prompt: |
  Este programa debería mostrar el **mayor** de los números, 42, pero muestra otro valor. Pégalo en tu proyecto, pon un breakpoint en la línea del `if`, observa `mayor` y `n` en cada pausa y encuentra el error. Anota la tabla de lo que viste y escribe la corrección.

  ```swift
  var mayor = 0
  for n in [17, 42, 8, 23] {
      if n < mayor {
          mayor = n
      }
  }
  print("Mayor:", mayor)
  ```
starter: |
  Pausa | n | mayor antes del if
hints:
  - Observa si la línea mayor = n llega a ejecutarse alguna vez. Usa Step Over para verlo.
  - "Revisa el sentido de la comparación: ¿queremos quedarnos con n cuando es menor o cuando es mayor?"
  - Revisa también el valor inicial, 0. ¿Funcionaría con números negativos?
rubric:
  - Anoté en una tabla los valores de n y mayor en cada pausa.
  - Identifiqué que la comparación debía ser n > mayor.
  - Mencioné que empezar en 0 falla si todos los números son negativos.
  - Mi versión corregida imprime Mayor, 42.
solution: |
  Lo que muestra el depurador en cada pausa sobre el `if`:

  | Pausa | n | mayor antes del if |
  | --- | --- | --- |
  | 1 | 17 | 0 |
  | 2 | 42 | 0 |
  | 3 | 8 | 0 |
  | 4 | 23 | 0 |

  `mayor` nunca cambia: ningún número es menor que 0, así que `mayor = n` no se ejecuta y el programa imprime `Mayor: 0`. La comparación está al revés. Además, empezar en 0 es el error de «valor inventado» del Módulo 2: con `[-5, -2]` el resultado sería 0. Empezar con el primer elemento lo evita; por ahora, como la lista es fija, basta con empezar en su primer valor:

  ```swift
  var mayor = 17
  for n in [17, 42, 8, 23] {
      if n > mayor {
          mayor = n
      }
  }
  print("Mayor:", mayor)
  ```

  ```output
  Mayor: 42
  ```

  En el módulo de colecciones verás cómo tomar el primer elemento de cualquier lista de forma segura.
````

````exercise
id: m03-l05-e4
type: explicar
prompt: |
  Abre la ayuda rápida de `print` en Xcode (Option y clic sobre la palabra) o su página de documentación. Con base en esta declaración, explica por qué `print("a", "b")` imprime `a b` en una sola línea y termina con un salto de línea, y cómo harías que imprimiera `a-b` sin salto de línea.
code: |
  func print(
      _ items: Any...,
      separator: String = " ",
      terminator: String = "\n"
  )
rubric:
  - Expliqué que Any... acepta varios valores.
  - Relacioné el espacio entre a y b con el valor predeterminado de separator.
  - Relacioné el salto de línea con el valor predeterminado de terminator.
  - "Escribí la llamada print(\"a\", \"b\", separator: \"-\", terminator: \"\")."
solution: |
  - `_ items: Any...` permite pasar varios valores sin etiqueta: `"a"` y `"b"`.
  - Como no indicas `separator`, vale su predeterminado `" "`: entre `a` y `b` se escribe un espacio.
  - Como no indicas `terminator`, vale `"\n"`: al final se escribe un salto de línea.

  Para `a-b` sin salto de línea se cambian ambos:

  ```swift
  print("a", "b", separator: "-", terminator: "")
  ```

  Imprime `a-b` y nada más: lo siguiente que se imprima continuará en la misma línea.

  Leer la declaración responde la pregunta sin buscar un tutorial. Volverás a `separator` y `terminator` en la primera lección del Módulo 4.
````

````exercise
id: m03-l05-e5
type: comprension
prompt: El programa está pausado. Quieres saber cuánto valdría `total + precio` sin modificar el código. ¿Qué escribes en la consola de LLDB?
choices:
  - text: "`v total + precio`"
    correct: false
    why: v solo lee variables de memoria; no evalúa expresiones.
  - text: "`p total + precio`"
    correct: true
    why: p (expression) compila y evalúa la expresión con los valores actuales.
  - text: "`print(total + precio)`"
    correct: false
    why: En la consola de LLDB se escriben comandos del depurador, no instrucciones del programa.
  - text: "No se puede; hay que agregar un print y volver a ejecutar."
    correct: false
    why: La consola del depurador permite evaluar expresiones sin modificar el programa.
solution: |
  **`p total + precio`**. `p` es la abreviatura de `expression`: compila la expresión y la evalúa con los valores actuales. `v` (frame variable) es más rápido y seguro, pero solo muestra variables tal como están en memoria, sin evaluar operaciones.
````

## Resumen

- Un breakpoint pausa el programa **antes** de la línea marcada.
- Continue avanza hasta el siguiente breakpoint; Step Over ejecuta una línea; Step Into entra a una función; Step Out sale de ella.
- El visor de variables y la consola (`v`, `p`, `po`) muestran los valores reales; compáralos con los esperados, como en una tabla de seguimiento.
- Un breakpoint condicional evita presionar Continue cientos de veces.
- Option y clic muestra la ayuda rápida; *Help → Developer Documentation* abre la documentación completa. Lee la declaración: dice qué recibe una función y sus valores predeterminados.
