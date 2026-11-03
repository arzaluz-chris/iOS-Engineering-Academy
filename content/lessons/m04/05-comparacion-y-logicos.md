---
id: m04-l05
title: "Operadores de comparación y operadores lógicos"
description: Produces valores Bool comparando números y textos, y los combinas con &&, || y ! para expresar condiciones como «mayor de edad y con boleto». Es la base de todas las decisiones del siguiente módulo.
module: m04
order: 5
level: inicial
minutes: 45
prerequisites: [m04-l03]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Usar los operadores de comparación ==, !=, <, >, <= y >= con números y textos.
  - Combinar condiciones con &&, || y ! y predecir su resultado.
  - Aplicar la precedencia de ! sobre && y de && sobre || y usar paréntesis para aclarar.
  - Explicar la evaluación en cortocircuito.
  - Evitar los errores típicos al comparar textos y decimales.
terms:
  - term: Operador de comparación
    definition: Operador que compara dos valores del mismo tipo y produce un Bool, como == o <.
  - term: Operador lógico
    definition: Operador que combina o invierte valores Bool. En Swift, && (y), || (o) y ! (no).
  - term: Condición
    definition: Expresión cuyo resultado es un Bool. Es lo que preguntarán if, while y guard en el siguiente módulo.
  - term: Evaluación en cortocircuito
    definition: Regla por la que && no evalúa su lado derecho si el izquierdo es false, y || no lo evalúa si el izquierdo es true, porque el resultado ya está decidido.
  - term: Tabla de verdad
    definition: Tabla que lista el resultado de un operador lógico para todas las combinaciones de true y false.
  - term: Leyes de De Morgan
    definition: "Equivalencias para negar condiciones compuestas: !(a && b) es lo mismo que !a || !b, y !(a || b) es lo mismo que !a && !b."
mastery:
  - Predecir el resultado de expresiones como !(edad < 18) && tienePermiso para valores dados.
  - Escribir la condición «entre 18 y 64 años, inclusive» y la condición «fuera de ese rango» sin errores de borde.
  - Explicar por qué "árbol" < "zorro" es false en Swift.
  - Comparar dos Double con una tolerancia en lugar de ==.
resources: [swift-book-basic-operators]
cards:
  - id: m04-l05-c1
    front: ¿Qué diferencia hay entre `=` y `==`?
    back: = asigna un valor a un nombre. == compara dos valores y produce un Bool.
  - id: m04-l05-c2
    front: ¿Qué precedencia tienen `!`, `&&` y `||`?
    back: "! primero, luego &&, luego ||. a || b && c significa a || (b && c). Ante la duda, paréntesis."
  - id: m04-l05-c3
    front: ¿Qué es la evaluación en cortocircuito?
    back: Si el lado izquierdo de && es false, el derecho no se evalúa; si el izquierdo de || es true, tampoco. El resultado ya está decidido.
  - id: m04-l05-c4
    front: ¿Cómo se niega «edad >= 18 && tieneBoleto» según De Morgan?
    back: edad < 18 || !tieneBoleto. Se niega cada parte y && se vuelve ||.
  - id: m04-l05-c5
    front: ¿Por qué no se deben comparar dos Double con ==?
    back: Por la precisión binaria, 0.1 + 0.2 == 0.3 es false. Se compara si la diferencia absoluta es menor que una tolerancia, abs(a - b) < 0.000001.
---

## La idea en una frase

Una comparación hace una pregunta de sí o no y responde con un `Bool`; los operadores lógicos combinan esas respuestas.

## Operadores de comparación

| Operador | Pregunta | Ejemplo | Resultado |
| --- | --- | --- | --- |
| `==` | ¿son iguales? | `5 == 5` | `true` |
| `!=` | ¿son distintos? | `5 != 3` | `true` |
| `<` | ¿es menor? | `3 < 5` | `true` |
| `>` | ¿es mayor? | `3 > 5` | `false` |
| `<=` | ¿es menor o igual? | `5 <= 5` | `true` |
| `>=` | ¿es mayor o igual? | `4 >= 5` | `false` |

