---
id: m04-l02
title: "Constantes y variables: let y var"
description: Das nombre a los valores con let y var, decides cuál usar, entiendes qué significa asignar y aprendes las reglas y convenciones para nombrar. Desaparecen los números mágicos de tus programas.
module: m04
order: 2
level: inicial
minutes: 45
prerequisites: [m04-l01]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Declarar constantes con let y variables con var.
  - Elegir entre let y var y justificar la elección.
  - Usar la asignación y los operadores compuestos +=, -=, *= y /=.
  - Nombrar constantes y variables según las reglas del lenguaje y las convenciones de Swift.
  - Corregir los errores de compilación típicos de let y var.
terms:
  - term: Constante
    definition: Nombre asociado a un valor que no puede cambiar después de asignarse. En Swift se declara con let.
  - term: Variable
    definition: Nombre asociado a un valor que puede cambiar. En Swift se declara con var.
  - term: Declaración
    definition: La instrucción que crea un nombre nuevo, por ejemplo let precio = 45.
  - term: Asignación
    definition: Guardar un valor en un nombre con el operador =. En Swift, = asigna; para comparar se usa ==.
  - term: Inicialización
    definition: La primera asignación de un valor a una constante o variable. Swift no permite leer un nombre antes de inicializarlo.
  - term: Operador de asignación compuesta
    definition: Operador que combina una operación con la asignación, como += en total += 5, equivalente a total = total + 5.
  - term: camelCase
    definition: Convención de nombres que une palabras empezando cada una, salvo la primera, con mayúscula, como precioConDescuento.
mastery:
  - Reescribir un programa con números repetidos usando constantes con nombre, sin cambiar su salida.
  - Decir, para cada nombre de un programa, si debe ser let o var y por qué.
  - Predecir la salida de un programa que reasigna una variable con =, += y *=.
  - Corregir los errores «is a 'let' constant», «used before being initialized» e «invalid redeclaration» sin ayuda del compilador.
resources: [swift-book-basics, swift-book-basic-operators]
cards:
  - id: m04-l02-c1
    front: ¿Qué diferencia hay entre let y var?
    back: let declara una constante, cuyo valor no puede cambiar después de asignarse. var declara una variable, que puede reasignarse.
  - id: m04-l02-c2
    front: ¿Cuál conviene usar por defecto, let o var?
    back: let. Usa var solo si el valor realmente va a cambiar. El compilador te avisa cuando una var nunca cambia.
  - id: m04-l02-c3
    front: ¿Qué significa `total += 5`?
    back: Lo mismo que total = total + 5. Calcula con el valor actual de total y guarda el resultado en total. Solo funciona si total es var.
  - id: m04-l02-c4
    front: ¿Qué convención de nombres usa Swift para constantes y variables?
    back: camelCase, empezando en minúscula y con nombres descriptivos, como precioConDescuento. Swift distingue mayúsculas de minúsculas.
---

## La idea en una frase

Una constante o una variable es un **nombre** para un valor, y el nombre cuenta qué significa ese valor.

## El problema: números mágicos

Al final de la lección anterior escribiste:

```swift
print("Café:", 45)
print("Pan:", 28)
print("Total:", 45 + 28)
```

```output
Café: 45
Pan: 28
Total: 73
```

Funciona, pero `45` aparece dos veces. Si el café sube de precio, tienes que encontrar y cambiar cada 45, y esperar que ningún otro 45 signifique otra cosa. Un número que aparece en el código sin explicación se llama **número mágico**.

## Constantes: let

**Definición sencilla:** `let` le pone nombre a un valor que no va a cambiar.

**Definición precisa:** `let nombre = valor` declara una **constante**: un nombre asociado a un valor que, una vez asignado, no puede reasignarse. El compilador lo garantiza.

```swift
let precioCafe = 45
let precioPan = 28
print("Café:", precioCafe)
print("Pan:", precioPan)
print("Total:", precioCafe + precioPan)
```

```output
Café: 45
Pan: 28
Total: 73
```

Línea por línea:

1. `let precioCafe = 45` crea la constante `precioCafe` con el valor 45. El `=` aquí **asigna**: guarda el valor de la derecha en el nombre de la izquierda.
2. Lo mismo para `precioPan`.
3. `print` recibe el **valor** de la constante. Escribir `precioCafe` en una expresión equivale a escribir 45.
4. Igual con el pan.
5. `precioCafe + precioPan` se evalúa como `45 + 28`.

