---
id: m04-l03
title: "Tipos de datos e inferencia de tipos"
description: Todo valor en Swift tiene un tipo y el tipo de un nombre no cambia nunca. Conoces Int, Double, Bool, String y Character, ves cómo Swift deduce los tipos por ti y por qué 0.1 + 0.2 no es exactamente 0.3.
module: m04
order: 3
level: inicial
minutes: 45
prerequisites: [m04-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Explicar qué es un tipo y qué decide sobre un valor.
  - Reconocer los tipos básicos Int, Double, Bool, String y Character.
  - Predecir qué tipo infiere Swift para una constante o variable a partir de su valor inicial.
  - Comprobar el tipo de un valor con type(of:).
  - Explicar las limitaciones de Int y Double, el rango finito y la precisión de los decimales.
terms:
  - term: Tipo
    definition: La clase de valor que guarda un nombre. Decide qué valores son válidos y qué operaciones se pueden hacer con él.
  - term: Int
    definition: Número entero con signo. En iPhone y Mac actuales ocupa 64 bits, de −9223372036854775808 a 9223372036854775807.
  - term: Double
    definition: Número decimal de punto flotante de 64 bits. Tiene unos 15 o 16 dígitos significativos de precisión.
  - term: Bool
    definition: Valor lógico, true o false.
  - term: String
    definition: Texto, una secuencia de caracteres.
  - term: Character
    definition: Un solo carácter tal como lo percibe una persona, por ejemplo "a", "ñ" o un emoji.
  - term: Inferencia de tipos
    definition: Mecanismo por el que el compilador deduce el tipo de un nombre a partir del valor con el que se inicializa.
  - term: Seguridad de tipos
    definition: Garantía de que el compilador no permite usar un valor como si fuera de otro tipo sin una conversión explícita.
mastery:
  - Decir sin ejecutar el tipo que infiere Swift para let a = 7, let b = 7.0, let c = "7" y let d = 7 > 2.
  - Explicar por qué var x = 5 seguido de x = 2.5 no compila.
  - Explicar por qué 0.1 + 0.2 == 0.3 es false y qué implica para cálculos con dinero.
  - Elegir el tipo adecuado para edad, precio, nombre, inicial y «¿está activo?».
resources: [swift-book-basics, swift-book-basic-operators]
cards:
  - id: m04-l03-c1
    front: ¿Qué tipo infiere Swift para `let x = 3.0` y para `let y = 3`?
    back: x es Double, porque el literal tiene punto decimal. y es Int.
  - id: m04-l03-c2
    front: ¿Puede cambiar el tipo de una variable después de declararla?
    back: No. El tipo se fija al declarar. var x = 5 es Int para siempre; x = 2.5 no compila.
  - id: m04-l03-c3
    front: ¿Por qué `0.1 + 0.2 == 0.3` es false en Swift?
    back: Double guarda los números en binario, y 0.1, 0.2 y 0.3 no tienen representación binaria exacta. La suma da 0.30000000000000004.
  - id: m04-l03-c4
    front: ¿Para qué sirve `type(of:)`?
    back: "Devuelve el tipo de un valor mientras el programa corre. print(type(of: 42)) imprime Int."
  - id: m04-l03-c5
    front: ¿Qué diferencia hay entre String y Character?
    back: String es un texto de cualquier longitud. Character es exactamente un carácter percibido, como "a" o "é".
---

## La idea en una frase

Para Swift no existe «un valor» a secas: existe un **entero**, un **decimal**, un **texto**… y cada uno tiene reglas propias que el compilador hace cumplir.

## Qué es un tipo

**Definición sencilla:** el tipo dice qué clase de dato es un valor.

**Definición precisa:** un tipo define el conjunto de valores posibles y las operaciones permitidas. Un `Int` puede ser 42 o −7, pero no 3.5 ni "hola"; con `Int` puedes usar `%`, y con un `String`, no.

Viste los tipos por primera vez con los literales en la lección de `print`. Ahora los conectas con los nombres: cuando declaras una constante o una variable, su tipo queda fijo.

## Los tipos básicos

| Tipo | Qué guarda | Literales | Ejemplo de uso |
| --- | --- | --- | --- |
| `Int` | Enteros | `42`, `-7`, `1_000` | Edad, cantidad, posición |
| `Double` | Decimales | `3.5`, `0.1`, `2.0` | Distancia, temperatura, promedio |
| `Bool` | Verdadero o falso | `true`, `false` | ¿Está activo? ¿Aprobó? |
| `String` | Texto | `"Hola"`, `""` | Nombre, mensaje |
| `Character` | Un carácter | `"a"`, `"ñ"` | Una inicial |

Existen más tipos numéricos, como `Float` (decimal de 32 bits, menos preciso) y enteros de tamaño fijo como `Int8` o `UInt8`. Para empezar, usa `Int` para enteros y `Double` para decimales: son los que la biblioteca estándar y los frameworks de Apple usan por defecto.

## Inferencia de tipos

**Definición sencilla:** Swift adivina el tipo por ti, sin adivinar mal.

**Explicación técnica:** cuando escribes `let edad = 30`, no dijiste que `edad` es un `Int`. El compilador lo **infiere** del valor inicial: `30` es un literal entero y el tipo por defecto de un literal entero es `Int`. No hay nada mágico ni dinámico: ocurre al compilar, y a partir de ahí `edad` es un `Int` para siempre.

```swift
let edad = 30
let estatura = 1.72
let nombre = "Ana"
let activo = true
print(type(of: edad), type(of: estatura), type(of: nombre), type(of: activo))
```

```output
Int Double String Bool
```

Línea por línea:

1. `30` es un literal entero: `edad` es `Int`.
2. `1.72` tiene punto decimal: `estatura` es `Double`.
3. `"Ana"` va entre comillas: `nombre` es `String`.
4. `true` es un literal booleano: `activo` es `Bool`.
5. `type(of:)` devuelve el tipo de un valor mientras el programa corre. Úsalo para comprobar lo que crees que inferiste.

### El tipo de una expresión

La inferencia también aplica a expresiones:

```swift
let a = 5
let b = 2.0
print(type(of: a * 2), type(of: b * 2), type(of: 3 + 0.5))
```

```output
Int Double Double
```

- `a * 2`: `Int` por `Int` da `Int`.
- `b * 2`: el literal `2` se adapta a `Double` porque `b` es `Double`.
- `3 + 0.5`: los **literales** no tienen un tipo fijo hasta que se usan; aquí ambos se interpretan como `Double`.

Esa flexibilidad es solo de los literales. Un **nombre** ya tiene su tipo, y Swift no lo cambia: `a * b` no compila, porque `a` es `Int` y `b` es `Double`. Lo resolverás con conversiones explícitas en la siguiente lección.

## El tipo de un nombre no cambia

```swift no-compila cannot assign value of type 'Double' to type 'Int'
var x = 5
x = 2.5
```

`x` se infirió como `Int`. Asignarle `2.5` sería cambiar de tipo, y Swift lo prohíbe. A esto se le llama **seguridad de tipos**: el compilador garantiza que, en cualquier línea, `x` es un entero. Si quieres que admita decimales, declárala desde el principio con un valor decimal, `var x = 5.0`, o con una anotación, como verás en la próxima lección.

## Los límites de los números

### Int tiene un rango

```swift
print(Int.max)
print(Int.min)
```

```output
9223372036854775807
-9223372036854775808
```

En iPhone y Mac actuales, `Int` ocupa 64 bits. Si una operación se pasa de ese rango, Swift no da un resultado incorrecto en silencio: si lo detecta al compilar es un error de compilación, y si ocurre durante la ejecución, el programa se detiene. Lo viste en la lección de errores del Módulo 3.

### Double es preciso, pero no exacto

```swift
print(0.1 + 0.2)
print(0.1 + 0.2 == 0.3)
```

```output
0.30000000000000004
false
```

`Double` guarda los números en **binario**. Así como 1/3 no tiene una representación decimal exacta (0.3333…), 0.1 no tiene una representación binaria exacta. El error es diminuto, pero existe, y por eso comparar decimales con `==` es peligroso. (`==` compara si dos valores son iguales; lo verás a fondo en la lección de operadores de comparación.)

> [!aviso]
> No uses `Double` para dinero cuando necesites exactitud al centavo. Una opción común es trabajar en centavos con `Int` (4550 en lugar de 45.50). Foundation ofrece además el tipo `Decimal`, que estudiarás más adelante.

## String y Character

Un `String` es un texto de cualquier longitud, incluso vacío (`""`). Un `Character` es **un solo** carácter. Como ambos se escriben con comillas dobles, un literal como `"a"` se infiere como `String` salvo que indiques lo contrario con una anotación:

```swift
let inicial: Character = "A"
print(inicial, type(of: inicial))
```

```output
A Character
```

```swift no-compila cannot convert value of type 'String' to specified type 'Character'
let inicial: Character = "AB"
```

`"AB"` son dos caracteres y no cabe en un `Character`. La sintaxis `: Character` es una **anotación de tipo**, el tema de la siguiente lección.

## Ejemplo práctico: la ficha de un producto

```swift
let nombre = "Audífonos"
let precioEnCentavos = 89_900
let unidadesEnInventario = 12
let calificacion = 4.6
let disponible = true

print(nombre, type(of: nombre))
print(precioEnCentavos, type(of: precioEnCentavos))
print(unidadesEnInventario, type(of: unidadesEnInventario))
print(calificacion, type(of: calificacion))
print(disponible, type(of: disponible))
```

```output
Audífonos String
89900 Int
12 Int
4.6 Double
true Bool
```

Cada decisión de tipo tiene una razón: el precio en **centavos enteros** para no perder exactitud; las unidades son enteras porque no se vende media unidad; la calificación es un promedio y necesita decimales; `disponible` solo puede ser sí o no. Observa que `print` muestra `89_900` como `89900`: el guion bajo solo existe en el código fuente.

## Errores frecuentes

> [!error] error: cannot assign value of type 'Double' to type 'Int'
> La variable se infirió como `Int` por su valor inicial. Si debe guardar decimales, inicialízala con un decimal (`0.0`) o anota su tipo.

> [!error] error: cannot assign value of type 'Int' to type 'String'
> Intentaste guardar un número en un nombre de tipo `String`. Si querías el texto, usa comillas o una conversión explícita.

> [!error] Comparar decimales con ==
> `0.1 + 0.2 == 0.3` es `false`. Compara decimales con una tolerancia o trabaja con enteros (por ejemplo, centavos).

> [!error] Inicializar con 0 algo que debe ser decimal
> `var promedio = 0` crea un `Int`. Más adelante, `promedio = 7.5` no compila. Escribe `var promedio = 0.0`.

````exercise
id: m04-l03-e1
type: comprension
multiple: true
prompt: ¿Cuáles de estas declaraciones crean un `Double`? Selecciona todas las que apliquen.
choices:
  - text: "`let a = 10.0`"
    correct: true
    why: El literal tiene punto decimal.
  - text: "`let b = 10`"
    correct: false
    why: Literal entero, se infiere Int.
  - text: "`let c = 10 / 4`"
    correct: false
    why: Dos literales enteros; división entera, Int con valor 2.
  - text: "`let d = 10 / 4.0`"
    correct: true
    why: Un literal decimal hace que ambos se interpreten como Double; vale 2.5.
  - text: "`let e = \"10.0\"`"
    correct: false
    why: Entre comillas es un String.
solution: |
  Son `Double` **`a`** y **`d`**. En `10 / 4.0`, como los literales no tienen tipo fijo, Swift interpreta ambos como `Double` y el resultado es 2.5. `10 / 4` es división entera (2, `Int`). `"10.0"` es texto.
````

````exercise
id: m04-l03-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea.
code: |
  let piezas = 7
  let cajas = 2
  let pesoPorPieza = 1.5
  print(piezas / cajas)
  print(type(of: piezas / cajas))
  print(pesoPorPieza * 4)
  print(type(of: pesoPorPieza * 4))
  print(type(of: "7"), type(of: 7 > 2))
output: |
  3
  Int
  6.0
  Double
  String Bool
hints:
  - "piezas / cajas: los dos son Int."
  - "Un Double siempre se imprime con punto decimal, aunque sea entero: 6.0."
  - "7 > 2 es una comparación; su resultado es verdadero o falso."
solution: |
  ```output
  3
  Int
  6.0
  Double
  String Bool
  ```

  1. `7 / 2` entre `Int` es división entera: **3**.
  2. El resultado de operar dos `Int` es `Int`.
  3. `1.5 * 4`: el literal `4` se adapta a `Double`; resultado **6.0**. Un `Double` se imprime con punto decimal.
  4. Por eso el tipo es `Double`.
  5. `"7"` es `String`; `7 > 2` es una comparación y produce un `Bool`.
````

````exercise
id: m04-l03-e3
type: errores
prompt: Este programa lleva el promedio de un alumno, pero no compila. Identifica los problemas reales y escribe una versión corregida.
code: |
  var promedio = 0
  let nombre = "Luis"
  promedio = 8.5
  nombre = 10
  print(nombre, promedio)
choices:
  - text: "promedio se infiere como Int por su valor inicial 0, así que no acepta 8.5."
    correct: true
    why: "cannot assign value of type 'Double' to type 'Int'."
  - text: "nombre es un String y una constante: no puede recibir 10."
    correct: true
    why: Hay dos problemas en esa línea, el tipo y que es let.
  - text: "print no puede recibir un String y un número a la vez."
    correct: false
    why: print acepta valores de cualquier tipo, separados por comas.
  - text: "Los nombres de variables no pueden empezar con p."
    correct: false
    why: No existe esa regla.
rubric:
  - Inicialicé promedio con un decimal, 0.0.
  - Eliminé o corregí la asignación a nombre.
  - Mi versión compila e imprime el nombre y el promedio.
solution: |
  ```swift
  var promedio = 0.0
  let nombre = "Luis"
  promedio = 8.5
  print(nombre, promedio)
  ```

  ```output
  Luis 8.5
  ```

  `var promedio = 0` fija el tipo en `Int` para siempre; `0.0` lo fija en `Double`. La línea `nombre = 10` tenía dos errores a la vez: `nombre` es constante y además es `String`. Si la intención era guardar una calificación, necesitaba otro nombre con tipo numérico.
````

````exercise
id: m04-l03-e4
type: resolver
prompt: |
  Elige el tipo adecuado para cada dato de un perfil de usuario y escribe un programa que los declare con inferencia (sin anotaciones, salvo donde sea imprescindible) y los imprima junto con su tipo usando `type(of:)`:

  - nombre de usuario
  - año de nacimiento
  - estatura en metros
  - si aceptó los términos
  - inicial del apellido

  Después explica en una frase por qué elegiste cada tipo.
starter: |
  let nombreDeUsuario = "chris"
hints:
  - Para la inicial necesitas una anotación de tipo; sin ella, "A" se infiere como String.
  - "La estatura necesita decimales: 1.75."
rubric:
  - Cada dato tiene un tipo adecuado y una justificación.
  - Usé inferencia en todos los casos salvo la inicial.
  - El programa imprime cada valor con su tipo.
  - Usé let porque ninguno cambia.
solution: |
  ```swift
  let nombreDeUsuario = "chris"
  let añoDeNacimiento = 1998
  let estatura = 1.75
  let aceptoTerminos = true
  let inicialDelApellido: Character = "A"

  print(nombreDeUsuario, type(of: nombreDeUsuario))
  print(añoDeNacimiento, type(of: añoDeNacimiento))
  print(estatura, type(of: estatura))
  print(aceptoTerminos, type(of: aceptoTerminos))
  print(inicialDelApellido, type(of: inicialDelApellido))
  ```

  ```output
  chris String
  1998 Int
  1.75 Double
  true Bool
  A Character
  ```

  Nombre: texto, `String`. Año: entero, `Int`. Estatura: necesita decimales, `Double`. Términos: solo sí o no, `Bool`. Inicial: exactamente un carácter, `Character`, que hay que anotar porque un literal entre comillas se infiere como `String`.
````

````exercise
id: m04-l03-e5
type: explicar
prompt: Explica qué imprime este programa, por qué, y qué harías en una app de pagos para evitar el problema.
code: |
  let precio = 0.1
  let impuesto = 0.2
  print(precio + impuesto == 0.3)
rubric:
  - Dije que imprime false.
  - Expliqué que Double usa una representación binaria donde 0.1 y 0.2 no son exactos.
  - Mencioné que la suma da 0.30000000000000004.
  - Propuse trabajar con enteros (centavos) u otro tipo exacto para dinero.
solution: |
  Imprime **false**. `Double` representa los números en binario y 0.1 y 0.2 no tienen representación binaria exacta, igual que 1/3 no la tiene en decimal. La suma da `0.30000000000000004`, que no es igual al `Double` más cercano a 0.3.

  En una app de pagos, guarda los montos en **centavos con `Int`** (10 y 20 centavos suman exactamente 30) o usa un tipo decimal exacto como `Decimal` de Foundation. Convierte a pesos con decimales solo para mostrar el valor.
````

## Resumen

- Todo valor tiene un tipo, y el tipo de un nombre se fija al declararlo.
- Tipos básicos: `Int`, `Double`, `Bool`, `String` y `Character`.
- Swift **infiere** el tipo del valor inicial: entero → `Int`, con punto → `Double`, entre comillas → `String`.
- Los literales se adaptan al contexto; los nombres no. `Int` y `Double` no se mezclan sin conversión.
- `Int` tiene un rango finito y `Double` no es exacto: `0.1 + 0.2 == 0.3` es `false`.
- `type(of:)` muestra el tipo de un valor.