El resultado de una comparación es un **valor** de tipo `Bool`. Puedes imprimirlo, guardarlo en una constante y operar con él:

```swift
let edad = 20
let esMayorDeEdad = edad >= 18
print(esMayorDeEdad)
print(edad == 21, edad != 21)
```

```output
true
false true
```

Línea por línea:

1. `edad` vale 20.
2. `edad >= 18` se evalúa como `true` y se guarda en `esMayorDeEdad`, que se infiere como `Bool`.
3. Imprime `true`.
4. `edad == 21` es `false` y `edad != 21` es `true`.

Nombrar una condición, como `esMayorDeEdad`, hace que el código se lea como una frase. Los nombres de `Bool` suelen empezar con *es*, *tiene*, *puede* o *debe*.

### Solo se comparan valores del mismo tipo

```swift no-compila binary operator '==' cannot be applied to operands of type 'String' and 'Int'
print("5" == 5)
```

Swift no considera que el texto `"5"` y el número `5` sean comparables. Convierte uno de los dos, como viste en la lección anterior.

### Una comparación a la vez

En matemáticas escribes 1 < x < 10. En Swift no:

```swift no-compila adjacent operators are in non-associative precedence group 'ComparisonPrecedence'
let x = 5
print(1 < x < 10)
```

Se escribe como dos comparaciones unidas por «y»: `1 < x && x < 10`.

## Operadores lógicos

| Operador | Nombre | Resultado `true` cuando… |
| --- | --- | --- |
| `a && b` | y (AND) | ambos son `true` |
| `a \|\| b` | o (OR) | al menos uno es `true` |
| `!a` | no (NOT) | `a` es `false` |

Tabla de verdad completa:

| a | b | `a && b` | `a \|\| b` | `!a` |
| --- | --- | --- | --- | --- |
| true | true | true | true | false |
| true | false | false | true | false |
| false | true | false | true | true |
| false | false | false | false | true |

El «o» de Swift es **inclusivo**: `true || true` es `true`. En el español cotidiano, «¿café o té?» suele ser exclusivo; en programación, no.

```swift
let edad = 30
let tieneBoleto = true
let esEstudiante = false

print(edad >= 18 && tieneBoleto)
print(esEstudiante || edad < 12)
print(!esEstudiante)
```

```output
true
false
true
```

1. Mayor de edad **y** con boleto: ambas son verdaderas.
2. Estudiante **o** menor de 12: ninguna se cumple.
3. **No** es estudiante: `!false` es `true`.

## Precedencia y paréntesis

Cuando combinas varios operadores, Swift los agrupa así:

1. `!` primero.
2. Luego las comparaciones (`<`, `==`…).
3. Luego `&&`.
4. Al final `||`.

Por eso `a || b && c` significa `a || (b && c)`, y no `(a || b) && c`:

```swift
let a = true
let b = false
let c = false
print(a || b && c)
print((a || b) && c)
```

```output
true
false
```

La misma regla que con la aritmética: si alguien tiene que pensar en la precedencia para entender tu condición, **agrega paréntesis**.

## Evaluación en cortocircuito

En `a && b`, si `a` es `false`, el resultado será `false` sin importar `b`. Swift **no evalúa** `b`. Con `||`, si `a` es `true`, tampoco evalúa `b`.

Esto permite poner primero la condición que protege a la segunda:

```swift
let cantidad = 0
let total = 100
print(cantidad != 0 && total / cantidad > 10)
```

```output
false
```

Como `cantidad != 0` es `false`, la división `total / cantidad` nunca se ejecuta. Si invirtieras el orden, el programa intentaría dividir entre cero y se detendría. El orden de las condiciones importa.

## Negar condiciones: De Morgan

