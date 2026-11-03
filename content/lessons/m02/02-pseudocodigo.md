---
id: m02-l02
title: "Pseudocódigo: escribir algoritmos con precisión"
description: Una notación sencilla para escribir algoritmos sin pelear con la sintaxis de un lenguaje. Aprendes las convenciones del curso, las cuatro estructuras de cualquier algoritmo y cómo cada línea se traducirá después a Swift.
module: m02
order: 2
level: inicial
minutes: 50
prerequisites: [m02-l01]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Escribir algoritmos en pseudocódigo con las convenciones del curso.
  - Usar las cuatro estructuras básicas, secuencia, asignación, decisión y repetición.
  - Distinguir una repetición con número conocido de pasos de una que depende de una condición.
  - Detectar pasos ambiguos, variables sin valor inicial y repeticiones que nunca terminan.
terms:
  - term: Pseudocódigo
    definition: Descripción de un algoritmo con palabras y una estructura parecida a la de un lenguaje de programación, pero sin sus reglas de sintaxis. No se ejecuta; se lee.
  - term: Variable
    definition: Un nombre que guarda un valor que puede cambiar durante el algoritmo, como «total» o «contador».
  - term: Asignación
    definition: "Guardar un valor en una variable. En el pseudocódigo del curso se escribe con una flecha: total ← 0."
  - term: Condición
    definition: Una pregunta que solo puede responderse con verdadero o falso, como «n > 10».
  - term: Decisión
    definition: Estructura que ejecuta unos pasos u otros según una condición. Se escribe «Si … entonces … Si no …».
  - term: Repetición
    definition: Estructura que ejecuta varias veces los mismos pasos. También se llama ciclo o bucle.
  - term: Sangría
    definition: Espacio al inicio de una línea que indica que pertenece al bloque de la línea anterior, por ejemplo a un «Si» o a un «Para cada».
mastery:
  - Escribir en pseudocódigo, sin consultar la lección, un algoritmo con una decisión y una repetición.
  - Traducir un algoritmo escrito en prosa a pseudocódigo con las convenciones del curso.
  - Señalar en un pseudocódigo ajeno una variable sin valor inicial o un ciclo que no termina, y corregirlo.
  - "Decidir entre «Para cada» y «Mientras» y justificar la elección."
resources: [swift-book-control-flow]
cards:
  - id: m02-l02-c1
    front: ¿Qué significa `total ← total + precio` en pseudocódigo?
    back: Calcula total + precio con el valor actual de total y guarda el resultado de nuevo en total. La flecha es una asignación, no una igualdad matemática.
  - id: m02-l02-c2
    front: ¿Cuáles son las cuatro estructuras básicas de un algoritmo?
    back: Secuencia (un paso tras otro), asignación (guardar un valor), decisión (Si … Si no) y repetición (Para cada, Mientras).
  - id: m02-l02-c3
    front: ¿Cuándo usar «Para cada» y cuándo «Mientras»?
    back: "«Para cada» cuando recorres los elementos de una colección o un número conocido de veces. «Mientras» cuando repites hasta que una condición deje de cumplirse y no sabes de antemano cuántas vueltas serán."
  - id: m02-l02-c4
    front: ¿Qué debe cambiar dentro de un ciclo «Mientras» para que termine?
    back: Algún valor que aparece en su condición. Si nada de la condición cambia dentro del ciclo, la condición nunca se vuelve falsa y el ciclo no termina.
---

## La idea en una frase

El pseudocódigo es un algoritmo escrito con la precisión de un programa y la libertad del español.

## Por qué no escribir directamente en Swift

Cuando aprendes a programar, cada línea de Swift te exige dos cosas a la vez: **qué** quieres hacer y **cómo** se escribe. El pseudocódigo separa ambas. Primero resuelves el problema sin preocuparte por comas, llaves o tipos; después traduces.

Esa separación no es solo para principiantes. En una entrevista técnica es habitual explicar el enfoque en pseudocódigo o en voz alta antes de escribir código, y en un equipo un algoritmo se discute en una pizarra antes de implementarse.

El pseudocódigo no tiene un estándar oficial. Cada libro y cada equipo usa su variante. Lo que importa es que **cada línea tenga un solo significado**. Este curso usa las convenciones de la siguiente sección.

## Las convenciones del curso

