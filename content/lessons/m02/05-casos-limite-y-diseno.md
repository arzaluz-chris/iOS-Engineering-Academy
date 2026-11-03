---
id: m02-l05
title: Casos límite y diseño de un algoritmo de principio a fin
description: Juntas todo el módulo en un método de seis pasos para diseñar un algoritmo, y aprendes a buscar a propósito las entradas que lo rompen antes de que lo haga alguien más.
module: m02
order: 5
level: inicial
minutes: 50
prerequisites: [m02-l03, m02-l04]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Aplicar un método de seis pasos para diseñar un algoritmo, desde entender el problema hasta verificarlo.
  - Enumerar los casos límite típicos de un problema con listas, números y textos.
  - Formular preguntas de aclaración cuando el enunciado es ambiguo.
  - Elegir un conjunto pequeño de casos de prueba que cubra caminos y bordes.
terms:
  - term: Caso límite
    definition: Entrada válida pero extrema o inusual, como una lista vacía, un solo elemento, el valor más pequeño o más grande permitido, o elementos repetidos.
  - term: Borde
    definition: Valor exactamente en el límite de una condición, como 6 en «aprobado si la calificación es 6 o más».
  - term: Precondición
    definition: Lo que el algoritmo supone de su entrada, por ejemplo «n ≥ 1». Si no se cumple, el algoritmo no promete nada.
  - term: Caso de prueba
    definition: Una entrada concreta junto con la salida que se espera para ella.
  - term: Pregunta de aclaración
    definition: Pregunta que se hace a quien pidió el programa para resolver una ambigüedad del enunciado antes de diseñar.
mastery:
  - Listar, para un problema nuevo con una lista de números, al menos cinco casos límite distintos.
  - Diseñar con el método de seis pasos un algoritmo para un problema no visto y entregar su pseudocódigo, su tabla de seguimiento y sus casos de prueba.
  - Formular dos preguntas de aclaración pertinentes para un enunciado ambiguo.
  - Explicar por qué un algoritmo que pasa con el ejemplo del enunciado todavía no está verificado.
resources: [swift-book-control-flow, swift-book-basic-operators]
cards:
  - id: m02-l05-c1
    front: Menciona cinco casos límite típicos de un problema con una lista de números.
    back: Lista vacía, un solo elemento, todos los elementos iguales, números negativos o cero, y el valor buscado en la primera o en la última posición.
  - id: m02-l05-c2
    front: ¿Cuáles son los seis pasos del método de diseño del curso?
    back: Entender, ejemplos, casos límite, algoritmo, seguimiento y verificación.
  - id: m02-l05-c3
    front: ¿Qué es una precondición?
    back: Lo que el algoritmo supone de su entrada, como «la lista no está vacía». Debe escribirse; si no se cumple, el algoritmo no promete nada.
  - id: m02-l05-c4
    front: ¿Qué años son bisiestos en el calendario gregoriano?
    back: Los divisibles entre 4, excepto los divisibles entre 100 que no lo son entre 400. 2000 sí, 1900 no, 2024 sí.
---

## La idea en una frase

Un algoritmo no está terminado cuando funciona con el ejemplo del enunciado, sino cuando sabes con qué entradas podría fallar y comprobaste que no falla.

## El método de seis pasos

Este módulo te dio las herramientas por separado. Juntas forman un método que usarás en cada reto de código del curso y en cada entrevista técnica:

| Paso | Qué haces | Herramienta |
| --- | --- | --- |
| 1. Entender | Escribes entrada, salida y reglas. Preguntas lo que no está claro. | Abstracción |
| 2. Ejemplos | Resuelves a mano dos o tres ejemplos normales. | Ejecución manual |
| 3. Casos límite | Buscas las entradas extremas y decides qué debe pasar con cada una. | Esta lección |
| 4. Algoritmo | Lo escribes por subproblemas. | Descomposición, pseudocódigo, diagramas |
| 5. Seguimiento | Ejecutas el algoritmo con tus ejemplos y casos límite. | Tablas de seguimiento |
| 6. Verificación | Comparas cada salida con la esperada. Si alguna difiere, vuelves al paso 4. | Casos de prueba |

Los pasos 1 a 3 ocurren **antes** de escribir el algoritmo. Es tentador saltarlos. Es también la razón más común por la que una solución termina reescrita.