Negar una condición compuesta es una fuente clásica de errores. Las **leyes de De Morgan** dicen:

- `!(a && b)` es lo mismo que `!a || !b`
- `!(a || b)` es lo mismo que `!a && !b`

Ejemplo: «puede entrar» es `edad >= 18 && tieneBoleto`. «**No** puede entrar» no es `edad < 18 && !tieneBoleto`, sino `edad < 18 || !tieneBoleto`: basta con que falte una de las dos cosas.

## Comparar textos

`==` compara textos carácter por carácter, distinguiendo mayúsculas y minúsculas:

```swift
print("casa" == "casa", "casa" == "Casa")
print("a" < "b", "Z" < "a", "10" < "9")
print("árbol" < "zorro")
```

```output
true false
true true true
false
```

- `"casa"` y `"Casa"` son distintos.
- `<` entre textos **no** es el orden alfabético de un diccionario. Compara los caracteres según su orden en Unicode: todas las mayúsculas sin acento van antes que las minúsculas (`"Z" < "a"`), los dígitos se comparan como caracteres (`"10" < "9"`, porque `"1"` va antes que `"9"`) y las letras acentuadas van después de la z (`"árbol" < "zorro"` es `false`).

Para ordenar palabras como lo espera una persona, Foundation tiene comparaciones que respetan el idioma; las verás al trabajar con colecciones y texto.

## Comparar decimales

Por la precisión de `Double` que viste en la lección de tipos, `==` entre decimales calculados es poco confiable. Compara la **diferencia** contra una tolerancia pequeña:

```swift
let resultado = 0.1 + 0.2
print(resultado == 0.3)
print(abs(resultado - 0.3) < 0.000001)
```

```output
false
true
```

`abs(_:)` da el valor absoluto. La tolerancia (aquí una millonésima) depende de tu problema.

## Ejemplo práctico: reglas de un cine

```swift
let edad = 15
let vieneConAdulto = true
let peliculaEsParaAdultos = false
let esMiercoles = true

let puedeEntrar = !peliculaEsParaAdultos || edad >= 18
let necesitaAcompañante = edad < 13 && !vieneConAdulto
let tieneDescuento = esMiercoles || edad < 12 || edad >= 60

print("Puede entrar:", puedeEntrar && !necesitaAcompañante)
print("Descuento:", tieneDescuento)
```

```output
Puede entrar: true
Descuento: true
```

Cada regla del negocio es una constante con nombre. La condición final se lee casi como el reglamento: «puede entrar y no necesita acompañante». Si una regla cambia, cambias una línea.

## Errores frecuentes

> [!error] error: use of '=' in a boolean context, did you mean '=='?
> Escribiste `=` donde querías comparar. `=` asigna; `==` compara.

> [!error] error: adjacent operators are in non-associative precedence group 'ComparisonPrecedence'
> Escribiste dos comparaciones seguidas, como `1 < x < 10`. Únelas con `&&`: `1 < x && x < 10`.

> [!error] Bordes equivocados
> «Entre 18 y 64 años, inclusive» es `edad >= 18 && edad <= 64`. Con `>` o `<` pierdes los extremos. Prueba siempre los bordes, como aprendiste en el Módulo 2.

> [!error] Negar mal una condición compuesta
> La negación de `a && b` es `!a || !b`. Cambiar solo los signos de comparación sin cambiar `&&` por `||` produce una condición distinta.

> [!error] Ordenar textos con < esperando orden alfabético
> `"Zapato" < "auto"` es `true` y `"árbol" < "zorro"` es `false`. `<` compara caracteres Unicode, no el orden de un diccionario.