| Escritura | Significado | En Swift (lo verás en los módulos 4 a 6) |
| --- | --- | --- |
| `Entrada:` y `Salida:` | Qué recibe y qué entrega el algoritmo | Parámetros y valor de retorno de una función |
| `total ← 0` | Guarda 0 en la variable `total` | `var total = 0` |
| `Muestra total` | Escribe el valor en la salida | `print(total)` |
| `Si condición entonces` … `Si no` | Decisión | `if condición { … } else { … }` |
| `Para cada x en lista` | Repite una vez por cada elemento | `for x in lista { … }` |
| `Mientras condición` | Repite mientras la condición sea verdadera | `while condición { … }` |
| `Devuelve valor` | Termina y entrega la salida | `return valor` |
| Sangría | Las líneas sangradas pertenecen al bloque de arriba | Las llaves `{ }` |

Para operaciones usa los símbolos de la aritmética: `+`, `−`, `×`, `÷`, y para comparar `=`, `≠`, `<`, `≤`, `>`, `≥`. Cuando la división debe ser entera, dilo.

### La flecha no es un igual

`contador ← contador + 1` sería absurdo como ecuación: ningún número es igual a sí mismo más uno. Como asignación tiene sentido: **calcula** `contador + 1` con el valor actual y **guarda** el resultado en `contador`. Si `contador` valía 4, después vale 5. Por eso el curso usa una flecha y reserva `=` para comparar.

## Las cuatro estructuras

Cualquier algoritmo de este curso se arma con cuatro piezas.

1. **Secuencia**: los pasos se ejecutan en orden, de arriba hacia abajo.
2. **Asignación**: guardar un valor en una variable.
3. **Decisión**: hacer una cosa u otra según una condición.
4. **Repetición**: hacer lo mismo varias veces.

### Ejemplo mínimo: par o impar

```pseudo
Entrada: un número entero n
Salida: el texto «par» o «impar»

Si el residuo de n ÷ 2 es 0 entonces
    Devuelve «par»
Si no
    Devuelve «impar»
```

Línea por línea:

1. `Entrada` declara qué recibe: un entero, no un decimal ni un texto.
2. `Salida` declara qué entrega: uno de dos textos, nada más.
3. La condición usa el **residuo**: un número es par si al dividirlo entre 2 no sobra nada. En Swift es el operador `%`, que verás en el Módulo 4.
4. La línea sangrada pertenece al `Si`: solo se ejecuta cuando la condición es verdadera.
5. `Si no` cubre todos los demás casos. Como un residuo entre 2 solo puede ser 0 o 1 para números positivos, no hay un tercer caso.
6. `Devuelve` termina el algoritmo con la respuesta.

> [!nota]
> Con números negativos el residuo de Swift conserva el signo: `-3 % 2` es `-1`, no `1`. Por eso la condición pregunta si el residuo **es 0**, que funciona para negativos, en lugar de preguntar si es 1.

### Dos tipos de repetición

**Para cada** recorre una colección o un rango conocido. Sabes cuántas vueltas dará antes de empezar.

```pseudo
Para cada calificación en calificaciones
    Muestra calificación
```

**Mientras** repite hasta que una condición se vuelva falsa. No siempre sabes cuántas vueltas dará.

```pseudo
saldo ← 1000
meses ← 0
Mientras saldo < 2000
    saldo ← saldo × 2
    meses ← meses + 1
Muestra meses
```

En un ciclo `Mientras`, algo de la condición **debe cambiar** dentro del ciclo. Aquí `saldo` crece en cada vuelta; si la línea `saldo ← saldo × 2` no existiera, el ciclo no terminaría nunca.

## Ejemplo práctico: promedio de calificaciones aprobatorias

Problema: de una lista de calificaciones, mostrar cuántas son aprobatorias (6 o más) y su promedio.

```pseudo
Entrada: una lista de calificaciones enteras de 0 a 10
Salida: cuántas aprobaron y el promedio de las aprobatorias

suma ← 0
aprobadas ← 0
Para cada c en calificaciones
    Si c ≥ 6 entonces
        suma ← suma + c
        aprobadas ← aprobadas + 1
Muestra aprobadas
Si aprobadas = 0 entonces
    Muestra «sin aprobadas»
Si no
    Muestra suma ÷ aprobadas
```

Este pseudocódigo combina las cuatro estructuras y dos patrones del acumulador, uno para la suma y otro para el conteo. Fíjate en la última decisión: protege la división del caso «nadie aprobó». Sin ella, con la lista `[4, 5]` el algoritmo dividiría 0 ÷ 0.

Antes de seguir, ¿el promedio debe ser entero o decimal? El enunciado no lo dice. Con `[6, 7]` el promedio es 6.5; con división entera sería 6. Una pregunta así es exactamente lo que el pseudocódigo hace visible antes de escribir una línea de Swift.

## Errores frecuentes

> [!error] Variable sin valor inicial
> `suma ← suma + c` dentro de un ciclo no tiene sentido si nunca escribiste `suma ← 0` antes. ¿Cuánto vale `suma` la primera vez? Swift tampoco te dejará usar una variable sin valor.

