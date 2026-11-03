---
id: m01-l01
title: Qué es programar y qué es un algoritmo
description: Antes de escribir código hay que entender qué le estás pidiendo a la computadora. Aquí defines algoritmo, ves qué lo hace correcto y diseñas el primero.
module: m01
order: 1
level: inicial
minutes: 40
codeStatus: sin-codigo
objectives:
  - Definir con tus palabras qué es programar y qué es un algoritmo.
  - 'Reconocer las tres propiedades de un algoritmo correcto: precisión, finitud y corrección.'
  - Escribir un algoritmo en pasos numerados para un problema cotidiano.
  - Detectar instrucciones ambiguas en un algoritmo escrito por otra persona.
terms:
  - term: Programa
    definition: Conjunto de instrucciones que una computadora ejecuta para realizar una tarea.
  - term: Algoritmo
    definition: Secuencia finita de pasos precisos que transforma una entrada en una salida.
  - term: Entrada
    definition: Los datos que el algoritmo recibe para trabajar.
  - term: Salida
    definition: El resultado que el algoritmo produce.
  - term: Caso límite
    definition: Una entrada válida pero extrema o inusual, como una lista vacía o un número negativo.
mastery:
  - Escribir, sin consultar la lección, un algoritmo en pasos numerados para encontrar el mayor de una lista de números.
  - Señalar en un algoritmo ajeno qué paso es ambiguo y reescribirlo de forma precisa.
  - Explicar por qué un algoritmo que funciona con un ejemplo todavía puede ser incorrecto.
resources: [swift-book-tour]
cards:
  - id: m01-l01-c1
    front: ¿Qué es un algoritmo?
    back: Una secuencia finita de pasos precisos que transforma una entrada en una salida.
  - id: m01-l01-c2
    front: ¿Cuáles son las tres propiedades de un algoritmo correcto?
    back: "Precisión (cada paso tiene un solo significado), finitud (termina) y corrección (produce la salida correcta para toda entrada válida, no solo para un ejemplo)."
  - id: m01-l01-c3
    front: ¿Por qué no basta con probar un algoritmo con un solo ejemplo?
    back: Porque un ejemplo no cubre los casos límite. Un algoritmo puede funcionar con [3, 7, 5] y fallar con una lista vacía o con puros números negativos.
---

## La idea en una frase

Programar es escribir instrucciones tan precisas que una máquina, que no entiende intenciones, pueda seguirlas sin equivocarse.

Una persona puede seguir la instrucción «ordena estos papeles» aunque sea vaga: adivina el criterio, pregunta o improvisa. Una computadora no adivina. Hace exactamente lo que dicen las instrucciones, en el orden en que están escritas, y nada más. Toda la disciplina de la programación nace de esa diferencia.

## Qué es un algoritmo, con precisión

Un **algoritmo** es una secuencia finita de pasos precisos que transforma una **entrada** en una **salida**.

Cada palabra de esa definición importa:

- **Secuencia**: los pasos tienen un orden. Cambiar el orden puede cambiar el resultado.
- **Finita**: el algoritmo termina. Un procedimiento que se repite para siempre no es un algoritmo útil.
- **Precisos**: cada paso tiene un único significado posible. «Agrega un poco de sal» no es preciso; «agrega 5 gramos de sal» sí.
- **Entrada y salida**: el algoritmo recibe datos y produce un resultado. Si no puedes decir qué entra y qué sale, todavía no entiendes el problema.

Un **programa** es un algoritmo escrito en un lenguaje que la computadora puede procesar, como Swift. El algoritmo es la idea; el programa es su expresión concreta. Puedes tener un algoritmo correcto y un programa con errores, o al revés: un programa que compila perfectamente e implementa un algoritmo equivocado.

## Una analogía y sus límites

Una receta de cocina se parece a un algoritmo: tiene ingredientes (entrada), pasos ordenados y un platillo (salida).

La analogía sirve para la idea de orden, pero falla en algo importante: las recetas dependen del criterio de quien cocina («hornea hasta que dore»). Un algoritmo no puede depender del criterio de nadie. Cuando escribas pasos, pregúntate: ¿una máquina sin sentido común podría ejecutar esto?

## Ejemplo mínimo: el mayor de dos números

Problema: dados dos números, decir cuál es el mayor.

```pseudo
Entrada: dos números, a y b
Salida: el mayor de los dos

1. Si a es mayor que b, la respuesta es a.
2. Si no, la respuesta es b.
```

## El ejemplo, paso por paso

- **Entrada**: declarar qué recibimos obliga a pensar en el tipo de dato. Aquí son números; no textos ni listas.
- **Salida**: declarar qué devolvemos define cuándo terminamos.
- **Paso 1**: compara y decide. Es preciso: «mayor que» tiene un solo significado para números.
- **Paso 2**: cubre todos los demás casos. Fíjate en que si `a` y `b` son iguales, la respuesta es `b`, que también es el mayor. El algoritmo es correcto incluso en ese caso límite, pero solo porque lo revisamos.

## Ejemplo práctico: el mayor de una lista

Ahora la entrada es una lista de calificaciones, de cualquier tamaño.

```pseudo
Entrada: una lista de calificaciones
Salida: la calificación más alta, o "sin datos" si la lista está vacía

1. Si la lista está vacía, la respuesta es "sin datos". Termina.
2. Guarda la primera calificación como "mayor hasta ahora".
3. Para cada calificación restante, en orden:
   3.1 Si es mayor que "mayor hasta ahora", reemplaza "mayor hasta ahora" con ella.
4. La respuesta es "mayor hasta ahora".
```

Dos decisiones de este algoritmo son las que separan a una persona que programa con cuidado de una que no:

