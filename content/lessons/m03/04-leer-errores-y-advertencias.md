---
id: m03-l04
title: "Leer al compilador: errores, advertencias y errores en ejecución"
description: Aprendes a leer un mensaje del compilador de Swift parte por parte, a distinguir un error de compilación de una advertencia y de un error en ejecución, y a corregir sin adivinar.
module: m03
order: 4
level: inicial
minutes: 45
prerequisites: [m03-l02, m01-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Leer un diagnóstico del compilador identificando archivo, línea, columna, tipo y mensaje.
  - Distinguir error de compilación, advertencia y error en ejecución por cuándo aparecen y qué consecuencia tienen.
  - Corregir errores de sintaxis y de nombres a partir del mensaje, sin cambiar código al azar.
  - Explicar por qué el compilador a veces señala una línea distinta de la que tiene el problema.
terms:
  - term: Diagnóstico
    definition: Mensaje que produce el compilador sobre tu código. Puede ser un error, una advertencia o una nota.
  - term: Error de compilación
    definition: Diagnóstico que impide generar el programa. Hasta corregirlo, no hay nada que ejecutar.
  - term: Advertencia
    definition: Diagnóstico que no impide compilar pero señala algo sospechoso, como un valor que nunca se usa. En inglés, warning.
  - term: Error en ejecución
    definition: Falla que ocurre mientras el programa corre, con datos concretos. En Swift suele detener el programa con un mensaje Fatal error.
  - term: Fix-it
    definition: Corrección automática que Xcode ofrece junto a algunos diagnósticos. Conviene leerla antes de aceptarla.
  - term: Ámbito
    definition: La región del código donde un nombre existe. «cannot find 'x' in scope» significa que en ese lugar no existe nada llamado x.
mastery:
  - Señalar en un diagnóstico de una línea el archivo, la línea, la columna, el tipo y el mensaje.
  - Clasificar cinco problemas dados como error de compilación, advertencia o error en ejecución y justificarlo.
  - Corregir un programa con tres errores de compilación leyendo solo los mensajes.
  - Encontrar el problema real cuando el compilador señala la línea siguiente.
resources: [swift-book-basics, xcode-overview]
cards:
  - id: m03-l04-c1
    front: "¿Qué significa cada parte de `p.swift:2:15: error: expected ',' separator`?"
    back: "Archivo p.swift, línea 2, columna 15, tipo error y el mensaje: el compilador esperaba una coma separadora en ese punto."
  - id: m03-l04-c2
    front: ¿Qué diferencia hay entre un error de compilación y una advertencia?
    back: El error impide generar el programa. La advertencia deja compilar, pero señala algo sospechoso que casi siempre conviene corregir.
  - id: m03-l04-c3
    front: "¿Qué significa `cannot find 'precio' in scope`?"
    back: Que en ese lugar del código no existe nada llamado precio. Suele ser un error de escritura, de mayúsculas o un nombre que todavía no se ha declarado.
  - id: m03-l04-c4
    front: ¿Cómo se ve en Swift un error en ejecución típico?
    back: "El programa compila, empieza a correr y se detiene con un mensaje como «Fatal error: Index out of range». En Xcode, la ejecución se pausa en la línea que lo causó."
---

## La idea en una frase

El compilador es tu primer revisor y escribe en un formato fijo: si aprendes a leerlo, la mitad de los errores se corrigen en segundos.

> [!nota]
> Los mensajes de esta lección son los que produce el compilador de Swift 6.3, y las pruebas automáticas del curso comprueban que siguen apareciendo así. Otras versiones pueden redactar algún mensaje distinto; la forma de leerlos es la misma.

## Tres tipos de problemas

| Tipo | Cuándo aparece | ¿Hay programa? | Ejemplo |
| --- | --- | --- | --- |
| Error de compilación | Al compilar | No | Comillas sin cerrar |
| Advertencia | Al compilar | Sí | Un valor que nunca se usa |
| Error en ejecución | Mientras corre | Sí, y se detiene | Pedir el elemento 4 de una lista de 3 |

La lección «Del código fuente al programa» presentó la diferencia entre compilación y ejecución. Aquí aprendes a reconocer cada tipo por su mensaje.

## Anatomía de un diagnóstico

```swift no-compila cannot find 'precio' in scope
print(precio)
```

Al compilar este archivo, guardado como `r7.swift`, desde la terminal:

```output
r7.swift:1:7: error: cannot find 'precio' in scope
1 | print(precio)
  |       `- error: cannot find 'precio' in scope
2 |
```

Parte por parte:

1. `r7.swift` es el **archivo**.
2. `1` es la **línea**.
3. `7` es la **columna**: el carácter donde empieza el problema, contando desde 1. La `p` de `precio` está en la columna 7.
4. `error` es el **tipo**. También puede ser `warning` o `note`.
5. `cannot find 'precio' in scope` es el **mensaje**: no existe nada llamado `precio` en ese lugar.
6. Las líneas siguientes repiten el código con un indicador debajo de la columna exacta.

En Xcode, el mismo diagnóstico aparece como un ícono rojo junto a la línea y en el **navegador de problemas** (*Issue navigator*), a la izquierda. Al hacer clic en él, Xcode te lleva a la línea.

### Los mensajes más comunes al empezar

```swift no-compila cannot find 'Print' in scope
Print("Hola")
```

Swift distingue mayúsculas de minúsculas. `Print` no existe; `print` sí.

```swift no-compila unterminated string literal
print("Hola)
```

Falta cerrar las comillas. El texto «se come» el paréntesis de cierre.

```swift no-compila binary operator '+' cannot be applied to operands of type 'String' and 'Int'
print("Total: " + 5)
```

El `+` no está definido entre un texto (`String`) y un número entero (`Int`). En el Módulo 4 aprenderás a combinar texto y números correctamente.

### Cuando el compilador señala la línea siguiente

```swift no-compila expected ',' separator
print("Hola")
print("Adiós"
print("Fin")
```

```output
p.swift:2:15: error: expected ',' separator
```

El problema es un paréntesis que falta al final de la línea 2. El compilador no puede saber que olvidaste el paréntesis: ve que después de `"Adiós"` viene otra cosa (el `print` de la línea 3) y supone que faltaba una coma para pasar otro valor. Por eso el mensaje habla de una coma.

Regla práctica: **el error está en la posición señalada o antes, nunca después**. Si la línea señalada se ve bien, revisa el final de la anterior.

### Un error que el compilador detecta haciendo cuentas

```swift no-compila results in an overflow
print(Int.max + 1)
```

`Int.max` es el entero más grande que cabe en un `Int`. Como ambos valores se conocen al compilar, el compilador calcula la suma, ve que no cabe y lo reporta: `arithmetic operation '9223372036854775807 + 1' (on type 'Int') results in an overflow`. Si el valor solo se conociera durante la ejecución, el mismo problema sería un error en ejecución.

## Advertencias

```swift advertencia initialization of immutable value 'sinUsar' was never used
do {
    let sinUsar = 10
    print("Hola")
}
```

```output
Hola
```

El programa compila y se ejecuta, pero el compilador avisa:

```plaintext
warning: initialization of immutable value 'sinUsar' was never used; consider replacing with assignment to '_' or removing it
```

`let sinUsar = 10` guarda un valor con nombre (lo estudiarás en el Módulo 4) que nadie usa después. No rompe nada, pero casi siempre es un descuido: o sobra la línea, o faltó usar el valor. En Xcode las advertencias se marcan con un triángulo amarillo.

> [!practica]
> Mantén tus proyectos en **cero advertencias**. Si ignoras diez advertencias inofensivas, no verás la undécima que sí importa.

## Errores en ejecución

```swift falla-en-ejecucion Index out of range
let numeros = [10, 20, 30]
print("antes")
print(numeros[3])
print("después")
```

```output
antes
```

Este programa **compila sin errores**. Al ejecutarlo, imprime `antes` y se detiene con un mensaje como este en la salida de errores:

```plaintext
Fatal error: Index out of range
```

La lista tiene 3 elementos, en las posiciones 0, 1 y 2 (lo verás en el módulo de colecciones). Pedir la posición 3 no tiene sentido. Swift **detiene el programa** en lugar de leer memoria que no le pertenece, y `después` nunca se imprime.

En Xcode, la ejecución se pausa en la línea culpable, marcada en rojo, con el mensaje junto a ella. La consola muestra el mismo `Fatal error`.

## Método para corregir errores de compilación

1. **Empieza por el primer error.** Uno solo puede provocar varios más abajo; al corregirlo, los demás a veces desaparecen.
2. **Lee el mensaje completo**, no solo la primera palabra.
3. **Ve a la línea y columna exactas.** Si se ven bien, revisa lo que hay justo antes.
4. **Haz un solo cambio y vuelve a compilar.** Cambiar cinco cosas a la vez te impide saber cuál funcionó.
5. **Lee los fix-its antes de aceptarlos.** Xcode a veces propone una corrección con un botón *Fix*. Suele acertar en errores de escritura, pero no conoce tu intención.

## Errores frecuentes

> [!error] Corregir el último error primero
> Los errores se producen en cascada. Empieza siempre por el primero de la lista.

> [!error] Cambiar código al azar hasta que compile
> Si no entiendes el mensaje, no sabes si tu cambio corrigió el problema o lo escondió. Lee, formula una hipótesis, cambia una cosa, compila.

> [!error] Ignorar las advertencias
> Las advertencias son errores pequeños que todavía no te han costado nada. Corrígelas en cuanto aparecen.

> [!error] Pensar que si compila, funciona
> Un programa sin errores ni advertencias puede detenerse en ejecución o, peor, dar un resultado incorrecto sin detenerse.

````exercise
id: m03-l04-e1
type: comprension
prompt: |
  ¿Qué indica el número `15` en este diagnóstico?

  ```plaintext
  p.swift:2:15: error: expected ',' separator
  ```
choices:
  - text: El número de errores en el archivo.
    correct: false
    why: El formato es archivo:línea:columna; no cuenta errores.
  - text: La columna donde el compilador detectó el problema.
    correct: true
    why: El tercer número es la columna, contando caracteres desde 1.
  - text: La línea del error.
    correct: false
    why: La línea es el segundo número, 2.
  - text: El código interno del error.
    correct: false
    why: El compilador de Swift no usa números de código en este formato.
solution: |
  Es la **columna**. El formato es `archivo:línea:columna: tipo: mensaje`, así que el problema está en `p.swift`, línea 2, columna 15. En Xcode no necesitas contar: el diagnóstico aparece junto a la línea y al hacer clic te lleva a la posición exacta.
````

````exercise
id: m03-l04-e2
type: prediccion
prompt: Este programa compila sin errores pero tiene un error en ejecución en la tercera línea. Escribe exactamente lo que imprime **antes** de detenerse; no incluyas el mensaje de error.
code: |
  print("Inicio")
  print(3 + 4)
  print([1, 2][5])
  print("Fin")
output: |
  Inicio
  7
hints:
  - El programa se ejecuta de arriba hacia abajo hasta que algo lo detiene.
  - "La lista [1, 2] tiene dos elementos; la posición 5 no existe."
solution: |
  ```output
  Inicio
  7
  ```

  Las dos primeras líneas se ejecutan normalmente. La tercera pide la posición 5 de una lista de dos elementos: el programa se detiene con `Fatal error: Index out of range` y `Fin` nunca se imprime. Lo que ya se imprimió antes del error permanece en la consola, y eso es útil para saber hasta dónde llegó el programa.
````

````exercise
id: m03-l04-e3
type: errores
prompt: |
  Este programa no compila. El compilador solo muestra un error, `expected ',' separator`, al final de la línea 2. Identifica todos los problemas reales del programa y escribe la versión corregida.
code: |
  print("Lista de compras")
  print("Leche"
  print("Pan")
  print(Huevos)
  Print("Total de productos:", 3)
choices:
  - text: "En la línea 2 falta el paréntesis de cierre."
    correct: true
    why: "Por eso el compilador se queja al final de la línea 2 de que esperaba una coma: ve otro print donde esperaba ) o una coma."
  - text: "En la línea 4, Huevos va sin comillas y no existe ningún nombre Huevos."
    correct: true
    why: "El mensaje sería cannot find 'Huevos' in scope."
  - text: "En la línea 5, Print con mayúscula no existe."
    correct: true
    why: Swift distingue mayúsculas de minúsculas.
  - text: "Falta una coma al final de la línea 2, como dice el mensaje."
    correct: false
    why: "El mensaje habla de una coma porque el compilador ve otro print donde esperaba más valores. Lo que falta es el paréntesis de cierre."
rubric:
  - Agregué el paréntesis que falta en la línea 2.
  - Puse comillas a Huevos.
  - Cambié Print por print.
  - Compilé de nuevo después de cada corrección, empezando por el primer error.
solution: |
  ```swift
  print("Lista de compras")
  print("Leche")
  print("Pan")
  print("Huevos")
  print("Total de productos:", 3)
  ```

  Con Swift 6.3, el compilador reporta un solo error, `expected ',' separator` al final de la línea 2: falta el paréntesis. Al corregirlo aparecen los otros dos, `cannot find 'Huevos' in scope` y `cannot find 'Print' in scope`. Por eso conviene corregir de uno en uno y volver a compilar.
````

````exercise
id: m03-l04-e4
type: comprension
multiple: true
prompt: ¿Cuáles de estas situaciones son **errores en ejecución**? Selecciona todas las que apliquen.
choices:
  - text: El programa se detiene con «Fatal error» al leer una posición que no existe en una lista.
    correct: true
    why: Compila bien y falla con un dato concreto mientras corre.
  - text: Xcode marca con un triángulo amarillo un valor que nunca se usa.
    correct: false
    why: Es una advertencia, se detecta al compilar.
  - text: El compilador dice «unterminated string literal».
    correct: false
    why: Es un error de compilación; no hay programa que ejecutar.
  - text: "El programa divide entre un número que el usuario escribió, el usuario escribe 0 y el programa se detiene."
    correct: true
    why: El compilador no puede saber qué escribirá el usuario; ocurre durante la ejecución.
solution: |
  Son errores en ejecución **leer una posición inexistente** y **dividir entre un 0 que llegó como dato**. En ambos casos el programa compila y la falla depende de valores que solo existen mientras corre. Las comillas sin cerrar son un error de compilación y el valor sin usar es una advertencia.
````

````exercise
id: m03-l04-e5
type: resolver
prompt: |
  Provoca a propósito, en tu proyecto `Practicas` o en un archivo suelto, estos cuatro diagnósticos, uno a la vez. Para cada uno copia el mensaje exacto que te dé tu compilador y escribe en una frase qué significa:

  1. `cannot find '…' in scope`
  2. `unterminated string literal`
  3. Una advertencia de valor sin usar
  4. Un `Fatal error` en ejecución
starter: |
  // 1.
hints:
  - Para la advertencia puedes copiar el ejemplo del bloque do de la lección.
  - "Para el error en ejecución, el ejemplo de la lista con [10, 20, 30] funciona."
rubric:
  - Provoqué los cuatro diagnósticos y copié el texto que mostró mi compilador.
  - Distinguí en mis notas cuáles impidieron ejecutar y cuál dejó ejecutar con un aviso.
  - En el error en ejecución anoté qué se imprimió antes de detenerse.
  - Expliqué cada mensaje con mis palabras.
solution: |
  Una forma de provocarlos:

  ```swift no-compila cannot find 'saludo' in scope
  print(saludo)
  ```

  ```swift no-compila unterminated string literal
  print("Hola)
  ```

  ```swift advertencia initialization of immutable value 'edad' was never used
  do {
      let edad = 30
  }
  print("Listo")
  ```

  ```swift falla-en-ejecucion Index out of range
  print([10, 20, 30][3])
  ```

  1. `cannot find 'saludo' in scope`: no existe nada llamado `saludo`; faltan comillas o el nombre no se ha declarado.
  2. `unterminated string literal`: un texto empieza con comillas y no se cierra.
  3. `initialization of immutable value 'edad' was never used`: compila y ejecuta, pero un valor se guardó y nunca se usó.
  4. `Fatal error: Index out of range`: compila, pero al ejecutarse pide una posición que no existe y el programa se detiene.

  Los dos primeros impiden ejecutar; el tercero deja ejecutar con un aviso; el cuarto solo aparece al ejecutar. Tu compilador puede redactar algún mensaje con otras palabras si tienes otra versión.
````

## Resumen

- Formato de un diagnóstico: `archivo:línea:columna: tipo: mensaje`.
- Error de compilación: no hay programa. Advertencia: hay programa, pero algo es sospechoso. Error en ejecución: el programa se detiene con datos concretos.
- El problema está en la posición señalada o antes; revisa el final de la línea anterior.
- Corrige de uno en uno, empezando por el primer error, y vuelve a compilar.
- Mantén cero advertencias.