> [!error] Un ciclo «Mientras» que nunca termina
> Si nada de lo que aparece en la condición cambia dentro del ciclo, la condición nunca se vuelve falsa. Revisa siempre qué línea del ciclo acerca la condición a ser falsa.

> [!error] Sangría ambigua
> Si no queda claro qué líneas pertenecen a un `Si` o a un `Para cada`, el algoritmo tiene dos lecturas posibles. Usa sangría consistente: cuatro espacios por nivel.

> [!error] Escribir pseudocódigo demasiado vago
> «Procesa la lista» no es pseudocódigo; es un deseo. Cada línea debe poder ejecutarse a mano sin preguntarle nada a quien la escribió.

````exercise
id: m02-l02-e1
type: comprension
prompt: |
  ¿Qué valor tiene `x` al terminar estas tres líneas?

  ```pseudo
  x ← 5
  x ← x + 3
  x ← x × 2
  ```
choices:
  - text: "5"
    correct: false
    why: La primera línea asigna 5, pero las siguientes cambian el valor.
  - text: "16"
    correct: true
    why: "5, después 5 + 3 = 8, después 8 × 2 = 16."
  - text: "13"
    correct: false
    why: "Sería 5 + 3 + 5: confunde la asignación con una suma acumulada."
  - text: "Ninguno: x ← x + 3 es una contradicción."
    correct: false
    why: La flecha es una asignación, no una ecuación. Calcula a la derecha y guarda a la izquierda.
solution: |
  **16.** Las asignaciones se ejecutan en orden y cada una usa el valor actual de `x`:

  | Paso | Cálculo | x |
  | --- | --- | --- |
  | `x ← 5` | — | 5 |
  | `x ← x + 3` | 5 + 3 | 8 |
  | `x ← x × 2` | 8 × 2 | 16 |
````

````exercise
id: m02-l02-e2
type: prediccion
lang: pseudo
prompt: Escribe exactamente lo que muestra este algoritmo, una línea por cada «Muestra».
code: |
  números ← [3, 8, 5, 10]
  Para cada n en números
      Si n > 4 entonces
          Muestra n × 2

  x ← 1
  Mientras x < 20
      Muestra x
      x ← x × 3
output: |
  16
  10
  20
  1
  3
  9
hints:
  - El 3 no cumple la condición n > 4.
  - "En el ciclo «Mientras», x pasa por 1, 3, 9 y 27. ¿Con cuál de esos valores ya no entra?"
solution: |
  ```output
  16
  10
  20
  1
  3
  9
  ```

  **Primer ciclo.** 3 no es mayor que 4 y no muestra nada. 8, 5 y 10 sí: se muestran 16, 10 y 20.

  **Segundo ciclo.** Se muestra x y después se triplica:

  | Vuelta | ¿x < 20? | Muestra | x después |
  | --- | --- | --- | --- |
  | 1 | 1 < 20, sí | 1 | 3 |
  | 2 | 3 < 20, sí | 3 | 9 |
  | 3 | 9 < 20, sí | 9 | 27 |
  | 4 | 27 < 20, no | — | — |

  Así se escribe en Swift. Las pruebas del curso ejecutan esta traducción para comprobar la salida:

  ```swift
  let números = [3, 8, 5, 10]
  for n in números {
      if n > 4 {
          print(n * 2)
      }
  }

  var x = 1
  while x < 20 {
      print(x)
      x = x * 3
  }
  ```
````

````exercise
id: m02-l02-e3
type: resolver
prompt: |
  Escribe en pseudocódigo, con las convenciones del curso, un algoritmo que reciba una lista de temperaturas enteras y muestre:

  1. Cuántas temperaturas están bajo cero.
  2. La temperatura más baja, o «sin datos» si la lista está vacía.
starter: |
  Entrada:
  Salida:
hints:
  - Son dos acumuladores en el mismo recorrido, un conteo y un mínimo.
  - El mínimo debe empezar con un elemento real de la lista, no con 0.
rubric:
  - Declaré Entrada y Salida.
  - Todas las variables tienen valor inicial antes de usarse.
  - El conteo cuenta solo temperaturas menores que 0.
  - El mínimo empieza con la primera temperatura, no con un valor inventado.
  - Manejé la lista vacía antes de leer el primer elemento.
  - La sangría deja claro qué pertenece a cada Si y a cada Para cada.