````exercise
id: m04-l05-e1
type: comprension
prompt: ¿Cuál es la condición correcta para «la temperatura está entre 18 y 25 grados, inclusive»?
choices:
  - text: "`18 <= temperatura <= 25`"
    correct: false
    why: Swift no permite encadenar comparaciones; no compila.
  - text: "`temperatura >= 18 && temperatura <= 25`"
    correct: true
    why: Dos comparaciones que deben cumplirse a la vez, incluyendo ambos extremos.
  - text: "`temperatura > 18 && temperatura < 25`"
    correct: false
    why: Excluye 18 y 25, que el enunciado incluye.
  - text: "`temperatura >= 18 || temperatura <= 25`"
    correct: false
    why: Con ||, cualquier número cumple al menos una de las dos. Siempre es true.
solution: |
  **`temperatura >= 18 && temperatura <= 25`.** «Entre» exige las dos condiciones a la vez, así que se unen con `&&`. «Inclusive» pide `>=` y `<=`. Con `||` la condición sería siempre verdadera: 100 es mayor que 18, y −5 es menor que 25.
````

````exercise
id: m04-l05-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea.
code: |
  let edad = 17
  let tienePermiso = true
  print(edad >= 18)
  print(edad >= 18 || tienePermiso)
  print(!(edad < 18) && tienePermiso)
  print(edad == 17 && !tienePermiso || edad > 10)
  print("casa" == "Casa", "a" < "b")
output: |
  false
  true
  false
  true
  false true
hints:
  - "Línea 5: primero el paréntesis, después !, después &&."
  - "Línea 6: && va antes que ||."
solution: |
  ```output
  false
  true
  false
  true
  false true
  ```

  1. 17 no es mayor o igual que 18: `false`.
  2. `false || true`: `true`.
  3. `edad < 18` es `true`; negado, `false`; `false && true` es `false`.
  4. Se agrupa como `(edad == 17 && !tienePermiso) || edad > 10`: `(true && false) || true` es `true`.
  5. Las mayúsculas importan: `false`. `"a"` va antes que `"b"`: `true`.
````

````exercise
id: m04-l05-e3
type: completar
prompt: |
  Completa las condiciones. Un usuario puede publicar si tiene la sesión iniciada **y** su cuenta **no** está suspendida. Muestra un aviso si **no** puede publicar.
code: |
  let sesionIniciada = true
  let cuentaSuspendida = false
  let puedePublicar = sesionIniciada [[1]] [[2]]cuentaSuspendida
  let mostrarAviso = !sesionIniciada [[3]] cuentaSuspendida
  print(puedePublicar, mostrarAviso)
blanks:
  - id: "1"
    answers: ["&&"]
  - id: "2"
    answers: ["!"]
  - id: "3"
    answers: ["||"]
solution: |
  ```swift
  let sesionIniciada = true
  let cuentaSuspendida = false
  let puedePublicar = sesionIniciada && !cuentaSuspendida
  let mostrarAviso = !sesionIniciada || cuentaSuspendida
  print(puedePublicar, mostrarAviso)
  ```

  ```output
  true false
  ```

  `mostrarAviso` es la negación de `puedePublicar`. Por De Morgan, `!(sesionIniciada && !cuentaSuspendida)` es `!sesionIniciada || cuentaSuspendida`: el `&&` se vuelve `||` y cada parte se niega (y `!!cuentaSuspendida` es `cuentaSuspendida`). También sería correcto escribir `let mostrarAviso = !puedePublicar`, que es más corto y no puede desincronizarse.
````

````exercise
id: m04-l05-e4
type: errores
prompt: |
  Este programa decide si un pedido tiene envío gratis: compras de 500 pesos o más, **o** cualquier compra si el cliente es premium. También quiere saber si el total coincide con un cupón de 99.9. No compila y tiene errores de lógica. Identifica los problemas reales y escribe la versión corregida.
code: |
  let total = 99.9
  let esPremium = false
  let envioGratis = total > 500 && esPremium
  if total = 99.9 {
      print("Cupón aplicado")
  }
  print(envioGratis)