Ahora, si el café cuesta 50, cambias una línea y todo el programa se actualiza. Y quien lea `precioCafe + precioPan` entiende el cálculo sin adivinar qué era 45.

## Variables: var

**Definición sencilla:** `var` le pone nombre a un valor que puede cambiar.

**Definición precisa:** `var nombre = valor` declara una **variable**. Después de la declaración puedes asignarle un valor nuevo con `nombre = otroValor`.

```swift
var puntos = 0
print(puntos)
puntos = 10
print(puntos)
puntos = puntos + 5
print(puntos)
```

```output
0
10
15
```

1. `var puntos = 0` declara la variable con valor inicial 0.
2. Imprime 0.
3. `puntos = 10` **reasigna**: el valor anterior se pierde y ahora vale 10. Sin `var` ni `let`, porque el nombre ya existe.
4. Imprime 10.
5. `puntos = puntos + 5` primero calcula el lado derecho con el valor **actual** (10 + 5) y después guarda 15. Es la flecha `←` del pseudocódigo del Módulo 2.
6. Imprime 15.

### Operadores de asignación compuesta

Actualizar una variable a partir de su propio valor es tan común que hay atajos:

| Escritura | Equivale a |
| --- | --- |
| `x += 3` | `x = x + 3` |
| `x -= 3` | `x = x - 3` |
| `x *= 3` | `x = x * 3` |
| `x /= 3` | `x = x / 3` |

```swift
var saldo = 100
saldo += 50
saldo -= 30
saldo *= 2
print(saldo)
```

```output
240
```

100 + 50 = 150; 150 − 30 = 120; 120 × 2 = 240.

## ¿let o var?

**Usa `let` por defecto.** Cambia a `var` solo cuando el valor realmente tenga que cambiar.

No es una cuestión de estilo. Una constante es una garantía: en cualquier línea del programa, `precioCafe` vale lo mismo. Con una variable tienes que revisar todo el código para saber qué valor tiene en cada momento. Menos variables significan menos cosas que pueden salir mal.

El compilador te ayuda. Si declaras una `var` dentro de un bloque y nunca la cambias, te advierte:

```swift advertencia variable 'precio' was never mutated; consider changing to 'let' constant
do {
    var precio = 45
    print(precio)
}
```

```output
45
```

`do { … }` solo agrupa líneas en un bloque; lo usamos aquí para que el compilador revise el nombre como lo haría dentro de una función. En código escrito directamente en `main.swift` o en un archivo suelto, los nombres son globales y el compilador no da esta advertencia.

## Reglas y convenciones para nombrar

**Reglas del lenguaje** (si no las cumples, no compila):

- Un nombre no puede empezar con un número: `2do` no es válido; `segundo` sí.
- No puede tener espacios: `mi nombre` no es válido.
- Swift distingue mayúsculas de minúsculas: `edad` y `Edad` son nombres distintos.
- Puede contener letras con acento, ñ y otros caracteres Unicode: `año` es válido.

**Convenciones** (compila igual, pero el código se vuelve difícil de leer si no las sigues):

- **camelCase** empezando en minúscula: `precioConDescuento`, `totalDeArticulos`.
- Nombres que dicen **qué es el valor**, no qué tipo tiene: `edad`, no `numero`; `precioCafe`, no `p`.
- Una letra está bien solo en contextos muy cortos y convencionales, como `i` para un contador en un ciclo.

> [!nota]
> Este curso usa nombres en español con acentos cuando el ejemplo lo pide (`año`, `números`) porque Swift lo permite. En equipos profesionales es común nombrar en inglés; lo importante es ser consistente dentro de un proyecto.

## Ejemplo práctico: un ticket con descuento

```swift
let precioCafe = 45
let precioPan = 28
let cantidadDeCafes = 2
let descuentoEnPesos = 10

var total = precioCafe * cantidadDeCafes
total += precioPan
total -= descuentoEnPesos

print("Subtotal sin descuento:", precioCafe * cantidadDeCafes + precioPan)
print("Descuento:", descuentoEnPesos)
print("Total:", total)
```

```output
Subtotal sin descuento: 118
Descuento: 10
Total: 108
```

Los precios, la cantidad y el descuento son `let`: son datos del problema y no cambian. Solo `total` es `var`, porque se construye por pasos. Cada número aparece **una vez**, con un nombre que lo explica.

## Errores frecuentes

> [!error] error: cannot assign to value: 'precio' is a 'let' constant
> Intentaste reasignar una constante. Si el valor de verdad debe cambiar, declárala con `var`. Si no, el error te salvó de un cambio accidental.

