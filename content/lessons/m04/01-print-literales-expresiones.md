---
id: m04-l01
title: "Tus primeras líneas: print, comentarios, literales y expresiones"
description: Escribes y ejecutas tus primeros programas en Swift, aprendes a predecir exactamente lo que imprimen y descubres por qué 7 / 2 da 3.
module: m04
order: 1
level: inicial
minutes: 50
prerequisites: [m01-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Usar print con uno o varios valores, separator y terminator.
  - Escribir comentarios de una línea y de varias líneas.
  - Reconocer literales enteros, decimales y de texto.
  - Evaluar expresiones aritméticas aplicando precedencia y asociatividad.
  - Explicar la diferencia entre división entera y división decimal.
terms:
  - term: Literal
    definition: Un valor escrito directamente en el código, como 42, 3.5 o "Hola".
  - term: Expresión
    definition: Combinación de valores y operadores que produce un nuevo valor, como 2 + 3.
  - term: Operador
    definition: Símbolo que realiza una operación sobre uno o más valores, como +, -, * o /.
  - term: Precedencia
    definition: Regla que decide qué operación se hace primero cuando hay varias en una expresión. La multiplicación va antes que la suma.
  - term: Asociatividad
    definition: Regla que decide el orden entre operadores de la misma precedencia. La resta se agrupa de izquierda a derecha.
  - term: Comentario
    definition: Texto en el código que el compilador ignora. Sirve para explicar a otras personas, o a ti en el futuro, por qué el código es así.
mastery:
  - Predecir sin ejecutar la salida exacta de un programa con varios print, incluyendo separator y terminator.
  - Calcular a mano el resultado de expresiones como 2 + 3 * 4, (2 + 3) * 4 y 10 - 4 - 3.
  - Explicar por qué 7 / 2 da 3 y 7.0 / 2 da 3.5.
  - Corregir errores de compilación típicos de print sin ayuda del compilador.
resources: [swift-book-basics, swift-book-basic-operators, swift-print]
cards:
  - id: m04-l01-c1
    front: ¿Qué imprime `print(7 / 2)` en Swift y por qué?
    back: "Imprime 3. Ambos operandos son enteros (Int), así que la división es entera y descarta la parte decimal."
  - id: m04-l01-c2
    front: '¿Qué imprime `print(1, 2, 3, separator: "-")`?'
    back: "1-2-3. Por defecto print separa sus valores con un espacio; separator cambia ese separador."
  - id: m04-l01-c3
    front: ¿Cuánto vale `2 + 3 * 4` y cuánto `10 - 4 - 3`?
    back: "14, porque la multiplicación tiene mayor precedencia. 3, porque la resta se agrupa de izquierda a derecha: (10 - 4) - 3."
  - id: m04-l01-c4
    front: ¿Para qué sirven los comentarios y qué hace el compilador con ellos?
    back: El compilador los ignora. Sirven para explicar el porqué del código, no para repetir lo que el código ya dice.
---

## Dónde ejecutar estos ejemplos

Tienes dos opciones mientras llegas al módulo del entorno de desarrollo:

- **Xcode**: *File → New → Playground*, plantilla *Blank*. Escribe el código y presiona el botón de ejecutar.
- **Terminal** (con Xcode instalado): guarda el código en un archivo `hola.swift` y ejecuta `swift hola.swift`.

```bash
swift hola.swift
```

Cada ejemplo de esta lección imprime en la consola. Antes de ejecutar cualquiera, **predice qué va a imprimir**. Ese hábito es el ejercicio más importante de la lección.

## print: la primera función

**Definición sencilla:** `print` muestra valores en la consola.

**Definición precisa:** `print` es una función de la biblioteca estándar de Swift. Recibe cero o más valores, los convierte en texto, los escribe separados por un `separator` (un espacio, si no indicas otro) y al final escribe un `terminator` (un salto de línea, si no indicas otro).

```swift
print("Hola")
print("Hola", "Swift")
print(1, 2, 3, separator: "-")
print("Sin salto", terminator: "")
print("!")
```

Línea por línea:

1. `print("Hola")` imprime `Hola` y un salto de línea.
2. `print("Hola", "Swift")` recibe dos valores y los separa con el separador por defecto: `Hola Swift`.
3. `separator: "-"` cambia el separador: `1-2-3`.
4. `terminator: ""` reemplaza el salto de línea final por nada, así que lo siguiente se escribe en la misma línea.
5. `print("!")` imprime `!` justo después: la cuarta y quinta línea producen juntas `Sin salto!`.

```output
Hola
Hola Swift
1-2-3
Sin salto!
```

`separator:` y `terminator:` son **etiquetas de argumento**: nombres que acompañan a ciertos valores al llamar una función. Las estudiarás a fondo en el módulo de funciones; por ahora basta con saber que se escriben así, con dos puntos.

## Comentarios

Un comentario es texto que el compilador ignora.

```swift
// Comentario de una línea: todo lo que sigue a // se ignora.
print("Visible") // también puede ir al final de una línea

/*
 Comentario de varias líneas.
 /* En Swift los comentarios de varias líneas se pueden anidar. */
*/
```

El buen comentario explica **por qué**, no **qué**. `// imprime 5` encima de `print(5)` no aporta nada. `// El banco redondea a dos decimales por regulación` sí.

## Literales

Un **literal** es un valor escrito tal cual en el código:

| Literal | Tipo que Swift le asigna por defecto | Ejemplo |
| --- | --- | --- |
| Entero | `Int` | `42`, `-7`, `1_000_000` |
| Decimal | `Double` | `3.5`, `0.1`, `-2.0` |
| Texto | `String` | `"Hola"`, `"42"` |
| Booleano | `Bool` | `true`, `false` |

El guion bajo en `1_000_000` solo mejora la lectura; vale lo mismo que `1000000`.

Ojo con `"42"`: con comillas es un **texto** que contiene los caracteres 4 y 2, no el número 42. Por eso `print("1" + "2")` imprime `12`: el `+` entre textos los **une** (concatena), no los suma.

## Expresiones y operadores aritméticos

Una **expresión** produce un valor. Los operadores aritméticos básicos son:

| Operador | Significado | Ejemplo | Resultado |
| --- | --- | --- | --- |
| `+` | suma | `7 + 2` | `9` |
| `-` | resta | `7 - 2` | `5` |
| `*` | multiplicación | `7 * 2` | `14` |
| `/` | división | `7 / 2` | `3` |
| `%` | residuo | `7 % 2` | `1` |

### Por qué 7 / 2 da 3

Si los dos operandos son enteros (`Int`), el resultado también es un entero: Swift **descarta la parte decimal**. No redondea: trunca hacia cero.

```swift
print(7 / 2)
print(7.0 / 2)
print(7 % 2)
```

```output
3
3.5
1
```

En `7.0 / 2`, el `7.0` es decimal y Swift interpreta el `2` también como decimal, así que la división es decimal y da `3.5`. El operador `%` devuelve el **residuo** de la división entera: 7 entre 2 cabe 3 veces y sobra 1.

### Precedencia y asociatividad

Como en aritmética escolar, `*`, `/` y `%` se evalúan antes que `+` y `-`. Entre operadores del mismo nivel, Swift agrupa de **izquierda a derecha**.

```swift
print(2 + 3 * 4)
print((2 + 3) * 4)
print(10 - 4 - 3)
```

```output
14
20
3
```

- `2 + 3 * 4` → primero `3 * 4 = 12`, luego `2 + 12 = 14`.
- Los paréntesis cambian el orden: `(2 + 3) * 4 = 20`.
- `10 - 4 - 3` se agrupa como `(10 - 4) - 3 = 3`, no como `10 - (4 - 3) = 9`.

Regla práctica profesional: si una persona tiene que pensar en la precedencia para entender tu expresión, **agrega paréntesis**. Cuestan nada y evitan errores.

## Swift no mezcla tipos en silencio

Esto no compila:

```swift no-compila binary operator '+' cannot be applied to operands of type 'String' and 'Int'
print("Total: " + 5)
```

El `+` entre un `String` y un `Int` no está definido. Otros lenguajes convierten el número a texto automáticamente; Swift no, porque esas conversiones silenciosas son fuente de errores. Al final de este módulo aprenderás la forma correcta de combinar texto y números, la **interpolación**. Por ahora, `print` con varios valores resuelve el caso:

```swift
print("Total:", 5)
```

```output
Total: 5
```

## Errores frecuentes

> [!error] error: cannot find 'Print' in scope
> Swift distingue mayúsculas de minúsculas. `Print` y `print` son nombres distintos, y `Print` no existe.

> [!error] error: unterminated string literal
> Falta cerrar las comillas de un texto. El compilador señala la línea donde empieza el texto sin cerrar.

> [!error] Esperar decimales de una división entre enteros
> `7 / 2` es `3`. Si necesitas `3.5`, al menos uno de los valores debe ser decimal.

> [!error] Confundir el texto "5" con el número 5
> `"5" + "5"` es `"55"`. `5 + 5` es `10`.

````exercise
id: m04-l01-e1
type: comprension
prompt: ¿Qué imprime `print(9 / 4)`?
choices:
  - text: "`2.25`"
    correct: false
    why: Eso sería el resultado de una división decimal. Aquí ambos operandos son enteros.
  - text: "`2`"
    correct: true
    why: División entera entre Int, la parte decimal se descarta.
  - text: "`3`"
    correct: false
    why: Swift no redondea en la división entera; trunca.
  - text: Un error de compilación
    correct: false
    why: Dividir dos enteros es válido; el resultado es otro entero.
solution: |
  Imprime **2**. `9` y `4` son literales enteros, así que Swift los trata como `Int` y hace división entera: 4 cabe 2 veces en 9 y el sobrante (1) se descarta. Si quisieras `2.25`, escribirías `9.0 / 4`.
````

````exercise
id: m04-l01-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea. Después, si quieres, verifícala ejecutándola.
code: |
  print("A", "B", "C")
  print("A", "B", "C", separator: "")
  print(10 - 4 - 3)
  print(2 * 3 + 4 * 5)
  print("1" + "2")
  // print("¿Me ves?")
  print(17 % 5)
output: |
  A B C
  ABC
  3
  26
  12
  2
hints:
  - El separador por defecto es un espacio.
  - La línea que empieza con // no se ejecuta.
  - "2 * 3 + 4 * 5: haz primero las multiplicaciones."
solution: |
  ```output
  A B C
  ABC
  3
  26
  12
  2
  ```

  1. Tres valores con el separador por defecto, un espacio.
  2. `separator: ""` los une sin espacio.
  3. `(10 - 4) - 3 = 3`, por asociatividad de izquierda a derecha.
  4. `6 + 20 = 26`: las multiplicaciones primero.
  5. Concatenación de textos: `"12"`.
  6. La línea comentada no existe para el compilador.
  7. 5 cabe 3 veces en 17 (15) y sobran **2**.
````

````exercise
id: m04-l01-e3
type: completar
prompt: |
  Completa el programa para que imprima exactamente:

  ```output
  Área: 12
  ```

  El primer hueco debe convertir la primera línea en un comentario de una línea.
code: |
  [[1]] Área de un rectángulo de 3 por 4
  print("Área:", 3 [[2]] 4)
blanks:
  - id: "1"
    answers: ["//"]
  - id: "2"
    answers: ["*"]
solution: |
  ```swift
  // Área de un rectángulo de 3 por 4
  print("Área:", 3 * 4)
  ```

  `//` convierte la línea en comentario. `3 * 4` es la multiplicación. `print` separa sus dos valores con un espacio, por eso aparece `Área: 12`.
````

````exercise
id: m04-l01-e4
type: errores
prompt: Este programa no compila. Identifica los problemas reales y después escribe la versión corregida en el editor.
code: |
  print("Bienvenido al curso)
  Print("Lección 1")
  print("Total:" + 3)
choices:
  - text: "En la línea 1 falta cerrar las comillas."
    correct: true
    why: "El texto empieza en `\"Bienvenido` y nunca se cierra."
  - text: "En la línea 2, `Print` con mayúscula no existe."
    correct: true
    why: Swift distingue mayúsculas de minúsculas.
  - text: "En la línea 3, no se puede usar `+` entre un String y un Int."
    correct: true
    why: Swift no convierte el número a texto en silencio.
  - text: "Faltan puntos y coma al final de cada línea."
    correct: false
    why: En Swift el punto y coma es opcional al final de una línea.
rubric:
  - Cerré las comillas de la línea 1.
  - Usé `print` en minúsculas.
  - "Corregí la línea 3 sin sumar texto y número, por ejemplo con `print(\"Total:\", 3)`."
  - Mi versión imprime tres líneas.
solution: |
  ```swift
  print("Bienvenido al curso")
  print("Lección 1")
  print("Total:", 3)
  ```

  Los tres problemas son errores de compilación: el programa no existe hasta corregirlos. El punto y coma no es obligatorio en Swift; solo se usa si escribes dos instrucciones en la misma línea.
````

````exercise
id: m04-l01-e5
type: resolver
prompt: |
  Escribe un programa que imprima un ticket de compra con estas tres líneas:

  ```output
  Café: 45
  Pan: 28
  Total: 73
  ```

  El total debe **calcularse** con una expresión en el código, no escribirse a mano.
starter: |
  // Ticket de compra
hints:
  - "`print` acepta varios valores separados por comas."
  - "Para el total, la expresión es `45 + 28`."
rubric:
  - El programa imprime exactamente las tres líneas pedidas.
  - El total se calcula con una expresión, no está escrito como 73.
  - No uso `+` entre texto y número.
  - Lo ejecuté en Xcode o en la terminal y comprobé la salida.
solution: |
  ```swift
  // Ticket de compra
  print("Café:", 45)
  print("Pan:", 28)
  print("Total:", 45 + 28)
  ```

  El problema de esta solución es que los precios aparecen dos veces: si el café sube de precio, hay que cambiarlo en dos lugares. Las **constantes**, en la siguiente lección, resuelven exactamente eso.
````

````exercise
id: m04-l01-e6
type: explicar
prompt: Explica con tus palabras qué calcula esta línea, en qué orden se evalúa y qué imprime.
code: |
  print(60 * 60 * 24)
rubric:
  - Dije el resultado correcto, 86400.
  - Expliqué el orden de evaluación, de izquierda a derecha.
  - Interpreté el significado, segundos en un día.
  - Propuse una forma de hacerlo más claro para quien lo lea.
solution: |
  Imprime **86400**. Los dos operadores son `*`, de la misma precedencia, así que se agrupa de izquierda a derecha: `(60 * 60) * 24 = 3600 * 24 = 86400`.

  Significa **segundos en un día**: 60 segundos por minuto, 60 minutos por hora, 24 horas por día. Como el número no se explica solo, un comentario ayuda: `// segundos en un día`. Mejor aún, con constantes con nombre, que verás en la siguiente lección.
````

````exercise
id: m04-l01-e7
type: refactorizar
prompt: |
  Este programa imprime el costo de tres desayunos iguales (café de 45 y pan de 28). Funciona, pero es difícil de leer y de mantener. Reescríbelo para que la intención sea evidente y el resultado sea el mismo.
code: |
  print(45 + 28 + 45 + 28 + 45 + 28)
rubric:
  - Mi versión imprime el mismo resultado, 219.
  - Se entiende que son tres desayunos iguales.
  - Usé paréntesis para dejar claro el orden de las operaciones.
  - Agregué un comentario que explica el porqué, no el qué.
solution: |
  ```swift
  // Tres desayunos iguales: café (45) + pan (28)
  print((45 + 28) * 3)
  ```

  `(45 + 28) * 3 = 73 * 3 = 219`, igual que la suma original. Los paréntesis son necesarios: sin ellos, `45 + 28 * 3` daría `129`, porque la multiplicación va primero. El resultado coincide, la estructura del cálculo ahora es visible y un cambio de precio se hace en un solo lugar.
````

## Resumen

- `print` convierte valores en texto, los separa con un espacio y termina con un salto de línea; `separator:` y `terminator:` cambian ese comportamiento.
- Los comentarios explican el porqué; el compilador los ignora.
- Los literales tienen tipos: `42` es `Int`, `3.5` es `Double`, `"Hola"` es `String`.
- La división entre enteros descarta la parte decimal; `%` da el residuo.
- La multiplicación y la división van antes que la suma y la resta; entre iguales, de izquierda a derecha. Ante la duda, paréntesis.
- Swift no mezcla texto y números en silencio.
