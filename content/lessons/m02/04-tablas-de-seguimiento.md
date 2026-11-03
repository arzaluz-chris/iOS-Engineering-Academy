---
id: m02-l04
title: Tablas de seguimiento y ejecución manual
description: Ejecutas un algoritmo a mano, paso por paso, anotando cada variable en una tabla. Es la forma más confiable de predecir lo que hará un programa y de encontrar el paso exacto donde falla.
module: m02
order: 4
level: inicial
minutes: 45
prerequisites: [m02-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Construir una tabla de seguimiento con una columna por variable, condición y salida.
  - Ejecutar a mano un algoritmo con ciclos y decisiones sin saltarse pasos.
  - Contar cuántas veces se ejecuta un ciclo a partir de su tabla.
  - Usar una tabla de seguimiento para localizar el paso exacto en el que un algoritmo falla.
terms:
  - term: Tabla de seguimiento
    definition: Tabla en la que cada fila es un momento de la ejecución y cada columna el valor de una variable, una condición o la salida. En inglés se llama trace table.
  - term: Ejecución manual
    definition: Seguir un algoritmo con lápiz y papel, como lo haría la computadora, sin suponer resultados.
  - term: Estado
    definition: Los valores de todas las variables en un momento dado de la ejecución.
  - term: Iteración
    definition: Una vuelta de un ciclo.
  - term: Error por uno
    definition: Error en el que un ciclo da una vuelta de más o de menos, normalmente por usar < en lugar de ≤ o al revés. En inglés, off-by-one error.
mastery:
  - Llenar sin errores una tabla de seguimiento de un algoritmo con un ciclo y una decisión, y escribir su salida exacta.
  - Decir cuántas iteraciones da un ciclo y con qué valores termina cada variable.
  - Encontrar con una tabla la fila en la que un algoritmo con un error por uno empieza a divergir del resultado esperado.
  - Explicar por qué la tabla se llena línea por línea y no «de memoria».
resources: [swift-book-control-flow]
cards:
  - id: m02-l04-c1
    front: ¿Qué columnas lleva una tabla de seguimiento?
    back: Una por cada variable, una por cada condición que se evalúa y una para la salida. Cada fila es un momento de la ejecución.
  - id: m02-l04-c2
    front: ¿Qué es un error por uno?
    back: Un ciclo que da una vuelta de más o de menos, típicamente por confundir < con ≤ o por empezar a contar en 0 en lugar de 1.
  - id: m02-l04-c3
    front: ¿Por qué no llenar la tabla «de memoria»?
    back: Porque el objetivo es ejecutar lo que el algoritmo dice, no lo que crees que dice. Los errores se esconden justo en la diferencia entre ambos.
---

## La idea en una frase

Una tabla de seguimiento te convierte en la computadora: ejecutas cada paso tal como está escrito y anotas qué cambia.

## Por qué ejecutar a mano

Leer un algoritmo y «ver» qué hace funciona hasta que hay un ciclo. Ahí la memoria falla: ¿cuánto valía `suma` en la tercera vuelta? ¿Se ejecutó el `Si` en la última? La tabla elimina la adivinanza.

Es la misma habilidad que usarás en dos situaciones de trabajo:

- **Depuración**: cuando un programa da un resultado equivocado, comparas la tabla que esperabas con los valores reales en el depurador de Xcode. El primer punto donde difieren es donde está el error. Lo practicarás en el Módulo 3.
- **Entrevistas técnicas**: después de escribir una solución, se espera que la ejecutes a mano con un ejemplo pequeño para mostrar que funciona.

## Cómo se construye una tabla

1. Escribe una columna por cada **variable**, una por cada **condición** que se evalúa y una para la **salida**.
2. Escribe una fila con los valores **iniciales**.
3. Ejecuta el algoritmo línea por línea. Cada vez que algo cambie, agrega una fila o actualiza la columna correspondiente.
4. No escribas un valor que no hayas calculado con la línea que lo produce.

### Ejemplo mínimo: suma de los dígitos

```pseudo
Entrada: un entero n ≥ 0
Salida: la suma de sus dígitos

suma ← 0
Mientras n > 0
    suma ← suma + (residuo de n ÷ 10)
    n ← n ÷ 10, división entera
Muestra suma
```

Con n = 472:

| Momento | n | ¿n > 0? | residuo de n ÷ 10 | suma | Salida |
| --- | --- | --- | --- | --- | --- |
| Inicio | 472 | — | — | 0 | |
| Vuelta 1 | 472 → 47 | sí | 2 | 2 | |
| Vuelta 2 | 47 → 4 | sí | 7 | 9 | |
| Vuelta 3 | 4 → 0 | sí | 4 | 13 | |
| Fin del ciclo | 0 | no | — | 13 | |
| Muestra | 0 | — | — | 13 | 13 |

Línea por línea:

1. `suma ← 0` es el valor inicial del acumulador.
2. La condición `n > 0` se evalúa **antes** de cada vuelta. Anótala siempre: la última evaluación, la que da «no», es la que termina el ciclo.
3. `residuo de n ÷ 10` toma el último dígito: el residuo de 472 entre 10 es 2.
4. `n ÷ 10` con división entera quita el último dígito: 472 se vuelve 47.
5. Tras tres vueltas `n` es 0 y la condición es falsa.
6. Se muestra 13, que es 4 + 7 + 2.

Dos cosas que solo la tabla deja ver: el ciclo da **tantas vueltas como dígitos tiene n**, y con n = 0 no da ninguna y muestra 0, que es correcto.

## Ejemplo práctico: encontrar un error por uno

Este algoritmo debería mostrar los múltiplos de 3 desde 3 hasta 15, inclusive:

```pseudo
m ← 3
Mientras m < 15
    Muestra m
    m ← m + 3
```

La tabla:

| Vuelta | m al preguntar | ¿m < 15? | Muestra | m después |
| --- | --- | --- | --- | --- |
| 1 | 3 | sí | 3 | 6 |
| 2 | 6 | sí | 6 | 9 |
| 3 | 9 | sí | 9 | 12 |
| 4 | 12 | sí | 12 | 15 |
| 5 | 15 | **no** | — | — |

La quinta fila es la evidencia: cuando `m` vale exactamente 15, la condición `m < 15` es falsa y el 15 nunca se muestra. Es un **error por uno**: el ciclo da una vuelta menos de lo necesario. La corrección es `m ≤ 15`.

Sin la tabla, el error es fácil de pasar por alto, porque el algoritmo «casi» funciona: muestra cuatro de los cinco números.

> [!practica]
> Cuando un ciclo tenga un límite, haz siempre la fila del **último valor**: el que debería entrar y el primero que no. Ahí viven los errores por uno.

## Errores frecuentes

> [!error] Llenar la tabla con lo que «debería» pasar
> Si escribes el valor que esperas en lugar del que produce la línea, la tabla confirmará tu error en vez de revelarlo. Calcula cada celda con la línea correspondiente.

> [!error] Olvidar la última evaluación de la condición
> La fila en la que la condición es falsa es la que explica por qué el ciclo termina y con qué valores. Sin ella no puedes detectar errores por uno.

> [!error] Actualizar dos variables en el orden equivocado
> Si dos líneas seguidas usan una variable que la otra cambia, el orden importa. Ejecuta y anota una línea a la vez.

> [!error] Probar solo con datos grandes
> Una tabla con 50 filas no se llena con cuidado. Elige la entrada más pequeña que ejercite todos los caminos.

````exercise
id: m02-l04-e1
type: comprension
prompt: |
  ¿Cuántas veces se ejecuta el cuerpo de este ciclo?

  ```pseudo
  i ← 1
  Mientras i ≤ 10
      i ← i × 2
  ```
choices:
  - text: "3"
    correct: false
    why: "Después de 3 vueltas i vale 8, y 8 ≤ 10 todavía es verdadero."
  - text: "4"
    correct: true
    why: "i pasa por 1, 2, 4 y 8 al entrar; después vale 16 y la condición es falsa."
  - text: "5"
    correct: false
    why: "Con i = 16 la condición ya es falsa; no hay quinta vuelta."
  - text: "10"
    correct: false
    why: "El ciclo no suma 1, multiplica por 2."
solution: |
  **4 vueltas.**

  | Vuelta | i al preguntar | ¿i ≤ 10? | i después |
  | --- | --- | --- | --- |
  | 1 | 1 | sí | 2 |
  | 2 | 2 | sí | 4 |
  | 3 | 4 | sí | 8 |
  | 4 | 8 | sí | 16 |
  | — | 16 | no | — |
````

````exercise
id: m02-l04-e2
type: prediccion
lang: pseudo
prompt: Construye la tabla de seguimiento y escribe exactamente lo que muestra el algoritmo.
code: |
  a ← 0
  b ← 1
  Repite 6 veces
      Muestra a
      siguiente ← a + b
      a ← b
      b ← siguiente
output: |
  0
  1
  1
  2
  3
  5
hints:
  - Columnas a, b, siguiente y Salida. Se muestra a antes de actualizar.
  - "Vuelta 3: a = 1, b = 2."
solution: |
  ```output
  0
  1
  1
  2
  3
  5
  ```

  | Vuelta | Muestra a | siguiente | a después | b después |
  | --- | --- | --- | --- | --- |
  | 1 | 0 | 1 | 1 | 1 |
  | 2 | 1 | 2 | 1 | 2 |
  | 3 | 1 | 3 | 2 | 3 |
  | 4 | 2 | 5 | 3 | 5 |
  | 5 | 3 | 8 | 5 | 8 |
  | 6 | 5 | 13 | 8 | 13 |

  Son los primeros números de la **sucesión de Fibonacci**: cada uno es la suma de los dos anteriores. La variable `siguiente` existe porque, si escribieras `a ← b` y luego `b ← a + b`, el segundo cálculo usaría la `a` ya modificada. El orden de las asignaciones importa.

  En Swift:

  ```swift
  var a = 0
  var b = 1
  for _ in 1...6 {
      print(a)
      let siguiente = a + b
      a = b
      b = siguiente
  }
  ```
````

````exercise
id: m02-l04-e3
type: completar
prompt: |
  Completa la tabla de seguimiento del algoritmo de suma de dígitos con n = 905.

  ```pseudo
  suma ← 0
  Mientras n > 0
      suma ← suma + (residuo de n ÷ 10)
      n ← n ÷ 10, división entera
  ```
code: |
  Momento    n      suma
  Inicio     905    0
  Vuelta 1   90     5
  Vuelta 2   [[1]]  [[2]]
  Vuelta 3   0      [[3]]
blanks:
  - id: "1"
    answers: ["9"]
  - id: "2"
    answers: ["5"]
  - id: "3"
    answers: ["14"]
solution: |
  | Momento | n | suma |
  | --- | --- | --- |
  | Inicio | 905 | 0 |
  | Vuelta 1 | 90 | 0 + 5 = 5 |
  | Vuelta 2 | 9 | 5 + 0 = 5 |
  | Vuelta 3 | 0 | 5 + 9 = 14 |

  En la vuelta 2 el residuo de 90 ÷ 10 es **0**, así que `suma` no cambia. El cero en medio del número es un buen caso de prueba: confirma que el algoritmo no se detiene al encontrar un dígito 0, solo cuando `n` llega a 0.
````

````exercise
id: m02-l04-e4
type: errores
prompt: |
  Este algoritmo debería mostrar el promedio de una lista de calificaciones. Con la lista [8, 6, 10] muestra 3 en lugar de 8. Todas las divisiones son enteras. Haz su tabla de seguimiento y selecciona el problema real. Después escribe la versión corregida.
code: |
  suma ← 0
  contador ← 0
  Para cada c en calificaciones
      suma ← c
      contador ← contador + 1
  Muestra suma ÷ contador
choices:
  - text: "`suma ← c` reemplaza la suma en lugar de acumular; debería ser `suma ← suma + c`."
    correct: true
    why: "La tabla muestra suma = 8, luego 6, luego 10: nunca acumula."
  - text: "`contador` debería empezar en 1."
    correct: false
    why: "Con 3 calificaciones, contador termina en 3, que es correcto."
  - text: "Falta proteger la división si la lista está vacía."
    correct: true
    why: "No explica el 3 de este ejemplo, pero con una lista vacía dividiría 0 ÷ 0. También es un problema real."
  - text: "El ciclo debería ser «Mientras» en lugar de «Para cada»."
    correct: false
    why: "«Para cada» es la estructura adecuada para recorrer una lista."
rubric:
  - Hice la tabla y vi que suma toma 8, 6 y 10 en lugar de acumular.
  - "Corregí la línea a `suma ← suma + c`."
  - Agregué la protección para la lista vacía.
  - Comprobé que con [8, 6, 10] el resultado es 8.
solution: |
  Tabla del algoritmo original:

  | Vuelta | c | suma | contador |
  | --- | --- | --- | --- |
  | Inicio | — | 0 | 0 |
  | 1 | 8 | 8 | 1 |
  | 2 | 6 | 6 | 2 |
  | 3 | 10 | 10 | 3 |

  Al final `suma` es 10, la última calificación, y `10 ÷ 3` con división entera es **3**. La tabla muestra la causa: `suma` nunca acumula, solo guarda la calificación actual.

  ```pseudo
  suma ← 0
  contador ← 0
  Para cada c en calificaciones
      suma ← suma + c
      contador ← contador + 1
  Si contador = 0 entonces
      Muestra «sin datos»
  Si no
      Muestra suma ÷ contador
  ```

  Con [8, 6, 10]: suma = 24, contador = 3, promedio = 8.
````

````exercise
id: m02-l04-e5
type: resolver
prompt: |
  Haz la tabla de seguimiento completa de este algoritmo con n = 6 y escribe qué muestra. Después explica en una frase qué calcula para cualquier n ≥ 1.

  ```pseudo
  resultado ← 1
  i ← 1
  Mientras i ≤ n
      resultado ← resultado × i
      i ← i + 1
  Muestra resultado
  ```
starter: |
  Vuelta | i al preguntar | ¿i ≤ n? | resultado después | i después
hints:
  - Son 6 vueltas y una última evaluación de la condición.
rubric:
  - La tabla tiene una fila por vuelta y la fila final con la condición falsa.
  - Los valores de resultado son 1, 2, 6, 24, 120 y 720.
  - La salida es 720.
  - "Identifiqué que calcula el factorial de n: 1 × 2 × … × n."
solution: |
  | Vuelta | i al preguntar | ¿i ≤ 6? | resultado después | i después |
  | --- | --- | --- | --- | --- |
  | 1 | 1 | sí | 1 | 2 |
  | 2 | 2 | sí | 2 | 3 |
  | 3 | 3 | sí | 6 | 4 |
  | 4 | 4 | sí | 24 | 5 |
  | 5 | 5 | sí | 120 | 6 |
  | 6 | 6 | sí | 720 | 7 |
  | — | 7 | no | — | — |

  Muestra **720**. Calcula el **factorial** de n, el producto 1 × 2 × … × n, que se escribe n!. El acumulador empieza en 1 y no en 0 porque es una multiplicación: empezar en 0 haría que todo el producto fuera 0.
````

## Resumen

- Una tabla de seguimiento tiene una columna por variable, condición y salida, y una fila por momento de la ejecución.
- Cada celda se calcula con la línea que la produce, nunca de memoria.
- Anota siempre la evaluación de la condición que termina el ciclo; ahí aparecen los errores por uno.
- El orden de las asignaciones importa cuando una variable depende de otra que cambia.
- Es la misma técnica que usarás con el depurador y en entrevistas: comparar lo esperado con lo real hasta encontrar la primera diferencia.