choices:
  - text: "La regla usa && pero el enunciado dice «o»."
    correct: true
    why: Con && solo los clientes premium con compras grandes tendrían envío gratis.
  - text: "La regla usa > pero el enunciado dice «500 o más»."
    correct: true
    why: Una compra de exactamente 500 debe tener envío gratis; hace falta >=.
  - text: "La línea 4 usa = en lugar de ==."
    correct: true
    why: "Error de compilación: use of '=' in a boolean context."
  - text: "Comparar 99.9 con == es frágil si total es el resultado de un cálculo."
    correct: true
    why: Aquí funciona porque total es el mismo literal, pero con un total calculado podría fallar. Conviene una tolerancia.
  - text: "esPremium no puede usarse con && porque es una constante."
    correct: false
    why: Ser constante no tiene relación con poder usarse en una condición.
rubric:
  - Cambié la regla a total >= 500 || esPremium.
  - Corregí = por == o, mejor, usé una comparación con tolerancia.
  - Probé mentalmente los bordes 499.99, 500 y un cliente premium con total pequeño.
solution: |
  ```swift
  let total = 99.9
  let esPremium = false
  let envioGratis = total >= 500 || esPremium
  let coincideConCupon = abs(total - 99.9) < 0.000001
  print(envioGratis, coincideConCupon)
  ```

  ```output
  false true
  ```

  El `if` lo estudiarás en el siguiente módulo; aquí la comparación se guarda en una constante con nombre. La regla corregida da envío gratis con 500 exactos y a cualquier cliente premium. La comparación del cupón usa una tolerancia porque en un programa real `total` vendría de sumar precios decimales.
````

````exercise
id: m04-l05-e5
type: resolver
prompt: |
  Un año es bisiesto si es divisible entre 4, excepto los divisibles entre 100 que no lo son entre 400 (Módulo 2). Escribe **una sola expresión booleana** con `%`, `==`, `!=`, `&&` y `||` que lo calcule, guárdala en `esBisiesto` y pruébala con 1900, 2000, 2023 y 2024. Imprime cada año con su resultado.
starter: |
  let año = 2024
hints:
  - "Bisiesto si: (divisible entre 4 y no entre 100) o (divisible entre 400)."
  - "«Divisible entre n» es año % n == 0."
  - Para probar varios años sin ciclos todavía, puedes repetir el bloque con otra constante o cambiar el valor y volver a ejecutar.
rubric:
  - La expresión es (año % 4 == 0 && año % 100 != 0) || año % 400 == 0 o una equivalente.
  - Usé paréntesis para dejar clara la agrupación.
  - "Probé los cuatro años y obtuve: 1900 false, 2000 true, 2023 false, 2024 true."
solution: |
  ```swift
  let años = [1900, 2000, 2023, 2024]
  for año in años {
      let esBisiesto = (año % 4 == 0 && año % 100 != 0) || año % 400 == 0
      print(año, esBisiesto)
  }
  ```

  ```output
  1900 false
  2000 true
  2023 false
  2024 true
  ```

  La expresión dice: «divisible entre 4 pero no entre 100, **o** divisible entre 400». Los paréntesis no son obligatorios, porque `&&` va antes que `||`, pero dejan la regla a la vista. El ciclo `for` solo repite la prueba con cada año; lo estudiarás en el siguiente módulo. Compárala con el algoritmo de la lección de casos límite: es la misma regla, escrita como un solo valor `Bool` en lugar de una serie de decisiones.
````

## Resumen

- `==`, `!=`, `<`, `>`, `<=` y `>=` comparan valores del mismo tipo y producen un `Bool`.
- `&&` exige ambas condiciones, `||` al menos una (inclusivo), `!` invierte.
- Precedencia: `!`, comparaciones, `&&`, `||`. Usa paréntesis para que la intención sea obvia.
- `&&` y `||` evalúan en cortocircuito: pon primero la condición que protege a la segunda.
- Negar `a && b` da `!a || !b` (De Morgan).
- `<` entre textos compara caracteres Unicode, no orden alfabético; los `Double` se comparan con tolerancia.