## Casos límite

**Definición sencilla:** las entradas raras pero válidas.

**Explicación técnica:** un caso límite es una entrada que cumple las reglas del problema pero está en un extremo: el tamaño mínimo, el valor más grande, todos los elementos iguales. Los algoritmos fallan desproporcionadamente en esos extremos porque quien los diseñó pensó en el caso típico.

### Lista de revisión

| Tipo de entrada | Casos límite que debes considerar |
| --- | --- |
| Lista | Vacía; un elemento; dos elementos; todos iguales; ya ordenada; en orden inverso; el elemento buscado al principio o al final; repetidos |
| Número | Cero; negativo; uno; el mínimo y el máximo permitidos; valores justo en el borde de cada condición |
| Texto | Vacío; un carácter; solo espacios; mayúsculas y minúsculas; acentos; emojis |
| Dos valores | Iguales; el primero mayor; el segundo mayor |

No todos aplican siempre. La lista sirve para **no olvidar** ninguno; luego decides cuáles importan para tu problema.

### Bordes de una condición

Si una regla dice «aprobado con 6 o más», los valores importantes son **5 y 6**: el último que no cumple y el primero que sí. Probar con 3 y 9 no distinguiría entre `≥ 6` y `> 6`, que es exactamente el error que quieres atrapar.

### Números demasiado grandes

En una computadora, los números enteros tienen un tamaño máximo. En Swift, si una suma o multiplicación de enteros se pasa de ese máximo, el programa **se detiene con un error en ejecución** en lugar de dar un resultado incorrecto. Lo estudiarás en el Módulo 4. Por ahora, basta con preguntarte: ¿qué tan grandes pueden ser los números de mi entrada?

## Ejemplo mínimo: año bisiesto

Paso 1, **entender**. En el calendario gregoriano, un año es bisiesto si es divisible entre 4, excepto los divisibles entre 100, que solo son bisiestos si también son divisibles entre 400.

Paso 2, **ejemplos**: 2024 es bisiesto; 2023 no.

Paso 3, **casos límite**. La regla tiene tres condiciones; cada una necesita un año que la active:

| Año | ¿÷ 4? | ¿÷ 100? | ¿÷ 400? | ¿Bisiesto? |
| --- | --- | --- | --- | --- |
| 2023 | no | — | — | no |
| 2024 | sí | no | — | sí |
| 1900 | sí | sí | no | no |
| 2000 | sí | sí | sí | sí |

Paso 4, **algoritmo**:

```pseudo
Entrada: un año, entero positivo
Salida: sí o no

Si el residuo de año ÷ 400 es 0 entonces
    Devuelve sí
Si el residuo de año ÷ 100 es 0 entonces
    Devuelve no
Si el residuo de año ÷ 4 es 0 entonces
    Devuelve sí
Devuelve no
```

Línea por línea:

1. Se pregunta primero la regla **más específica**, 400. Un año divisible entre 400 también lo es entre 100 y entre 4; si preguntaras 4 primero, 1900 saldría bisiesto.
2. Si llegó aquí, no es divisible entre 400. Si lo es entre 100, no es bisiesto.
3. Si llegó aquí, no es divisible entre 100. Basta con que lo sea entre 4.
4. En cualquier otro caso, no es bisiesto.

Pasos 5 y 6: el ejercicio de predicción de esta lección ejecuta este algoritmo con los cuatro años de la tabla.

## Ejemplo práctico: el segundo mayor

Problema: «Dada una lista de puntuaciones, devuelve la segunda más alta».

**Paso 1 y preguntas de aclaración.** El enunciado parece claro hasta que piensas en los casos límite:

- Con `[9, 9, 4]`, ¿la segunda más alta es 9 o 4? Depende de si cuentan **posiciones** o **valores distintos**.
- Con `[7]` o `[]`, no hay segunda. ¿Qué se devuelve?
- ¿Puede haber puntuaciones negativas?

Supón que la respuesta es: valores distintos; si no existe, devuelve «no existe»; sí puede haber negativos.

**Paso 3, casos límite y salidas esperadas:**

