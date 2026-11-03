---
id: m04-l04
title: "Anotaciones de tipo y conversión entre tipos"
description: Declaras el tipo de un nombre de forma explícita cuando la inferencia no basta, conviertes entre Int, Double y String sin sorpresas, y conoces tu primer valor opcional al convertir texto a número.
module: m04
order: 4
level: inicial
minutes: 50
prerequisites: [m04-l03]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Escribir anotaciones de tipo y decidir cuándo son necesarias.
  - Declarar una constante sin valor inicial y asignarla después.
  - Convertir entre Int y Double y predecir el efecto del truncamiento.
  - Convertir números a texto con String(…) y texto a número con Int(…) y Double(…).
  - Usar ?? para dar un valor por defecto cuando una conversión de texto falla.
terms:
  - term: Anotación de tipo
    definition: "Indicación explícita del tipo de un nombre, escrita con dos puntos después del nombre, como en let precio: Double = 45."
  - term: Conversión explícita
    definition: Crear un valor de un tipo a partir de otro escribiéndolo en el código, por ejemplo Double(edad). Swift nunca convierte entre tipos numéricos por su cuenta.
  - term: Truncar
    definition: Descartar la parte decimal de un número sin redondear. Int(3.9) es 3 e Int(-3.9) es -3.
  - term: Opcional
    definition: Tipo que puede contener un valor o ningún valor (nil). Int("42") devuelve un Int? porque el texto podría no ser un número.
  - term: Operador ??
    definition: Operador de coalescencia de nil. a ?? b vale el contenido de a si existe, o b si a es nil.
mastery:
  - Escribir la anotación correcta para un nombre que se declara sin valor o cuyo literal se inferiría con otro tipo.
  - Predecir el resultado de Int(9.99), Int(-2.7), Double(7) / 2 y Int("doce") ?? 0.
  - Corregir el error «binary operator cannot be applied to operands of type 'Int' and 'Double'» con una conversión explícita y explicar qué se pierde o se conserva.
  - Explicar por qué Int("42") no devuelve un Int sino un Int?.
resources: [swift-book-basics]
cards:
  - id: m04-l04-c1
    front: ¿Cómo se escribe una anotación de tipo?
    back: "Con dos puntos después del nombre: let precio: Double = 45. Aquí 45 se guarda como 45.0."
  - id: m04-l04-c2
    front: ¿Qué vale `Int(3.9)` y qué vale `Int(-3.9)`?
    back: 3 y -3. La conversión de Double a Int trunca hacia cero; no redondea.
  - id: m04-l04-c3
    front: ¿Por qué `Int("42")` devuelve un `Int?`?
    back: Porque la conversión puede fallar; Int("hola") no tiene un número que devolver. El ? indica un opcional, que puede ser nil.
  - id: m04-l04-c4
    front: ¿Qué hace `Int(texto) ?? 0`?
    back: Si el texto representa un entero, da ese entero; si no, da 0. ?? da un valor por defecto cuando el opcional es nil.
  - id: m04-l04-c5
    front: "¿Por qué no compila `let a = 3; let b = 2.5; print(a * b)`?"
    back: Porque a es Int y b es Double, y Swift no los mezcla. Hay que convertir uno, por ejemplo Double(a) * b.
---

## La idea en una frase

Cuando la inferencia no dice lo que quieres, lo dices tú con una **anotación**; cuando necesitas cambiar de tipo, lo pides tú con una **conversión**. Swift nunca lo hace a escondidas.

## Anotaciones de tipo

**Definición sencilla:** escribir el tipo de un nombre en lugar de dejar que Swift lo deduzca.

**Sintaxis:** dos puntos después del nombre y luego el tipo.

```swift
let precio: Double = 45
let inicial: Character = "M"
var intentos: Int = 0
print(precio, inicial, intentos)
```

```output
45.0 M 0
```

Línea por línea:

1. Sin la anotación, `45` sería un `Int`. Con `: Double`, el literal se interpreta como decimal y se imprime `45.0`.
2. Sin la anotación, `"M"` sería un `String`.
3. Aquí la anotación es redundante: `0` ya se inferiría como `Int`. Es válida, pero no aporta nada.
4. `print` muestra los tres valores.

### Cuándo anotar

| Situación | Ejemplo |
| --- | --- |
| El literal se inferiría con otro tipo | `let precio: Double = 45` |
| Declaras sin valor inicial | `let mensaje: String` |
| Quieres un tipo distinto del predeterminado | `let inicial: Character = "M"` |
| La anotación aclara la intención a quien lee | Código que se lee más de lo que se escribe |