> [!error] error: left side of mutating operator isn't mutable: 'precio' is a 'let' constant
> Lo mismo, con `+=`, `-=`, `*=` o `/=`: solo funcionan sobre una `var`.

> [!error] error: variable 'x' used before being initialized
> Declaraste un nombre sin valor (`var x: Int`) y lo leíste antes de asignarle uno. Swift nunca te deja leer basura: asigna un valor antes de usarlo.

> [!error] error: invalid redeclaration of 'total'
> Escribiste `let total` o `var total` dos veces. Para cambiar el valor de una variable que ya existe, asígnale sin `var`: `total = 5`.

> [!error] Confundir = con ==
> `=` asigna. Para preguntar si dos valores son iguales se usa `==`, que verás en la lección de operadores de comparación.

````exercise
id: m04-l02-e1
type: comprension
prompt: Un programa guarda el precio de un producto (fijo), la cantidad que el cliente va agregando al carrito y el total que se recalcula con cada producto. ¿Qué declaraciones son las más adecuadas?
choices:
  - text: "`let precio`, `var cantidad`, `var total`"
    correct: true
    why: El precio no cambia; cantidad y total sí.
  - text: "`var precio`, `var cantidad`, `var total`"
    correct: false
    why: Funciona, pero precio no cambia y debe ser let. Swift te advertiría.
  - text: "`let precio`, `let cantidad`, `let total`"
    correct: false
    why: Cantidad y total cambian; con let no compilaría al reasignarlos.
  - text: "`var precio`, `let cantidad`, `let total`"
    correct: false
    why: Es justo al revés de lo que el problema necesita.
solution: |
  **`let precio`, `var cantidad`, `var total`.** La regla es `let` por defecto y `var` solo para lo que cambia. El precio es un dato fijo; la cantidad y el total se actualizan. Declarar todo con `var` compilaría, pero perderías la garantía de que el precio no se modifica por accidente.
````

````exercise
id: m04-l02-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea.
code: |
  var puntos = 10
  let bono = 5
  puntos = puntos + bono
  print(puntos)
  puntos += 2
  puntos *= 2
  print(puntos)
  let nivel = puntos / 10
  print(nivel, puntos % 10)
output: |
  15
  34
  3 4
hints:
  - "Cada asignación usa el valor actual de puntos."
  - "puntos / 10 es una división entera."
solution: |
  ```output
  15
  34
  3 4
  ```

  | Línea | puntos | Imprime |
  | --- | --- | --- |
  | `var puntos = 10` | 10 | |
  | `puntos = puntos + bono` | 15 | |
  | `print(puntos)` | 15 | 15 |
  | `puntos += 2` | 17 | |
  | `puntos *= 2` | 34 | |
  | `print(puntos)` | 34 | 34 |

  `nivel` es `34 / 10`, división entera: **3**. `34 % 10` es el residuo: **4**. `print` los separa con un espacio.
````

````exercise
id: m04-l02-e3
type: completar
prompt: |
  Completa el programa para que compile e imprima exactamente:

  ```output
  Saldo: 150
  ```
code: |
  [[1]] deposito = 50
  [[2]] saldo = 100
  saldo [[3]] deposito
  print("Saldo:", saldo)
blanks:
  - id: "1"
    answers: ["let"]
  - id: "2"
    answers: ["var"]
  - id: "3"
    answers: ["+="]
solution: |
  ```swift
  let deposito = 50
  var saldo = 100
  saldo += deposito
  print("Saldo:", saldo)
  ```

  `deposito` no cambia: `let`. `saldo` se modifica en la tercera línea: tiene que ser `var`, o `+=` no compila. `saldo += deposito` equivale a `saldo = saldo + deposito`.
````

````exercise
id: m04-l02-e4
type: errores
prompt: Este programa no compila. Identifica los problemas reales y escribe la versión corregida.
code: |
  let limite = 3
  var intentos
  intentos = 0
  intentos += 1
  limite = 5
  var intentos = 2
  print(Intentos, limite)
choices:
  - text: "La línea 2 declara una var sin valor ni tipo; el compilador no sabe qué tipo tiene."
    correct: true
    why: "El mensaje es type annotation missing in pattern. Lo más simple es var intentos = 0."
  - text: "La línea 5 reasigna una constante."
    correct: true
    why: "limite es let: cannot assign to value: 'limite' is a 'let' constant."
  - text: "La línea 6 vuelve a declarar intentos."
    correct: true
    why: "invalid redeclaration of 'intentos'. Para cambiar su valor basta intentos = 2."
  - text: "En la línea 7, Intentos con mayúscula no es el mismo nombre que intentos."
    correct: true
    why: Swift distingue mayúsculas de minúsculas.
  - text: "La línea 4 está mal: += solo funciona con números decimales."
    correct: false
    why: "+= funciona con enteros. El problema de intentos está en su declaración."
