---
id: m04-l06
title: "Interpolación de cadenas y caracteres especiales"
description: Insertas valores y expresiones dentro de un texto con \( ), escribes comillas, saltos de línea y emojis con secuencias de escape, y construyes textos de varias líneas. Cierras el módulo escribiendo un recibo completo.
module: m04
order: 6
level: inicial
minutes: 45
prerequisites: [m04-l04, m04-l05]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Insertar constantes, variables y expresiones en un String con interpolación.
  - Elegir entre interpolación, concatenación con + y varios valores en print.
  - Usar las secuencias de escape \", \\, \n, \t y \u{…}.
  - Escribir literales de varias líneas con triple comilla y controlar su sangría.
  - Reconocer y evitar la interpolación de un opcional.
terms:
  - term: String
    definition: Tipo de Swift para texto. Un literal de String se escribe entre comillas dobles.
  - term: Interpolación
    definition: Insertar el valor de una expresión dentro de un literal de texto escribiendo \(expresión). Funciona con valores de cualquier tipo.
  - term: Concatenación
    definition: Unir dos textos con el operador +. Ambos lados deben ser String.
  - term: Secuencia de escape
    definition: Combinación que empieza con \ dentro de un texto y representa un carácter especial, como \n (salto de línea) o \" (comillas).
  - term: Literal de varias líneas
    definition: Texto delimitado por tres comillas dobles al inicio y al final, que puede ocupar varias líneas del código.
  - term: Literal sin procesar
    definition: Texto delimitado con # alrededor de las comillas, como #"C:\carpeta"#, en el que \ no inicia secuencias de escape.
mastery:
  - Reescribir un programa que usa String(…) y + para que use interpolación, con la misma salida.
  - Predecir la salida de un texto con \(…), \n y \" incluyendo expresiones aritméticas dentro de la interpolación.
  - Escribir un literal de varias líneas con sangría interna controlada por la posición de las comillas de cierre.
  - Explicar por qué "\(Int("30"))" muestra Optional(30) y cómo evitarlo.
resources: [swift-book-strings, swift-book-basics, swift-print]
cards:
  - id: m04-l06-c1
    front: ¿Cómo se inserta el valor de `total` dentro de un texto?
    back: Con interpolación, "Total \(total)". Funciona con cualquier tipo y con expresiones, como "\(a + b)".
  - id: m04-l06-c2
    front: ¿Qué secuencias de escape escriben comillas, diagonal invertida, salto de línea y tabulador?
    back: \" para comillas, \\ para la diagonal invertida, \n para salto de línea y \t para tabulador.
  - id: m04-l06-c3
    front: En un literal de varias líneas, ¿qué decide cuánta sangría se elimina?
    back: La sangría de las comillas de cierre. Se elimina esa cantidad de espacios de cada línea; lo que esté más a la derecha se conserva.
  - id: m04-l06-c4
    front: ¿Por qué `"Edad \(Int("30"))"` muestra `Optional(30)`?
    back: Int("30") es un Int? y la interpolación muestra la descripción del opcional. El compilador advierte. Usa Int("30") ?? 0 antes de interpolar.
---

## La idea en una frase

La interpolación escribe un valor **dentro** de un texto: `"Total: \(total)"`. Es la forma normal de combinar texto y datos en Swift.

## El problema que resuelve

Desde la primera lección del módulo sabes que esto no compila:

```swift no-compila binary operator '+' cannot be applied to operands of type 'String' and 'Int'
let total = 73
print("Total: " + total)
```

Hasta ahora tenías dos salidas: `print` con varios valores, o convertir con `String(…)`:

```swift
let total = 73
print("Total:", total)
print("Total: " + String(total) + " pesos")
```

```output
Total: 73
Total: 73 pesos
```

La primera solo sirve dentro de `print`. La segunda funciona en cualquier lugar, pero con varios valores se llena de `+` y de `String(…)`.

## Interpolación

**Definición sencilla:** escribir `\(algo)` dentro de un texto para que aparezca el valor de `algo`.

**Definición precisa:** dentro de un literal de `String`, la secuencia `\(expresión)` evalúa la expresión, convierte su resultado en texto y lo inserta en ese lugar. La expresión puede ser de cualquier tipo.

```swift
let nombre = "Ana"
let edad = 30
let mensaje = "Hola, \(nombre). Tienes \(edad) años."
print(mensaje)
print("El año que viene tendrás \(edad + 1).")
```

```output
Hola, Ana. Tienes 30 años.
El año que viene tendrás 31.
```

Línea por línea:

1. y 2. Dos constantes, un `String` y un `Int`.
3. `\(nombre)` se reemplaza por `Ana` y `\(edad)` por `30`. El resultado es un `String` normal que se guarda en `mensaje`.
4. Se imprime como cualquier texto.
5. Dentro de `\( )` puede ir una **expresión**: `edad + 1` se calcula primero.

No hace falta convertir: la interpolación funciona igual con `Int`, `Double`, `Bool` o cualquier otro tipo.

```swift
let precio = 45.5
let disponible = true
print("Precio: \(precio), disponible: \(disponible), división: \(7 / 2)")
```

```output
Precio: 45.5, disponible: true, división: 3
```

Las reglas de los tipos siguen aplicando dentro: `7 / 2` entre enteros sigue siendo 3.

### ¿Interpolación, + o varios valores en print?

| Forma | Cuándo usarla |
| --- | --- |
| `"Total: \(total)"` | Casi siempre. Funciona en cualquier lugar, con cualquier tipo, y se lee como el texto final |
| `"Hola" + nombre` | Para unir dos textos que ya son `String` |
| `print("Total:", total)` | Para una impresión rápida mientras pruebas algo |

## Secuencias de escape

Algunos caracteres no se pueden escribir tal cual dentro de las comillas. Se escriben con una **diagonal invertida** `\`:

| Escritura | Produce |
| --- | --- |
| `\"` | comillas dobles |
| `\\` | una diagonal invertida |
| `\n` | salto de línea |
| `\t` | tabulador |
| `\u{1F600}` | el carácter Unicode con ese código hexadecimal, aquí 😀 |

```swift
print("Ella dijo: \"hola\"")
print("Ruta: C:\\Usuarios")
print("Línea 1\nLínea 2")
print("\u{00F1} \u{1F600}")
```

```output
Ella dijo: "hola"
Ruta: C:\Usuarios
Línea 1
Línea 2
ñ 😀
```

En la práctica escribes `ñ` y 😀 directamente en el código; `\u{…}` sirve cuando un carácter no se puede teclear o no se ve, como un espacio especial.