solution: |
  ```pseudo
  Entrada: una lista de temperaturas enteras
  Salida: cuántas están bajo cero y la más baja

  bajoCero ← 0
  Para cada t en temperaturas
      Si t < 0 entonces
          bajoCero ← bajoCero + 1
  Muestra bajoCero

  Si temperaturas está vacía entonces
      Muestra «sin datos»
  Si no
      mínima ← la primera temperatura
      Para cada t en temperaturas
          Si t < mínima entonces
              mínima ← t
      Muestra mínima
  ```

  - El conteo con una lista vacía da 0, que es correcto; por eso no necesita protección.
  - El mínimo sí la necesita: con una lista vacía no hay primera temperatura.
  - Empezar `mínima ← 0` sería un error: con `[5, 12, 8]` el algoritmo respondería 0, una temperatura que no está en la lista.

  Se puede hacer todo en un solo recorrido. Dos recorridos son más fáciles de leer y, para listas de este tamaño, la diferencia no importa.
````

````exercise
id: m02-l02-e4
type: errores
prompt: |
  Este pseudocódigo debería mostrar la suma de los números del 1 al n. Tiene problemas reales. Selecciónalos y escribe la versión corregida.
code: |
  Entrada: un entero n ≥ 1
  Salida: 1 + 2 + … + n

  i ← 1
  Mientras i ≤ n
      suma ← suma + i
  Muestra suma
choices:
  - text: "`suma` se usa antes de tener un valor inicial."
    correct: true
    why: La primera vez que se ejecuta `suma ← suma + i`, `suma` no vale nada.
  - text: "El ciclo nunca termina porque `i` no cambia dentro de él."
    correct: true
    why: "La condición es i ≤ n y nada dentro del ciclo modifica i ni n."
  - text: "Debería usar `=` en lugar de `←`."
    correct: false
    why: "En el pseudocódigo del curso, `←` asigna y `=` compara. Aquí se quiere asignar."
  - text: "La condición debería ser `i < n`."
    correct: false
    why: "Con `i < n`, el valor n no se sumaría. `i ≤ n` es correcto."
rubric:
  - "Inicialicé `suma ← 0` antes del ciclo."
  - "Agregué `i ← i + 1` dentro del ciclo."
  - "Comprobé a mano con n = 3 que el resultado es 6."
solution: |
  ```pseudo
  Entrada: un entero n ≥ 1
  Salida: 1 + 2 + … + n

  suma ← 0
  i ← 1
  Mientras i ≤ n
      suma ← suma + i
      i ← i + 1
  Muestra suma
  ```

  Con n = 3: suma pasa por 1, 3 y 6; i pasa por 2, 3 y 4; cuando i vale 4 la condición es falsa y se muestra **6**.

  Como aquí sabes de antemano cuántas vueltas son, `Para cada i en 1…n` sería más claro y elimina el riesgo de olvidar el incremento.
````

````exercise
id: m02-l02-e5
type: refactorizar
prompt: Reescribe este algoritmo en pseudocódigo preciso, con las convenciones del curso. Debe hacer lo mismo que describe, sin ambigüedades.
code: |
  Revisa los precios del carrito. Si alguno es caro, avisa.
  Al final di cuánto cuesta todo y aplica el descuento si toca.
rubric:
  - "Definí «caro» con un número concreto."
  - "Definí cuándo «toca» el descuento y de cuánto es."
  - Declaré Entrada y Salida.
  - Usé un acumulador con valor inicial para el total.
  - Cada línea se puede ejecutar a mano sin preguntar nada.
solution: |
  El original tiene tres ambigüedades: qué es «caro», cuándo «toca» el descuento y de cuánto es. Hay que decidirlas (o preguntarlas). Una versión precisa, con decisiones explícitas:

  ```pseudo
  Entrada: una lista de precios enteros
  Salida: avisos de precios altos y el total a pagar

  Límite de precio caro: 1000
  Descuento: 10 % si el total es de 2000 o más

  total ← 0
  Para cada p en precios
      Si p > 1000 entonces
          Muestra «Precio alto:» y p
      total ← total + p
  Si total ≥ 2000 entonces
      total ← total − total × 10 ÷ 100
  Muestra total
  ```

  Los números concretos (1000, 2000, 10 %) son decisiones; en un proyecto real los define quien pide la app. Lo importante es que ya no dependen de la interpretación de quien lee.
````

## Resumen

- El pseudocódigo separa **qué** hace un algoritmo de **cómo** se escribe en un lenguaje.
- En el curso: `←` asigna, `=` compara, `Muestra` escribe, `Devuelve` termina con la respuesta, y la sangría marca los bloques.
- Cuatro estructuras: secuencia, asignación, decisión y repetición.
- `Para cada` recorre algo conocido; `Mientras` repite hasta que su condición sea falsa, y algo de esa condición debe cambiar dentro del ciclo.
- Toda variable necesita un valor inicial antes de usarse.