rubric:
  - Declaré intentos con valor inicial en una sola línea.
  - Decidí si limite debía cambiar y usé let o var en consecuencia.
  - Eliminé la segunda declaración de intentos.
  - Usé el mismo nombre, con la misma capitalización, en todo el programa.
  - Mi versión compila e imprime dos números.
solution: |
  Una versión corregida, suponiendo que el límite sí debía cambiar a 5:

  ```swift
  var limite = 3
  var intentos = 0
  intentos += 1
  limite = 5
  intentos = 2
  print(intentos, limite)
  ```

  ```output
  2 5
  ```

  Si el límite no debía cambiar, la corrección es la opuesta: deja `let limite = 3` y borra `limite = 5`. El compilador no puede saber cuál era tu intención; tú sí. Observa también que la declaración en dos pasos (`var intentos` y luego `intentos = 0`) necesitaría una anotación de tipo, que verás en la lección de anotaciones; declarar e inicializar en la misma línea es más simple.
````

````exercise
id: m04-l02-e5
type: refactorizar
prompt: |
  Este programa calcula cuánto cuesta una membresía de gimnasio por un año, con inscripción. Reescríbelo sin números mágicos, con constantes de nombres claros, sin cambiar la salida.
code: |
  print("Mensualidades:", 450 * 12)
  print("Inscripción:", 300)
  print("Total del primer año:", 450 * 12 + 300)
rubric:
  - Cada número aparece una sola vez, en una constante con nombre.
  - Los nombres usan camelCase y explican el significado.
  - Usé let para todos los valores que no cambian.
  - La salida es idéntica a la original.
solution: |
  ```swift
  let mensualidad = 450
  let mesesPorAño = 12
  let inscripcion = 300

  let costoMensualidades = mensualidad * mesesPorAño
  print("Mensualidades:", costoMensualidades)
  print("Inscripción:", inscripcion)
  print("Total del primer año:", costoMensualidades + inscripcion)
  ```

  ```output
  Mensualidades: 5400
  Inscripción: 300
  Total del primer año: 5700
  ```

  Todo es `let`: ningún valor cambia después de calcularse. La constante intermedia `costoMensualidades` evita repetir `mensualidad * mesesPorAño` y da nombre a un concepto del problema. Si la mensualidad sube, cambias una línea.
````

````exercise
id: m04-l02-e6
type: resolver
prompt: |
  Escribe un programa que **intercambie** los valores de dos variables, `a = 3` y `b = 8`, e imprima:

  ```output
  Antes: 3 8
  Después: 8 3
  ```

  No puedes escribir los números 3 y 8 en ningún lugar salvo en la declaración inicial.
starter: |
  var a = 3
  var b = 8
  print("Antes:", a, b)
hints:
  - "Si haces a = b primero, el 3 se pierde."
  - Guarda uno de los valores en una constante temporal antes de sobrescribirlo.
rubric:
  - El programa imprime exactamente las dos líneas.
  - Usé una constante temporal para no perder un valor.
  - No escribí 3 ni 8 fuera de la declaración.
  - Expliqué por qué a = b seguido de b = a no funciona.
solution: |
  ```swift
  var a = 3
  var b = 8
  print("Antes:", a, b)
  let temporal = a
  a = b
  b = temporal
  print("Después:", a, b)
  ```

  ```output
  Antes: 3 8
  Después: 8 3
  ```

  Con `a = b` y luego `b = a`, ambas terminarían en 8: la primera asignación borra el 3 antes de que puedas copiarlo. La constante `temporal` lo guarda. Es el mismo problema del orden de asignaciones que viste con Fibonacci en la lección de tablas de seguimiento. (Swift también permite `(a, b) = (b, a)` con tuplas, que estudiarás en el módulo de funciones.)
````

## Resumen

- `let` declara una constante; `var`, una variable. Usa `let` por defecto.
- `=` asigna: calcula el lado derecho con los valores actuales y guarda el resultado.
- `+=`, `-=`, `*=` y `/=` actualizan una `var` a partir de su propio valor.
- Swift no te deja leer un nombre antes de inicializarlo ni reasignar una constante.
- Nombres en camelCase, empezando en minúscula, que digan qué significa el valor. Sin números mágicos.