| Entrada | Salida esperada | Por qué |
| --- | --- | --- |
| `[5, 9, 4]` | 5 | Caso normal |
| `[9, 9, 4]` | 4 | Máximo repetido |
| `[7, 7, 7]` | no existe | Todos iguales |
| `[7]` | no existe | Un elemento |
| `[]` | no existe | Vacía |
| `[-3, -8]` | −8 | Negativos |
| `[4, 9]` | 4 | El mayor al final |

**Paso 4, algoritmo**, usando el patrón del mayor dos veces:

```pseudo
Entrada: una lista de enteros
Salida: el segundo valor distinto más alto, o «no existe»

Si la lista está vacía entonces
    Devuelve «no existe»
mayor ← el mayor de la lista
segundo ← ninguno
Para cada p en la lista
    Si p ≠ mayor entonces
        Si segundo es ninguno o p > segundo entonces
            segundo ← p
Si segundo es ninguno entonces
    Devuelve «no existe»
Devuelve segundo
```

Observa que `segundo` empieza en **ninguno**, no en 0. Si empezara en 0, con `[-3, -8]` respondería 0, un número que ni siquiera está en la lista. Swift tiene una forma precisa de representar «ninguno», los **opcionales**, que estudiarás en la etapa de Swift.

**Paso 5, seguimiento** con `[9, 9, 4]`: `mayor` = 9. Los dos 9 se saltan por ser iguales a `mayor`. Con 4, `segundo` es ninguno, así que `segundo ← 4`. Devuelve 4, como esperábamos.

## Errores frecuentes

> [!error] Diseñar solo para el ejemplo del enunciado
> El ejemplo del enunciado casi nunca incluye los casos límite. Si tu algoritmo solo se probó con él, no está verificado.

> [!error] Inicializar con un valor que puede ser una respuesta válida
> Empezar un mínimo, un máximo o un «segundo mayor» en 0 falla en cuanto la entrada tiene negativos. Usa un elemento real o «ninguno».

> [!error] Probar lejos de los bordes
> Para «mayor o igual que 6», prueba con 5 y 6. Con 3 y 9 no distingues `≥` de `>`.

> [!error] Resolver una ambigüedad en silencio
> Si el enunciado admite dos lecturas, pregunta o escribe tu suposición. En una entrevista, preguntar es parte de lo que se evalúa.

````exercise
id: m02-l05-e1
type: comprension
multiple: true
prompt: Un algoritmo calcula el **promedio** de una lista de calificaciones de 0 a 10. ¿Cuáles de estas entradas son casos límite que vale la pena probar? Selecciona todos los que apliquen.
choices:
  - text: "La lista vacía, `[]`."
    correct: true
    why: Provoca una división entre 0 si no se protege.
  - text: "Una sola calificación, `[7]`."
    correct: true
    why: El promedio debe ser la propia calificación; verifica el conteo mínimo.
  - text: "Calificaciones en los extremos del rango, `[0, 10]`."
    correct: true
    why: Comprueba que 0 se cuenta como dato y no como «vacío».
  - text: "Una lista normal, `[7, 8, 9]`."
    correct: false
    why: Es un ejemplo típico, útil, pero no es un caso límite.
  - text: "Calificaciones con decimales, `[7, 8]`, cuyo promedio es 7.5."
    correct: true
    why: Revela si el algoritmo usa división entera y pierde el .5.
solution: |
  Son casos límite **la lista vacía** (división entre 0), **un solo elemento** (tamaño mínimo), **los extremos 0 y 10** (el 0 a veces se confunde con «sin dato») y **un promedio no entero** (división entera contra decimal). `[7, 8, 9]` es un buen ejemplo normal para el paso 2, pero no está en ningún extremo.
````

````exercise
id: m02-l05-e2
type: prediccion
lang: pseudo
prompt: Ejecuta el algoritmo de año bisiesto de la lección con cada año y escribe exactamente lo que se muestra.
code: |
  Para cada año en [1900, 2000, 2023, 2024]
      Si el residuo de año ÷ 400 es 0 entonces
          Muestra año, «sí»
      Si no, si el residuo de año ÷ 100 es 0 entonces
          Muestra año, «no»
      Si no, si el residuo de año ÷ 4 es 0 entonces
          Muestra año, «sí»
      Si no
          Muestra año, «no»
output: |
  1900 no
  2000 sí
  2023 no
  2024 sí