- El **paso 1** existe porque una lista vacía no tiene primera calificación. Sin él, el paso 2 no tendría sentido.
- El **paso 2** empieza con la primera calificación, no con 0. Si empezáramos con 0 y todas las calificaciones fueran negativas (pensemos en temperaturas en lugar de calificaciones), el algoritmo respondería 0, un valor que ni siquiera está en la lista.

## Qué hace correcto a un algoritmo

Un algoritmo es **correcto** si produce la salida esperada para **toda** entrada válida. No para la entrada con la que lo probaste: para todas.

Por eso, antes de programar, conviene preguntarse por los **casos límite**: la lista vacía, una lista con un solo elemento, valores repetidos, valores negativos, valores muy grandes. Vas a usar esta pregunta en cada ejercicio y en cada entrevista técnica.

## Errores frecuentes

> [!error] Pasos que dependen del criterio de quien los lee
> «Revisa si el número es grande» no es un paso: ¿grande respecto a qué? Reemplázalo por una comparación concreta: «si el número es mayor que 100».

> [!error] Probar solo con el ejemplo del enunciado
> Si tu algoritmo funciona con `[3, 7, 5]`, todavía no sabes si funciona con `[]`, con `[4]` o con `[-2, -9]`. Prueba siempre los casos límite.

> [!error] Inicializar con un valor inventado
> Empezar «el mayor» en 0 parece inofensivo y falla con números negativos. Empieza con un elemento real de la entrada.

````exercise
id: m01-l01-e1
type: comprension
prompt: ¿Cuál de estas instrucciones es un **algoritmo** según la definición de esta lección?
choices:
  - text: "Revisa la lista y quédate con los números que parezcan importantes."
    correct: false
    why: «Parezcan importantes» depende del criterio de quien lo lee. No es preciso.
  - text: "Para cada número de la lista, si es par, súmalo a un total que empieza en 0. Al terminar la lista, la respuesta es el total."
    correct: true
    why: Cada paso tiene un solo significado, termina al acabar la lista y define entrada y salida.
  - text: "Repite: suma 1 a un contador."
    correct: false
    why: No dice cuándo detenerse. No es finito.
  - text: "Encuentra la mejor solución al problema."
    correct: false
    why: No describe pasos; describe un deseo.
solution: |
  Solo la segunda opción cumple las tres propiedades: **precisión** («si es par» tiene un único significado), **finitud** (termina al recorrer la lista) y define **entrada** (una lista) y **salida** (el total). Las demás fallan en precisión, en finitud o ni siquiera describen pasos.
````

````exercise
id: m01-l01-e2
type: comprension
prompt: Un algoritmo para encontrar la temperatura más alta del día empieza con «mayor hasta ahora = 0» y después compara cada lectura. Con las lecturas `[-5, -2, -8]`, ¿qué responde?
choices:
  - text: "-2"
    correct: false
    why: Sería la respuesta correcta, pero el algoritmo nunca reemplaza el 0 porque ninguna lectura es mayor que 0.
  - text: "0"
    correct: true
    why: Ninguna lectura supera el valor inicial, así que la respuesta es 0, que ni siquiera aparece en la lista.
  - text: "-8"
    correct: false
    why: El algoritmo busca el mayor, no el menor.
solution: |
  Responde **0**. Ninguna lectura es mayor que el valor inicial, así que el algoritmo nunca lo reemplaza. Es un algoritmo **incorrecto**: funciona con temperaturas positivas y falla con negativas. La corrección es empezar con la primera lectura real, después de verificar que la lista no esté vacía.
````

````exercise
id: m01-l01-e3
type: diseno
prompt: |
  Diseña un algoritmo en pasos numerados, como los de esta lección, para este problema:

  **Entrada:** una lista de precios de productos en un carrito.
  **Salida:** el total a pagar. Si el total es mayor que 1000, se aplica un descuento del 10 %.

  Declara entrada y salida, y escribe los casos límite que tu algoritmo debe soportar.
hints:
  - Empieza por definir qué haces si el carrito está vacío.
  - Primero suma todo; decide el descuento al final, una sola vez.
  - ¿Qué pasa si el total es exactamente 1000? Decide y escríbelo en tu algoritmo.
rubric:
  - Declaré la entrada y la salida.
  - Cada paso tiene un único significado posible.
  - El algoritmo termina.
  - Manejé el carrito vacío.
  - Dije explícitamente qué pasa cuando el total es exactamente 1000.
  - Apliqué el descuento una sola vez, después de sumar.
solution: |
  ```pseudo
  Entrada: una lista de precios (puede estar vacía)
  Salida: el total a pagar

  1. Guarda 0 como "total".
  2. Para cada precio de la lista, en orden:
     2.1 Suma el precio a "total".
  3. Si "total" es mayor que 1000:
     3.1 Reemplaza "total" por "total" multiplicado por 0.9.
  4. La respuesta es "total".
  ```

  - **Carrito vacío**: el paso 2 no se ejecuta ninguna vez y la respuesta es 0, que es correcto. Aquí empezar en 0 *sí* es válido, porque 0 es el total real de no comprar nada.
  - **Total igual a 1000**: con «mayor que», no hay descuento. El enunciado dice «mayor que 1000», así que esa es la interpretación correcta. En una entrevista, esta es exactamente la pregunta que conviene hacer: «¿el límite es inclusivo?».
  - **Descuento al final**: aplicarlo dentro del ciclo descontaría varias veces o dependería del orden de los productos.
````

## Resumen

- Programar es escribir instrucciones sin ambigüedad para una máquina que no interpreta intenciones.
- Un algoritmo es una secuencia finita de pasos precisos que transforma una entrada en una salida.
- Un algoritmo es correcto solo si funciona para toda entrada válida; los casos límite son donde suele fallar.
- Antes de escribir código, declara la entrada, la salida y los casos límite.