Cuando la inferencia da el tipo correcto y es evidente, la convención de Swift es **no anotar**. `let nombre: String = "Ana"` no aporta nada que `let nombre = "Ana"` no diga.

### Declarar ahora, asignar después

Una constante puede declararse sin valor si se le asigna **exactamente una vez** antes de leerla. Sin valor inicial no hay nada de dónde inferir, así que la anotación es obligatoria:

```swift
let saludo: String
saludo = "Hola"
print(saludo)
```

```output
Hola
```

Esto será útil cuando el valor dependa de una decisión (`if`), que verás en el siguiente módulo. Sin anotación, el compilador responde `type annotation missing in pattern`.

## Conversión entre tipos numéricos

Swift no mezcla `Int` y `Double`:

```swift no-compila binary operator '*' cannot be applied to operands of type 'Int' and 'Double'
let cantidad = 3
let precioUnitario = 2.5
print(cantidad * precioUnitario)
```

Otros lenguajes convierten en silencio. Swift no, porque cada conversión puede **perder información** y quiere que lo decidas tú. La conversión se escribe con el nombre del tipo como si fuera una función:

```swift
let cantidad = 3
let precioUnitario = 2.5
print(Double(cantidad) * precioUnitario)
print(cantidad * Int(precioUnitario))
```

```output
7.5
6
```

1. `Double(cantidad)` crea el `Double` 3.0. La multiplicación es entre `Double`: **7.5**. No se pierde nada.
2. `Int(precioUnitario)` crea el `Int` 2, porque **trunca** 2.5. El resultado, **6**, está mal para un ticket. La conversión elegida cambió el significado del cálculo.

Regla práctica: convierte **hacia** el tipo que conserva la información que necesitas. Para dinero y medidas, eso suele ser `Double` (o centavos con `Int`, como viste en la lección anterior).

### Truncar no es redondear

```swift
print(Int(9.99))
print(Int(-2.7))
print(Int((9.99).rounded()))
```

```output
9
-2
10
```

`Int(_:)` con un `Double` descarta la parte decimal **hacia cero**: 9.99 se vuelve 9 y −2.7 se vuelve −2. Si quieres redondear, primero redondea con `rounded()`, que por defecto redondea al entero más cercano (y los casos .5 se alejan del cero), y después convierte.

> [!aviso]
> Si el `Double` no cabe en un `Int` (por ejemplo `1e20`), la conversión detiene el programa con `Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max`. Swift prefiere detenerse a darte un número incorrecto.

```swift falla-en-ejecucion Double value cannot be converted to Int
let enorme = 1e20
print(Int(enorme))
```

## Números y texto

### De número a texto

`String(…)` convierte un número en su texto:

```swift
let piso = 5
print(String(piso) + "º piso")
print(String(2.5))
```

```output
5º piso
2.5
```

Ahora sí puedes usar `+` porque ambos lados son `String`. En la última lección del módulo verás la **interpolación**, que casi siempre es más cómoda.

### De texto a número: tu primer opcional

Convertir texto a número **puede fallar**. ¿Qué número es `"doce"`? Por eso `Int("…")` no devuelve un `Int`, sino un **`Int?`**: un *opcional*, que contiene un entero o no contiene nada (`nil`).

```swift no-compila value of optional type 'Int?' must be unwrapped to a value of type 'Int'
let edad = Int("30")
print(edad + 1)
```

El compilador no te deja sumar a algo que podría no existir. La forma más simple de obtener un `Int` es dar un valor por defecto con el operador `??`:

```swift
let edad = Int("30") ?? 0
print(edad + 1)
print(Int("doce") ?? 0)
print(Int("3.5") ?? -1)
print(Double("3.5") ?? -1)
```

```output
31
0
-1
3.5
```

1. `"30"` sí es un entero: `edad` vale 30, y su tipo ya es `Int`.
2. Se puede sumar sin problema: 31.
3. `"doce"` no es un número: `Int("doce")` es `nil` y `??` da el valor por defecto, 0.
4. `"3.5"` tampoco es un **entero**: `Int` no lo acepta.
5. `Double("3.5")` sí funciona.

Los opcionales son una de las ideas centrales de Swift y tienen su propio módulo más adelante. Por ahora basta con esto: **si una operación puede fallar, Swift te obliga a decidir qué pasa cuando falla**.

> [!nota]
> Si imprimes el opcional directamente, `print(Int("42"))`, verás `Optional(42)` y el compilador te dará una advertencia. Es su forma de recordarte que no has decidido qué hacer con el caso `nil`.

## Ejemplo práctico: repartir litros