hints:
  - "«Muestra año, «sí»» escribe el año, un espacio y el texto."
  - 1900 es divisible entre 100 pero no entre 400.
solution: |
  ```output
  1900 no
  2000 sí
  2023 no
  2024 sí
  ```

  - **1900**: no es divisible entre 400; sí entre 100, así que no es bisiesto.
  - **2000**: divisible entre 400; es bisiesto.
  - **2023**: no es divisible entre 400, ni entre 100, ni entre 4.
  - **2024**: no es divisible entre 400 ni entre 100, pero sí entre 4.

  Los cuatro años recorren los cuatro caminos del algoritmo; ese es el criterio con el que se eligieron. En Swift, `print` con dos valores los separa con un espacio:

  ```swift
  for año in [1900, 2000, 2023, 2024] {
      if año % 400 == 0 {
          print(año, "sí")
      } else if año % 100 == 0 {
          print(año, "no")
      } else if año % 4 == 0 {
          print(año, "sí")
      } else {
          print(año, "no")
      }
  }
  ```
````

````exercise
id: m02-l05-e3
type: explicar
prompt: |
  Un compañero escribe este algoritmo para «el menor de una lista de números enteros» y dice que funciona porque lo probó con [5, 3, 8] y dio 3. Explica por qué su prueba no es suficiente, con qué entrada falla y cómo lo corregirías.
code: |
  menor ← 0
  Para cada n en números
      Si n < menor entonces
          menor ← n
  Muestra menor
rubric:
  - "Expliqué que con [5, 3, 8] el resultado correcto es 3, pero el algoritmo muestra 0."
  - Di una entrada concreta en la que falla y la salida incorrecta que produce.
  - Propuse inicializar con el primer elemento y manejar la lista vacía.
  - Mencioné que un solo ejemplo no cubre los casos límite.
solution: |
  En realidad la prueba de tu compañero **ya falla**: con `[5, 3, 8]`, `menor` empieza en 0 y ningún número es menor que 0, así que el algoritmo muestra **0**, no 3. Si creyó ver un 3, no hizo la ejecución manual. Falla con cualquier lista de números positivos, y con una lista vacía muestra 0 como si fuera un dato.

  La causa es inicializar con un valor inventado. Corrección:

  ```pseudo
  Si números está vacía entonces
      Muestra «sin datos»
  Si no
      menor ← el primer número
      Para cada n en números
          Si n < menor entonces
              menor ← n
      Muestra menor
  ```

  La lección general: una prueba solo cuenta si comparas la salida real con la esperada, y un ejemplo no basta; se necesitan casos límite (vacía, un elemento, todos positivos, todos negativos).
````

````exercise
id: m02-l05-e4
type: resolver
prompt: |
  Aplica los pasos 1 a 5 del método a este problema y entrega cada paso por escrito:

  > Dado un número entero positivo, determina si es **capicúa**, es decir, si se lee igual de izquierda a derecha que de derecha a izquierda. Por ejemplo, 121 y 7 son capicúas; 123 no.

  Puedes reutilizar la técnica de la lección de tablas de seguimiento para separar los dígitos de un número.
starter: |
  1. Entender:
  2. Ejemplos:
  3. Casos límite:
  4. Algoritmo:
  5. Seguimiento:
hints:
  - "Una idea: construye el número al revés dígito por dígito y compáralo con el original."
  - "Para agregar un dígito d al final de un número r: r ← r × 10 + d."
  - Casos límite útiles, un solo dígito, un número que termina en 0 como 120, y un número con cantidad par de dígitos como 1221.
rubric:
  - Escribí entrada, salida y la precondición (entero positivo).
  - Incluí al menos dos ejemplos que sí son capicúas y uno que no.
  - Mis casos límite incluyen un solo dígito, un número que termina en 0 y uno con cantidad par de dígitos.
  - El algoritmo guarda el número original antes de modificarlo.
  - Hice la tabla de seguimiento con al menos un ejemplo y la salida coincide con la esperada.