> [!nota]
> La interpolación `\( )` también empieza con `\`. Por eso, si quieres escribir literalmente `\(` en un texto, necesitas `\\(`.

## Textos de varias líneas

Para textos largos, tres comillas dobles:

```swift
let recibo = """
    Cafetería Central
      Café       45
      Pan        28
    Gracias por su visita
    """
print(recibo)
```

```output
Cafetería Central
  Café       45
  Pan        28
Gracias por su visita
```

Reglas:

1. Las tres comillas de apertura van al final de su línea; el texto empieza en la línea siguiente.
2. Las tres comillas de cierre van en su propia línea.
3. La **sangría de las comillas de cierre** se elimina de todas las líneas. Aquí son cuatro espacios. Lo que esté más a la derecha, como los dos espacios extra de Café y Pan, se conserva.
4. Dentro funcionan la interpolación y los escapes, y puedes escribir `"` sin escapar.

Si una línea del código termina en `\`, el salto de línea no se incluye en el texto. Sirve para partir una línea larga en el código sin partirla en la salida.

### Literales sin procesar

Con `#` alrededor de las comillas, `\` deja de ser especial. Útil para rutas de Windows o expresiones regulares:

```swift
print(#"Ruta: C:\carpeta y "comillas""#)
```

```output
Ruta: C:\carpeta y "comillas"
```

Dentro de un literal sin procesar, la interpolación se escribe `\#(valor)`.

## Interpolar un opcional

```swift advertencia string interpolation produces a debug description for an optional value
let edad = Int("30")
print("Edad: \(edad)")
```

```output
Edad: Optional(30)
```

`Int("30")` es un `Int?` (lección de conversiones). La interpolación muestra su descripción de depuración, `Optional(30)`, que nunca debería ver una persona usuaria, y el compilador lo advierte. Resuelve el caso `nil` antes de interpolar:

```swift
let edad = Int("30") ?? 0
print("Edad: \(edad)")
```

```output
Edad: 30
```

## Ejemplo práctico: un recibo

Este programa reúne todo el módulo: constantes, variables, tipos, conversiones, comparaciones e interpolación.

```swift
let cliente = "Mariana"
let precioCafe = 45
let precioPan = 28
let cantidadDeCafes = 2
let esCumpleaños = true

var total = precioCafe * cantidadDeCafes + precioPan
let descuentoEnPesos = esCumpleaños ? 20 : 0
total -= descuentoEnPesos
let totalConPropina = Double(total) * 1.10

let recibo = """
    Cliente: \(cliente)
    Cafés: \(cantidadDeCafes) × \(precioCafe) = \(cantidadDeCafes * precioCafe)
    Pan: \(precioPan)
    Descuento de cumpleaños: \(descuentoEnPesos)
    Total: \(total)
    Total con 10 % de propina: \(Int(totalConPropina.rounded()))
    ¿Pagó más de 100?: \(total > 100)
    """
print(recibo)
```

```output
Cliente: Mariana
Cafés: 2 × 45 = 90
Pan: 28
Descuento de cumpleaños: 20
Total: 98
Total con 10 % de propina: 108
¿Pagó más de 100?: false
```

Una pieza nueva: `esCumpleaños ? 20 : 0` es el **operador condicional ternario**: si la condición es verdadera vale lo que está después de `?`; si no, lo que está después de `:`. Lo estudiarás junto con `if` en el siguiente módulo.

Observa la propina: 98 × 1.10 en `Double` no es exactamente 107.8, y por eso se redondea antes de mostrarla.

## Errores frecuentes

> [!error] error: binary operator '+' cannot be applied to operands of type 'String' and 'Int'
> Usa interpolación: `"Total: \(total)"`.

> [!error] error: cannot find ')' to match opening '(' in string interpolation
> Falta cerrar el paréntesis de `\( )`. Suele venir acompañado de `unterminated string literal`.

> [!error] error: multi-line string literal content must begin on a new line
> Escribiste texto en la misma línea que las tres comillas de apertura. El contenido empieza en la línea siguiente.

> [!error] Ver Optional(…) en un texto
> Interpolaste un opcional. Resuélvelo antes con `?? valorPorDefecto`.

> [!error] Olvidar la diagonal invertida
> `"Total: (total)"` imprime literalmente `(total)`. La interpolación necesita `\(`.

````exercise
id: m04-l06-e1
type: comprension
prompt: |
  ¿Qué imprime este programa?

  ```swift
  let a = 4
  let b = 6
  print("\(a) + \(b) = \(a + b)")
  ```
choices:
  - text: "`4 + 6 = 10`"
    correct: true
    why: Cada \( ) se reemplaza por su valor; el + de fuera es texto.
  - text: "`a + b = a + b`"
    correct: false
    why: Sin \( ) se imprimirían los nombres; con \( ) se evalúan.
  - text: "`4 + 6 = 4 + 6`"
    correct: false
    why: La tercera interpolación contiene una expresión y se calcula.
  - text: No compila porque mezcla texto y números.
    correct: false
    why: La interpolación acepta valores de cualquier tipo.
solution: |
  Imprime **`4 + 6 = 10`**. Fuera de `\( )`, los caracteres `+` e `=` son parte del texto. Dentro, `a + b` es una expresión que se evalúa. La interpolación convierte cada resultado en texto, así que no hay problema de tipos.
````

````exercise
id: m04-l06-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea.
code: |
  let nombre = "Ana"
  let puntos = 7
  let bono = 3
  print("\(nombre) tiene \(puntos + bono) puntos")
  print("Promedio: \(Double(puntos) / 2)")
  print("Dijo: \"listo\"")
  print("Uno\nDos")
  var saludo = "Hola"
  saludo += ", \(nombre)!"
  print(saludo)
  print("¿Ganó? \(puntos + bono >= 10)")
output: |
  Ana tiene 10 puntos
  Promedio: 3.5
  Dijo: "listo"
  Uno
  Dos
  Hola, Ana!
  ¿Ganó? true
hints:
  - "\\n dentro de un texto produce un salto de línea: un print, dos líneas."
  - "+= también funciona con String: agrega texto al final."
solution: |
  ```output
  Ana tiene 10 puntos
  Promedio: 3.5
  Dijo: "listo"
  Uno
  Dos
  Hola, Ana!
  ¿Ganó? true
  ```

  1. `puntos + bono` se evalúa: 10.
  2. `Double(7) / 2` es 3.5.
  3. `\"` produce comillas dentro del texto.
  4. `\n` parte el texto en dos líneas.
  5. `saludo += …` concatena al final de la variable.
  6. La comparación `10 >= 10` es `true` y se interpola como texto.
````

````exercise
id: m04-l06-e3
type: completar
prompt: |
  Completa el programa para que imprima exactamente:

  ```output
  Producto: "Audífonos"
  Precio: 899.5
  ```
code: |
  let producto = "Audífonos"
  let precio = 899.5
  print("Producto: [[1]]\(producto)[[2]]")
  print("Precio: [[3]](precio)")
blanks:
  - id: "1"
    answers: ["\\\""]
  - id: "2"
    answers: ["\\\""]
  - id: "3"
    answers: ["\\"]
solution: |
  ```swift
  let producto = "Audífonos"
  let precio = 899.5
  print("Producto: \"\(producto)\"")
  print("Precio: \(precio)")
  ```

  ```output
  Producto: "Audífonos"
  Precio: 899.5
  ```

  `\"` escribe unas comillas dentro del texto; se necesitan dos, en los huecos 1 y 2, antes y después del nombre. `\(` inicia la interpolación: sin la diagonal se imprimiría `(precio)` literalmente.
````

````exercise
id: m04-l06-e4
type: refactorizar
prompt: Reescribe este programa con interpolación. La salida debe ser idéntica y no debe quedar ningún `String(…)` ni `+` entre textos.
code: |
  let ciudad = "Puebla"
  let temperatura = 23
  let humedad = 0.45
  print("En " + ciudad + " hay " + String(temperatura) + " grados.")
  print("Humedad: " + String(Int(humedad * 100)) + " %")
rubric:
  - La salida es idéntica a la original.
  - No quedan + entre textos ni String(…).
  - Las expresiones se calculan dentro de la interpolación o en constantes con nombre.
solution: |
  ```swift
  let ciudad = "Puebla"
  let temperatura = 23
  let humedad = 0.45
  print("En \(ciudad) hay \(temperatura) grados.")
  print("Humedad: \(Int(humedad * 100)) %")
  ```

  ```output
  En Puebla hay 23 grados.
  Humedad: 45 %
  ```

  La interpolación se lee como el texto final. La conversión `Int(…)` se conserva porque `humedad * 100` es un `Double` (45.0) y queremos mostrar `45`, no `45.0`. Si la expresión dentro de `\( )` se vuelve larga, sácala a una constante con nombre, como `let porcentajeDeHumedad = Int(humedad * 100)`.
````

````exercise
id: m04-l06-e5
type: resolver
prompt: |
  Escribe un programa que, a partir de estas constantes, imprima la tarjeta de presentación exactamente como se muestra, usando **un solo** literal de varias líneas con interpolación.

  ```swift
  let nombre = "Christian"
  let rol = "iOS Engineer"
  let añosDeExperiencia = 1
  let usaSwiftUI = true
  ```

  ```output
  +--------------------------+
  | Christian
  | iOS Engineer
  | Experiencia: 1 año(s)
  | ¿SwiftUI?: true
  +--------------------------+
  ```
starter: |
  let nombre = "Christian"
  let rol = "iOS Engineer"
  let añosDeExperiencia = 1
  let usaSwiftUI = true
hints:
  - "Las comillas de cierre deciden cuánta sangría se quita. Alinéalas con el inicio de las líneas."
  - "Puedes escribir \"(s)\" tal cual; solo \\( inicia una interpolación."
rubric:
  - Usé un solo literal de varias líneas.
  - Interpolé las cuatro constantes.
  - La salida coincide carácter por carácter, sin sangría sobrante.
solution: |
  ```swift
  let nombre = "Christian"
  let rol = "iOS Engineer"
  let añosDeExperiencia = 1
  let usaSwiftUI = true

  let tarjeta = """
      +--------------------------+
      | \(nombre)
      | \(rol)
      | Experiencia: \(añosDeExperiencia) año(s)
      | ¿SwiftUI?: \(usaSwiftUI)
      +--------------------------+
      """
  print(tarjeta)
  ```

  ```output
  +--------------------------+
  | Christian
  | iOS Engineer
  | Experiencia: 1 año(s)
  | ¿SwiftUI?: true
  +--------------------------+
  ```

  Las comillas de cierre tienen cuatro espacios de sangría, así que Swift quita cuatro espacios de cada línea y el texto queda pegado al margen. `año(s)` no es interpolación porque el paréntesis no va precedido de `\`. Elegir entre «año» y «años» según el número es una decisión, `if`, que verás en el siguiente módulo.
````

## Resumen

- `"Texto \(expresión)"` inserta el valor de cualquier expresión, de cualquier tipo. Es la forma normal de combinar texto y datos.
- `+` une textos que ya son `String`; `print` con varios valores sirve para pruebas rápidas.
- Escapes: `\"`, `\\`, `\n`, `\t`, `\u{…}`.
- `"""` crea textos de varias líneas; la sangría de las comillas de cierre se elimina de todas las líneas.
- `#"…"#` crea un texto sin procesar donde `\` no es especial.
- No interpoles opcionales: resuélvelos antes con `??`.