Una persona escribe en una app cuántos litros de agua hay (`"7"`) y entre cuántas botellas repartirlos (`"2"`). La app debe mostrar cuánto va en cada botella, con decimales.

```swift
let textoLitros = "7"
let textoBotellas = "2"

let litros = Int(textoLitros) ?? 0
let botellas = Int(textoBotellas) ?? 1

let litrosPorBotella = Double(litros) / Double(botellas)
print("Litros por botella:", litrosPorBotella)
print("Si solo usaras enteros:", litros / botellas)
```

```output
Litros por botella: 3.5
Si solo usaras enteros: 3
```

Tres decisiones conscientes:

- Si el texto de litros no es un número, se usan 0 litros.
- Si el texto de botellas no es un número, se usa **1** botella y no 0, para no dividir entre cero.
- Se convierte a `Double` **antes** de dividir. `Double(litros / botellas)` daría 3.0: la división entera ya habría perdido el .5.

## Errores frecuentes

> [!error] error: binary operator '*' cannot be applied to operands of type 'Int' and 'Double'
> Estás mezclando tipos numéricos. Convierte uno de los dos de forma explícita y elige hacia qué tipo según lo que necesites conservar.

> [!error] Convertir después de dividir
> `Double(7 / 2)` es 3.0, no 3.5: la división entera ocurre primero. Convierte los operandos, no el resultado.

> [!error] Esperar que Int(…) redondee
> `Int(9.99)` es 9. Para redondear usa `Int(x.rounded())`.

> [!error] error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
> `Int("…")` y `Double("…")` devuelven opcionales. Usa `?? valorPorDefecto` hasta que estudies los opcionales a fondo.

> [!error] error: type annotation missing in pattern
> Declaraste un nombre sin valor inicial y sin tipo. Agrega la anotación: `let mensaje: String`.

````exercise
id: m04-l04-e1
type: comprension
prompt: "¿Qué valor tiene `x` después de `let x = Int(Double(17) / 5)`?"
choices:
  - text: "3.4"
    correct: false
    why: Int no puede guardar decimales.
  - text: "3"
    correct: true
    why: "Double(17) / 5 es 3.4 y la conversión a Int trunca: 3."
  - text: "4"
    correct: false
    why: La conversión no redondea, trunca.
  - text: No compila.
    correct: false
    why: Todas las conversiones son explícitas y válidas.
solution: |
  **3.** `Double(17) / 5` es una división decimal, 3.4. `Int(3.4)` descarta la parte decimal hacia cero: 3. Si quisieras 3 con certeza sin pasar por decimales, `17 / 5` lo da directamente; si quisieras redondear, `Int((Double(17) / 5).rounded())`, que también da 3 porque 3.4 está más cerca de 3.
````

````exercise
id: m04-l04-e2
type: prediccion
prompt: Predice la salida exacta, línea por línea.
code: |
  let litros = 7
  let personas = 2
  print(litros / personas)
  print(Double(litros) / Double(personas))
  print(Double(litros / personas))
  print(Int(9.99), Int(-2.7))
  print(String(5) + String(5))
  print(Int("12") ?? 0, Int("doce") ?? 0)
output: |
  3
  3.5
  3.0
  9 -2
  55
  12 0
hints:
  - "En la línea 5 la división ocurre antes de la conversión."
  - "Int(_:) trunca hacia cero."
  - "String(5) es el texto \"5\"."
solution: |
  ```output
  3
  3.5
  3.0
  9 -2
  55
  12 0
  ```

  1. División entera: 3.
  2. Ambos convertidos a `Double` antes de dividir: 3.5.
  3. `litros / personas` ya es 3 (entero); convertirlo después da 3.0. El .5 se perdió antes.
  4. Truncar hacia cero: 9 y −2.
  5. `"5" + "5"` concatena textos: `55`.
  6. `"12"` se convierte; `"doce"` no, y `??` da 0.
````

````exercise
id: m04-l04-e3
type: completar
prompt: |
  Completa el programa para que calcule el promedio con decimales de tres calificaciones enteras e imprima exactamente:

  ```output
  Promedio: 8.0
  ```
code: |
  let suma = 9 + 7 + 8
  let cantidad = 3
  let promedio = [[1]](suma) / [[2]](cantidad)
  print("Promedio:", promedio)
blanks:
  - id: "1"
    answers: ["Double"]
  - id: "2"
    answers: ["Double"]
solution: |
  ```swift
  let suma = 9 + 7 + 8
  let cantidad = 3
  let promedio = Double(suma) / Double(cantidad)
  print("Promedio:", promedio)
  ```

  ```output
  Promedio: 8.0
  ```

  `suma` vale 24 y es `Int`. Para obtener un promedio con decimales hay que convertir los dos operandos a `Double` antes de dividir. Como 24 / 3 es exacto, el resultado es 8.0; con otras calificaciones conservaría los decimales.
