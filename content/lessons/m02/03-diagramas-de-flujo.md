---
id: m02-l03
title: Diagramas de flujo
description: Dibujas un algoritmo para ver de un vistazo sus caminos. Aprendes los símbolos, cómo se representan decisiones y ciclos, y cómo pasar de un diagrama a pseudocódigo y de regreso.
module: m02
order: 3
level: inicial
minutes: 40
prerequisites: [m02-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Reconocer los símbolos básicos de un diagrama de flujo y su significado.
  - Dibujar el diagrama de un algoritmo con decisiones y ciclos.
  - Convertir un diagrama de flujo en pseudocódigo y un pseudocódigo en diagrama.
  - Contar los caminos posibles de un algoritmo a partir de su diagrama.
terms:
  - term: Diagrama de flujo
    definition: Representación gráfica de un algoritmo en la que cada paso es una figura y las flechas indican el orden de ejecución.
  - term: Terminal
    definition: Óvalo que marca el inicio o el fin del algoritmo.
  - term: Proceso
    definition: Rectángulo que representa una operación o asignación, como «total ← total + p».
  - term: Decisión
    definition: Rombo con una condición; de él salen dos flechas, una para «sí» y otra para «no».
  - term: Entrada/salida
    definition: Paralelogramo que representa leer un dato o mostrar un resultado.
  - term: Camino
    definition: Una secuencia concreta de figuras que se recorre desde el inicio hasta el fin con ciertos datos de entrada.
mastery:
  - Dibujar, sin consultar la lección, el diagrama de flujo de un algoritmo con una decisión y un ciclo.
  - Traducir un diagrama de flujo de una página a pseudocódigo con las convenciones del curso.
  - Indicar qué flecha de un diagrama forma un ciclo y qué condición lo termina.
  - Proponer una entrada que recorra cada camino de un diagrama con una o dos decisiones.
resources: [swift-book-control-flow]
cards:
  - id: m02-l03-c1
    front: ¿Qué figura representa una decisión en un diagrama de flujo y cuántas salidas tiene?
    back: Un rombo. Tiene dos salidas, una para «sí» (verdadero) y otra para «no» (falso).
  - id: m02-l03-c2
    front: ¿Cómo se ve un ciclo en un diagrama de flujo?
    back: Como una flecha que regresa a una figura anterior, normalmente a la decisión que pregunta si hay que repetir.
  - id: m02-l03-c3
    front: ¿Para qué sirve contar los caminos de un diagrama?
    back: Para elegir casos de prueba. Cada camino necesita al menos una entrada que lo recorra; si un camino nunca se prueba, sus errores pasan inadvertidos.
---

## La idea en una frase

Un diagrama de flujo es un mapa del algoritmo: muestra todos sus caminos a la vez, algo que el texto esconde.

## Cuándo conviene un diagrama

El pseudocódigo se lee de arriba hacia abajo. Cuando un algoritmo tiene varias decisiones o un ciclo con varias salidas, seguir el texto obliga a retener mucho en la cabeza. Un diagrama muestra los caminos de un vistazo.

No todo merece diagrama. Para tres pasos en secuencia es más lento dibujar que escribir. El diagrama paga su costo cuando hay decisiones anidadas, ciclos o cuando necesitas explicarle el algoritmo a alguien que no programa.

## Los símbolos

Existe una norma internacional para estos símbolos (ISO 5807), pero en la práctica casi todo el mundo usa solo estos cinco:

| Figura | Nombre | Significado |
| --- | --- | --- |
| Óvalo | Terminal | Inicio o fin |
| Rectángulo | Proceso | Una operación o asignación |
| Rombo | Decisión | Una condición con salida «sí» y salida «no» |
| Paralelogramo | Entrada/salida | Leer un dato o mostrar un resultado |
| Flecha | Flujo | Qué figura sigue |

En este curso los diagramas se escriben con texto, para que puedas copiarlos y editarlos. Las figuras se indican así:

```plaintext
( Inicio )         óvalo: terminal
[ total ← 0 ]      rectángulo: proceso
< ¿n > 0? >        rombo: decisión
/ Muestra n /      paralelogramo: entrada/salida
```

En papel o en una pizarra, dibuja las figuras reales.

## Ejemplo mínimo: par o impar

El algoritmo de la lección anterior, como diagrama:

```plaintext
        ( Inicio )
            |
            v
        / Lee n /
            |
            v
   < ¿residuo de n ÷ 2 = 0? >
       |sí            |no
       v              v
  / Muestra    /  / Muestra    /
  / «par»      /  / «impar»    /
       |              |
       +------+-------+
              |
              v
          ( Fin )
```

Línea por línea:

1. **Inicio**: todo diagrama tiene exactamente un inicio.
2. **Lee n**: la entrada del algoritmo, un paralelogramo.
3. **El rombo** hace una pregunta de sí o no. De él salen exactamente dos flechas, cada una con su etiqueta.
4. **Cada rama** muestra un texto distinto.
5. **Las ramas se unen** antes del fin. Un diagrama puede tener varias figuras de fin, pero unir las ramas deja claro que, tome el camino que tome, el algoritmo termina.

Este diagrama tiene **dos caminos**: uno para números pares y otro para impares. Para probarlo bastan dos entradas, por ejemplo 4 y 7.

## Ciclos: una flecha que regresa

Un ciclo aparece como una flecha que **vuelve** a una figura anterior. Este diagrama corresponde a un `Mientras`:

```plaintext
        ( Inicio )
            |
            v
       [ n ← 10 ]
            |
            v
   +--> < ¿n > 0? > --no--> ( Fin )
   |        |sí
   |        v
   |   / Muestra n /
   |        |
   |        v
   |   [ n ← n − 4 ]
   |        |
   +--------+
```

La condición está **antes** del cuerpo: si `n` empezara en 0, el algoritmo terminaría sin mostrar nada. Es exactamente cómo funciona un `Mientras`. La flecha que regresa sale del último proceso del cuerpo, `n ← n − 4`, que es lo que acerca la condición a ser falsa.

## Ejemplo práctico: tres intentos de NIP

Un cajero pide el NIP y permite como máximo tres intentos.

```plaintext
           ( Inicio )
               |
               v
         [ intentos ← 0 ]
               |
               v
  +-----> / Lee nip /
  |            |
  |            v
  |    [ intentos ← intentos + 1 ]
  |            |
  |            v
  |     < ¿nip correcto? > --sí--> / Muestra «Bienvenido» / --> ( Fin )
  |            |no
  |            v
  |     < ¿intentos < 3? > --no--> / Muestra «Tarjeta retenida» / --> ( Fin )
  |            |sí
  +------------+
```

El mismo algoritmo en pseudocódigo:

```pseudo
intentos ← 0
Repite
    Lee nip
    intentos ← intentos + 1
    Si nip es correcto entonces
        Muestra «Bienvenido»
        Termina
    Si intentos = 3 entonces
        Muestra «Tarjeta retenida»
        Termina
```

Observa en el diagrama cosas que en el texto cuestan más:

- Hay **dos salidas** del ciclo, una por éxito y otra por agotar los intentos.
- El ciclo tiene un **límite garantizado**: `intentos` aumenta en cada vuelta y la segunda decisión lo corta en 3. Aunque la persona nunca acierte, el algoritmo termina.
- Hay **cuatro caminos** distintos: acertar al primer, segundo o tercer intento, o fallar tres veces. Un buen conjunto de pruebas recorre los cuatro.

> [!practica]
> En una app real el contador de intentos no puede vivir solo en el teléfono: alguien podría reiniciar la app para obtener más intentos. Las reglas de seguridad se aplican del lado del servidor o de un componente protegido. Lo estudiarás en el módulo de desarrollo seguro.

## Errores frecuentes

> [!error] Un rombo con una sola salida o sin etiquetas
> Toda decisión tiene dos salidas, «sí» y «no», y ambas deben estar etiquetadas. Una flecha sin etiqueta obliga a adivinar.

> [!error] Ciclos que no tienen salida
> Sigue la flecha que regresa: si en ese recorrido ningún proceso cambia algo de la condición, el ciclo no termina nunca.

> [!error] Flechas que se cruzan sin necesidad
> Si el diagrama se vuelve una maraña, reorganiza las figuras o divide el algoritmo en procedimientos con nombre, cada uno con su diagrama.

> [!error] Dibujar cada línea de código
> Un diagrama con cien figuras no ayuda a nadie. Agrupa los pasos en secuencia en un solo rectángulo y deja el detalle para el pseudocódigo.

````exercise
id: m02-l03-e1
type: comprension
prompt: En un diagrama de flujo, ¿qué figura usarías para «¿el saldo alcanza para el retiro?»?
choices:
  - text: Rectángulo
    correct: false
    why: El rectángulo es para procesos, como restar el retiro del saldo.
  - text: Rombo
    correct: true
    why: Es una pregunta de sí o no; tendrá dos salidas.
  - text: Paralelogramo
    correct: false
    why: El paralelogramo es para leer datos o mostrar resultados.
  - text: Óvalo
    correct: false
    why: El óvalo marca el inicio o el fin.
solution: |
  Un **rombo**, porque es una decisión: la respuesta es sí o no y el algoritmo sigue por caminos distintos según la respuesta. Del rombo salen dos flechas, «sí» hacia el retiro y «no» hacia un mensaje de saldo insuficiente.
````

````exercise
id: m02-l03-e2
type: prediccion
lang: pseudo
prompt: Sigue el diagrama del ciclo de la lección y escribe exactamente lo que muestra.
code: |
  ( Inicio ) --> [ n ← 10 ]
                     |
                     v
            +--> < ¿n > 0? > --no--> ( Fin )
            |        |sí
            |        v
            |   / Muestra n /
            |        |
            |        v
            |   [ n ← n − 4 ]
            |        |
            +--------+
output: |
  10
  6
  2
hints:
  - Después de mostrar 2, n vale −2. ¿Se cumple n > 0?
solution: |
  ```output
  10
  6
  2
  ```

  | Vuelta | n al preguntar | ¿n > 0? | Muestra | n después |
  | --- | --- | --- | --- | --- |
  | 1 | 10 | sí | 10 | 6 |
  | 2 | 6 | sí | 6 | 2 |
  | 3 | 2 | sí | 2 | −2 |
  | 4 | −2 | no | — | — |

  El ciclo no se detiene en 0 exactamente: se detiene la primera vez que la condición es falsa, y eso ocurre con −2. Así se escribe en Swift:

  ```swift
  var n = 10
  while n > 0 {
      print(n)
      n = n - 4
  }
  ```
````

````exercise
id: m02-l03-e3
type: explicar
prompt: Traduce este diagrama a pseudocódigo con las convenciones del curso y explica qué calcula.
code: |
  ( Inicio ) --> / Lee edad /
                      |
                      v
             < ¿edad ≥ 18? > --sí--> / Muestra «General» / -----+
                    |no                                         |
                    v                                           |
             < ¿edad ≥ 12? > --sí--> / Muestra «Joven» / -------+
                    |no                                         |
                    v                                           |
             / Muestra «Infantil» / ----------------------------+
                                                                |
                                                                v
                                                            ( Fin )
rubric:
  - Mi pseudocódigo tiene una decisión anidada dentro del «Si no» de la primera.
  - Las condiciones están en el mismo orden que en el diagrama.
  - Expliqué que clasifica una edad en tres categorías.
  - Dije qué categoría corresponde a 12 y a 18 exactamente.
solution: |
  ```pseudo
  Entrada: edad
  Salida: la categoría de boleto

  Si edad ≥ 18 entonces
      Muestra «General»
  Si no
      Si edad ≥ 12 entonces
          Muestra «Joven»
      Si no
          Muestra «Infantil»
  ```

  Clasifica una edad en tres categorías: 18 o más es General; de 12 a 17, Joven; menos de 12, Infantil. Con 12 exactamente se muestra «Joven» y con 18, «General», porque las condiciones usan `≥`.

  El orden importa: la segunda pregunta solo se hace si la primera respondió «no», así que «edad ≥ 12» en realidad significa «de 12 a 17». Si se invirtiera el orden, una persona de 30 años recibiría «Joven». El diagrama tiene tres caminos; para probarlo bastan tres edades, y conviene elegir los bordes: 11, 12, 17 y 18.
````

````exercise
id: m02-l03-e4
type: resolver
prompt: |
  Dibuja con texto, usando la notación del curso, el diagrama de flujo de este algoritmo:

  Lee calificaciones de una en una. Si la calificación está fuera del rango de 0 a 10, muestra «inválida» y vuelve a pedirla. Cuando sea válida, muestra «aprobado» si es 6 o más y «reprobado» en otro caso.

  Después indica cuántos caminos tiene y propone una entrada para cada uno.
starter: |
  ( Inicio )
      |
      v
hints:
  - La validación es un ciclo, la flecha de «inválida» regresa a leer.
  - "Fuera de rango significa menor que 0 o mayor que 10. Puedes usar dos rombos o uno con «o»."
rubric:
  - Tiene un solo inicio y las salidas llegan a un fin.
  - Cada rombo tiene dos salidas etiquetadas con sí y no.
  - La flecha de «inválida» regresa a la lectura de la calificación.
  - La decisión de aprobado solo se alcanza con una calificación válida.
  - Propuse entradas que recorren cada camino, incluidos los bordes 0, 6 y 10.
solution: |
  ```plaintext
            ( Inicio )
                |
                v
     +--> / Lee c /
     |          |
     |          v
     |   < ¿c < 0 o c > 10? > --no--> < ¿c ≥ 6? > --sí--> / Muestra «aprobado» / --+
     |          |sí                        |no                                     |
     |          v                          v                                       |
     +-- / Muestra «inválida» /     / Muestra «reprobado» / -----------------------+
                                                                                    |
                                                                                    v
                                                                                ( Fin )
  ```

  Caminos y entradas de prueba:

  1. Válida y aprobatoria: `8`. Bordes: `6` y `10`.
  2. Válida y reprobatoria: `3`. Borde: `0` y `5`.
  3. Inválida y después válida: `11` y luego `7`; `-1` y luego `4`.

  El tercer camino es un ciclo: puede dar varias vueltas. Prueba al menos una entrada inválida por cada lado del rango.
````

````exercise
id: m02-l03-e5
type: diseno
prompt: |
  Diseña el diagrama de flujo de una máquina expendedora que vende un producto de 15 pesos y acepta monedas de 1, 2, 5 y 10. Debe pedir monedas hasta juntar al menos 15, rechazar cualquier otra moneda y al final mostrar el cambio. Escribe también una lista de los caminos que probarías.
rubric:
  - Hay un acumulador del dinero ingresado con valor inicial 0.
  - Las monedas no válidas se rechazan sin sumarse y el ciclo continúa.
  - El ciclo termina cuando el acumulado es mayor o igual que 15.
  - El cambio se calcula como acumulado − 15 y se muestra.
  - Los casos de prueba incluyen pago exacto, pago con cambio y una moneda rechazada.
solution: |
  ```plaintext
          ( Inicio )
              |
              v
       [ pagado ← 0 ]
              |
              v
  +--> < ¿pagado < 15? > --no--> [ cambio ← pagado − 15 ] --> / Muestra cambio / --> ( Fin )
  |           |sí
  |           v
  |     / Lee moneda /
  |           |
  |           v
  |   < ¿moneda es 1, 2, 5 o 10? > --no--> / Muestra «Moneda rechazada» / --+
  |           |sí                                                            |
  |           v                                                            |
  |   [ pagado ← pagado + moneda ]                                           |
  |           |                                                            |
  +-----------+------------------------------------------------------------+
  ```

  Casos de prueba:

  - Pago exacto: 10 y 5. Cambio 0.
  - Pago con cambio: 10, 2 y 5. Pagado 17, cambio 2.
  - Moneda rechazada: 20 (rechazada), luego 10 y 5. Cambio 0.
  - Muchas monedas pequeñas: quince monedas de 1. El ciclo da quince vueltas.

  El ciclo siempre termina si la persona sigue metiendo monedas válidas, porque cada una aumenta `pagado`. ¿Y si deja de meter monedas? Ese caso no está en el diagrama: una máquina real necesita un botón de cancelar que devuelva lo pagado. Detectar estos huecos es justo para lo que sirve diseñar antes de programar.
````

## Resumen

- Óvalo para inicio y fin, rectángulo para procesos, rombo para decisiones, paralelogramo para entrada y salida, flechas para el orden.
- Un rombo siempre tiene dos salidas etiquetadas.
- Un ciclo es una flecha que regresa; dentro de ese recorrido algo debe acercar la condición a ser falsa.
- Cada camino del diagrama necesita al menos un caso de prueba; elige entradas en los bordes de cada condición.
- Usa diagramas cuando hay decisiones anidadas o ciclos con varias salidas; para secuencias simples, basta el pseudocódigo.