solution: |
  **1. Entender.** Entrada: un entero n ≥ 1. Salida: sí o no. Regla: n es capicúa si es igual a n con sus dígitos invertidos.

  **2. Ejemplos.** 121 → sí. 123 → no. 4554 → sí.

  **3. Casos límite.** 7 (un dígito) → sí. 120 → no, porque al revés es 021, es decir, 21. 1221 (cantidad par) → sí. 10 → no.

  **4. Algoritmo.**

  ```pseudo
  Entrada: un entero n ≥ 1
  Salida: sí o no

  original ← n
  invertido ← 0
  Mientras n > 0
      dígito ← residuo de n ÷ 10
      invertido ← invertido × 10 + dígito
      n ← n ÷ 10, división entera
  Si invertido = original entonces
      Devuelve sí
  Si no
      Devuelve no
  ```

  **5. Seguimiento** con 120:

  | Vuelta | n al preguntar | dígito | invertido | n después |
  | --- | --- | --- | --- | --- |
  | 1 | 120 | 0 | 0 | 12 |
  | 2 | 12 | 2 | 2 | 1 |
  | 3 | 1 | 1 | 21 | 0 |

  `invertido` es 21 ≠ 120: no es capicúa, como esperábamos. Guardar `original` es imprescindible: al terminar el ciclo `n` vale 0.
````

````exercise
id: m02-l05-e5
type: diseno
prompt: |
  Una tienda quiere un algoritmo que dé el cambio con **la menor cantidad de monedas posible**, usando monedas de 10, 5, 2 y 1 peso. Antes de escribir el algoritmo, entrega: tus preguntas de aclaración, tu tabla de casos de prueba con la salida esperada y una idea del algoritmo en dos o tres frases. Después escribe el pseudocódigo.
rubric:
  - Hice al menos dos preguntas de aclaración pertinentes, por ejemplo qué pasa si el cambio es 0 o si se acaban las monedas de algún tipo.
  - Mis casos de prueba incluyen cambio 0, un valor que solo requiere una moneda y uno que requiere todas las denominaciones.
  - El algoritmo empieza por la moneda más grande.
  - El pseudocódigo usa división entera y residuo, o un ciclo que resta, de forma correcta.
  - Verifiqué al menos un caso con una tabla de seguimiento.
solution: |
  **Preguntas de aclaración**

  - ¿El cambio puede ser 0? Supongo que sí, y la respuesta es «ninguna moneda».
  - ¿Hay monedas ilimitadas de cada tipo? Supongo que sí. Si no, el problema cambia por completo.
  - ¿El cambio siempre es un entero de pesos? Supongo que sí.

  **Casos de prueba**

  | Cambio | Monedas esperadas |
  | --- | --- |
  | 0 | ninguna |
  | 10 | 10 |
  | 18 | 10, 5, 2, 1 |
  | 4 | 2, 2 |
  | 27 | 10, 10, 5, 2 |

  **Idea.** Usa tantas monedas de la más grande como quepan, y con lo que sobra repite con la siguiente. Con estas denominaciones, esta estrategia da el mínimo de monedas.

  ```pseudo
  Entrada: cambio, entero ≥ 0
  Salida: cuántas monedas de cada tipo

  restante ← cambio
  Para cada moneda en [10, 5, 2, 1]
      cantidad ← restante ÷ moneda, división entera
      restante ← residuo de restante ÷ moneda
      Si cantidad > 0 entonces
          Muestra cantidad, «de», moneda
  ```

  Seguimiento con 18: con 10, cantidad 1, restante 8; con 5, cantidad 1, restante 3; con 2, cantidad 1, restante 1; con 1, cantidad 1, restante 0. Cuatro monedas, como esperábamos.

  > [!aviso]
  > Esta estrategia, llamada **voraz** (*greedy*), no da el mínimo con cualquier conjunto de monedas. Con monedas de 1, 3 y 4 y un cambio de 6, la estrategia voraz da 4 + 1 + 1 (tres monedas), pero 3 + 3 son dos. Estudiarás cuándo una estrategia voraz es correcta en la etapa de algoritmos.
````

## Resumen

- Método de seis pasos: entender, ejemplos, casos límite, algoritmo, seguimiento y verificación.
- Los casos límite se buscan a propósito con una lista de revisión: vacío, uno, todos iguales, negativos, bordes, repetidos.
- Prueba los bordes de cada condición: el último valor que no cumple y el primero que sí.
- No inicialices con un valor inventado; usa un elemento real o «ninguno».
- Ante una ambigüedad, pregunta o escribe tu suposición antes de diseñar.