````

````exercise
id: m04-l04-e4
type: errores
prompt: Este programa debería calcular el precio con 16 % de IVA de un producto cuyo precio llega como texto. No compila. Identifica los problemas reales y corrígelo.
code: |
  let textoPrecio = "250"
  let precio = Int(textoPrecio)
  let tasa = 0.16
  let iva = precio * tasa
  let total: Int = precio + iva
  print("Total:", total)
choices:
  - text: "precio es un Int?, no un Int; hay que dar un valor por defecto con ??."
    correct: true
    why: Int(textoPrecio) puede fallar.
  - text: "precio * tasa mezcla Int con Double."
    correct: true
    why: Hay que convertir precio a Double.
  - text: "Anotar total como Int obliga a perder los centavos."
    correct: true
    why: 250 × 1.16 = 290.0, pero con otros precios habría decimales que un Int truncaría.
  - text: "0.16 no es un literal válido; debe escribirse .16."
    correct: false
    why: Al revés. En Swift, .16 no es válido; se escribe 0.16.
rubric:
  - Convertí el texto con Int(…) ?? 0 o Double(…) ?? 0.
  - Hice todas las operaciones en Double.
  - Quité la anotación Int de total o la cambié por Double.
  - La salida es Total, 290.0.
solution: |
  ```swift
  let textoPrecio = "250"
  let precio = Double(textoPrecio) ?? 0
  let tasa = 0.16
  let iva = precio * tasa
  let total = precio + iva
  print("Total:", total)
  ```

  ```output
  Total: 290.0
  ```

  Convertir el texto directamente a `Double` resuelve dos problemas a la vez: el opcional (con `??`) y la mezcla de tipos. `total` se infiere como `Double`. En una app real con dinero trabajarías en centavos o con `Decimal`, como viste en la lección de tipos; este ejercicio es sobre conversiones.
````

````exercise
id: m04-l04-e5
type: resolver
prompt: |
  Una app recibe como texto una temperatura en grados Celsius, `"36.6"`, y debe mostrar:

  ```output
  Celsius: 36.6
  Fahrenheit: 97.88000000000001
  Fahrenheit redondeado: 98
  ```

  La fórmula es F = C × 9 / 5 + 32. Si el texto no es un número válido, usa 0.
starter: |
  let texto = "36.6"
hints:
  - "Double(texto) ?? 0 convierte el texto."
  - "Escribe 9.0 / 5 para que la división sea decimal."
  - Para el redondeo, Int(f.rounded()).
rubric:
  - Convertí el texto con Double(…) ?? 0.
  - La fórmula usa división decimal.
  - El valor redondeado usa rounded() antes de convertir a Int.
  - El programa imprime exactamente las tres líneas.
solution: |
  ```swift
  let texto = "36.6"
  let celsius = Double(texto) ?? 0
  let fahrenheit = celsius * 9 / 5 + 32
  print("Celsius:", celsius)
  print("Fahrenheit:", fahrenheit)
  print("Fahrenheit redondeado:", Int(fahrenheit.rounded()))
  ```

  ```output
  Celsius: 36.6
  Fahrenheit: 97.88000000000001
  Fahrenheit redondeado: 98
  ```

  Como `celsius` es `Double`, los literales `9`, `5` y `32` se interpretan como `Double` y toda la fórmula es decimal. `Int(fahrenheit)` daría 97 por truncar; `rounded()` primero da 98.0 y después la conversión da 98.

  Observa la segunda línea: en papel, 36.6 × 9 / 5 + 32 es exactamente 97.88, pero Swift imprime `97.88000000000001`. Es la precisión binaria de `Double` que viste en la lección anterior: 36.6 no tiene representación binaria exacta y el error diminuto aparece al imprimir. El valor redondeado no se ve afectado. Para mostrar un número fijo de decimales hay herramientas de formato que verás más adelante.
````

## Resumen

- Una anotación de tipo se escribe `nombre: Tipo`. Úsala cuando no hay valor inicial o cuando el literal se inferiría con otro tipo.
- Swift nunca mezcla ni convierte tipos numéricos por su cuenta: `Double(n)`, `Int(x)`, `String(n)`.
- `Int(x)` con un `Double` trunca hacia cero; para redondear, `Int(x.rounded())`.
- Convierte los operandos antes de dividir si quieres decimales.
- `Int("…")` y `Double("…")` devuelven opcionales; `?? valor` da un valor por defecto si la conversión falla.
