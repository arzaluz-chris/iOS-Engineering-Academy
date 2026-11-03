---
id: m02-l01
title: "Descomponer, reconocer patrones y abstraer"
description: Las tres herramientas para atacar un problema que todavía no sabes resolver. Partes un problema grande en subproblemas, reconoces que ya resolviste algo parecido y te quedas solo con los datos que importan.
module: m02
order: 1
level: inicial
minutes: 45
prerequisites: [m01-l01]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Descomponer un problema en subproblemas pequeños, cada uno con su propia entrada y salida.
  - Reconocer cuándo un problema nuevo tiene la misma estructura que uno ya resuelto.
  - Abstraer un problema, separando los datos que importan de los detalles que no.
  - Nombrar subproblemas reutilizables como procedimientos con entrada y salida.
terms:
  - term: Pensamiento computacional
    definition: Forma de plantear un problema para que una persona o una computadora pueda resolverlo con un algoritmo. Incluye descomponer, reconocer patrones, abstraer y diseñar el algoritmo.
  - term: Descomposición
    definition: Dividir un problema en subproblemas más pequeños que se pueden resolver y verificar por separado.
  - term: Subproblema
    definition: Una parte de un problema mayor con su propia entrada y su propia salida.
  - term: Patrón
    definition: Estructura que se repite en problemas distintos. Por ejemplo, «recorrer una lista acumulando un total» aparece al sumar precios, contar votos o calcular un promedio.
  - term: Abstracción
    definition: Quedarse con los datos y las reglas que importan para resolver el problema e ignorar los detalles que no cambian el resultado.
  - term: Procedimiento
    definition: Un subproblema con nombre, entrada y salida que se puede usar varias veces. En Swift se escribe como una función.
mastery:
  - Descomponer por escrito un problema cotidiano en al menos tres subproblemas, indicando la entrada y la salida de cada uno.
  - Señalar qué tienen en común dos problemas de enunciado distinto y reutilizar la solución de uno en el otro.
  - Reescribir un enunciado largo como entrada, salida y reglas, eliminando los detalles irrelevantes.
  - Explicar por qué un subproblema bien definido se puede probar por separado.
resources: [swift-book-tour]
cards:
  - id: m02-l01-c1
    front: ¿Qué es descomponer un problema?
    back: Dividirlo en subproblemas más pequeños, cada uno con entrada y salida propias, que se pueden resolver y verificar por separado.
  - id: m02-l01-c2
    front: ¿Qué es la abstracción en pensamiento computacional?
    back: Quedarse con los datos y reglas que cambian el resultado e ignorar los detalles que no lo cambian.
  - id: m02-l01-c3
    front: "¿Qué patrón comparten «sumar precios», «contar votos» y «calcular un promedio»?"
    back: "Recorrer una lista acumulando un resultado: empezar con un valor inicial y actualizarlo con cada elemento."
  - id: m02-l01-c4
    front: ¿Cómo sabes que un subproblema está bien definido?
    back: Puedes decir exactamente qué recibe, qué devuelve y verificarlo con un ejemplo sin mirar el resto del problema.
---

## La idea en una frase

Un problema que no sabes resolver suele ser varios problemas que sí sabes resolver, mezclados. Las herramientas de esta lección sirven para separarlos.

## Pensamiento computacional

**Definición sencilla:** pensar un problema de forma que se pueda resolver con pasos precisos.

**Definición precisa:** el pensamiento computacional reúne cuatro prácticas que se usan juntas:

| Práctica | Pregunta que responde |
| --- | --- |
| Descomposición | ¿En qué partes más pequeñas se divide el problema? |
| Reconocimiento de patrones | ¿Ya resolví algo con la misma estructura? |
| Abstracción | ¿Qué datos importan y cuáles puedo ignorar? |
| Diseño de algoritmos | ¿Qué pasos precisos resuelven cada parte? |

Esta lección trabaja las tres primeras. El diseño de algoritmos, con pseudocódigo, diagramas y tablas de seguimiento, ocupa el resto del módulo.

No necesitas una computadora para nada de esto. Una persona que programa con experiencia pasa una parte importante de su tiempo aquí, antes de abrir Xcode.

## Descomposición

**Definición sencilla:** partir un problema grande en problemas pequeños.

**Explicación técnica:** cada subproblema debe tener una **entrada** y una **salida** claras. Si no puedes decir qué recibe y qué entrega, todavía no es un subproblema; es un tema. La salida de un subproblema suele ser la entrada del siguiente.

### Ejemplo mínimo: dividir la cuenta del restaurante

Problema: cuatro personas comen juntas, la cuenta es de 600 pesos y quieren dejar 10 % de propina. ¿Cuánto paga cada una?

```pseudo
Problema: cuánto paga cada persona

1. Calcular la propina.        Entrada: cuenta, porcentaje.   Salida: propina.
2. Calcular el total.          Entrada: cuenta, propina.      Salida: total.
3. Repartir el total.          Entrada: total, personas.      Salida: monto por persona.
```

Línea por línea:

1. El primer subproblema solo sabe de porcentajes: 10 % de 600 es 60. No le importa cuántas personas hay.
2. El segundo solo suma: 600 + 60 = 660. Recibe la salida del paso 1.
3. El tercero solo divide: 660 entre 4 es 165. Recibe la salida del paso 2.

Cada subproblema es tan pequeño que puedes comprobarlo con una calculadora. Si el resultado final está mal, sabes dónde buscar: revisas cada paso por separado en lugar de todo el problema a la vez.

### Ejemplo práctico: una app de lista de compras

Un problema real rara vez llega tan ordenado. «Quiero una app que me diga cuánto voy a gastar en el súper» se descompone así:

```pseudo
Problema: estimar el gasto del súper

1. Registrar productos.        Entrada: nombre, precio, cantidad.   Salida: lista de productos.
2. Calcular el costo de uno.   Entrada: precio, cantidad.           Salida: costo del producto.
3. Sumar todos los costos.     Entrada: lista de costos.            Salida: subtotal.
4. Aplicar descuentos.         Entrada: subtotal, descuento.        Salida: total.
5. Mostrar el resultado.       Entrada: total.                      Salida: texto en pantalla.
```

Observa dos cosas. El paso 2 se usa una vez **por cada producto**: es un procedimiento reutilizable. Y el paso 5 es el único que sabe que existe una pantalla; los demás funcionarían igual en una app, en la terminal o en una hoja de cálculo. Separar el cálculo de la presentación es una decisión que verás una y otra vez en arquitectura de apps iOS.

## Subproblemas con nombre: procedimientos

Cuando un subproblema se usa varias veces, conviene darle un **nombre**. «Calcular el costo de un producto» es un procedimiento: recibe precio y cantidad y devuelve un costo. Lo describes una vez y lo usas cuantas veces haga falta.

En Swift, un procedimiento con nombre se escribe como una **función**. Las estudiarás en el Módulo 6; por ahora, la habilidad es reconocerlas en el problema. Una pista: si al describir tu solución dices «y otra vez hago lo mismo para…», ahí hay un procedimiento.

## Reconocimiento de patrones

**Definición sencilla:** darte cuenta de que un problema nuevo se parece a uno que ya resolviste.

**Explicación técnica:** dos problemas comparten un patrón cuando tienen la misma **estructura** de entrada, proceso y salida, aunque los datos sean distintos. Estos tres problemas son el mismo:

| Problema | Entrada | Acumulador inicial | Con cada elemento |
| --- | --- | --- | --- |
| Total de una compra | lista de precios | 0 | sumar el precio |
| Votos por «sí» | lista de votos | 0 | sumar 1 si el voto es «sí» |
| Calificación más alta | lista de calificaciones | la primera calificación | quedarse con la mayor |

Los tres recorren una lista y actualizan un valor con cada elemento. Ese patrón se llama **acumulador** y es probablemente el más usado de todo el curso. Lo viste en la lección «Qué es programar» con «el mayor hasta ahora».

Reconocer el patrón tiene una ventaja concreta: heredas también los **casos límite** que ya conoces. Si sabes que «el mayor de una lista» falla con una lista vacía, sospecharás lo mismo de «el promedio de una lista».

## Abstracción

**Definición sencilla:** quedarte solo con lo que importa.

**Explicación técnica:** abstraer es decidir qué datos y qué reglas cambian el resultado. Todo lo demás se elimina del planteamiento. Compara:

> Mariana organiza una comida en un restaurante italiano de Coyoacán el sábado. Van ella, su hermano y dos amigas de la universidad. La cuenta es de 600 pesos y quieren dejar 10 % de propina. ¿Cuánto paga cada quien?

Con abstracción, el problema queda así:

```pseudo
Entrada: cuenta = 600, porcentaje de propina = 10, personas = 4
Salida: monto por persona
Regla: (cuenta + cuenta × porcentaje ÷ 100) ÷ personas
```

El restaurante, el día y los nombres no cambian el resultado. El número de personas **sí**, aunque en el enunciado venga escondido en «ella, su hermano y dos amigas».

### Los límites de la abstracción

Abstraer de más también es un error. Si eliminas un dato que sí importa, tu solución será correcta para un problema que no es el tuyo. Por ejemplo, si el restaurante cobra un cargo fijo por servicio, «restaurante italiano» sigue sin importar, pero «cargo por servicio» sí. La pregunta para cada dato es siempre la misma: **¿si este dato cambia, cambia la respuesta?**

## Errores frecuentes

> [!error] Subproblemas sin entrada ni salida
> «Hacer la parte de los descuentos» no es un subproblema. «Aplicar un descuento: recibe subtotal y porcentaje, devuelve total» sí lo es. Si no puedes escribir su entrada y su salida, todavía no lo entiendes.

> [!error] Descomponer en pasos demasiado grandes
> «1. Calcular todo. 2. Mostrarlo.» no ayuda. Sigue dividiendo hasta que cada paso se pueda verificar con un ejemplo en menos de un minuto.

> [!error] Mezclar el cálculo con la presentación
> Si «calcular el total» también decide cómo se ve en pantalla, no podrás reutilizar el cálculo en otro lugar ni probarlo por separado.

> [!error] Eliminar un dato que sí importa
> Al abstraer, pregunta por cada dato si cambia la respuesta. «Cuatro personas» escondido en un enunciado largo es fácil de perder.

````exercise
id: m02-l01-e1
type: comprension
multiple: true
prompt: |
  Problema: «Laura corre en un parque de Guadalajara los lunes, miércoles y viernes. Esta semana corrió 5, 7 y 6 kilómetros. ¿Cuántos kilómetros corrió en promedio por día de entrenamiento?».

  ¿Qué datos son necesarios para resolverlo? Selecciona todos los que apliquen.
choices:
  - text: Las distancias 5, 7 y 6.
    correct: true
    why: Son la entrada del cálculo.
  - text: El número de días de entrenamiento, 3.
    correct: true
    why: El promedio divide entre el número de días. Aquí coincide con el número de distancias.
  - text: Que el parque está en Guadalajara.
    correct: false
    why: Si el parque estuviera en otra ciudad, el promedio sería el mismo.
  - text: Que los días son lunes, miércoles y viernes.
    correct: false
    why: Los nombres de los días no cambian el resultado; solo importa cuántos son.
solution: |
  Solo importan **las distancias** y **cuántos días** son. La pregunta que decide es: ¿si este dato cambia, cambia la respuesta? La ciudad y los nombres de los días no la cambian.

  El problema abstraído queda así: entrada, una lista de distancias; salida, su suma dividida entre la cantidad de distancias. Es el patrón del acumulador más una división: (5 + 7 + 6) ÷ 3 = 6.
````

````exercise
id: m02-l01-e2
type: prediccion
lang: pseudo
prompt: Sigue el algoritmo con los datos indicados y escribe exactamente lo que muestra, una línea por cada «Muestra». Todas las operaciones son con números enteros.
code: |
  Datos: cuenta = 600, porcentaje = 10, personas = 4

  1. propina ← cuenta × porcentaje ÷ 100
  2. total ← cuenta + propina
  3. porPersona ← total ÷ personas
  4. Muestra propina
  5. Muestra total
  6. Muestra porPersona
output: |
  60
  660
  165
hints:
  - "La flecha ← significa «guarda el resultado en»."
  - "Paso 1: 600 × 10 = 6000; 6000 ÷ 100 = 60."
solution: |
  ```output
  60
  660
  165
  ```

  1. `propina` = 600 × 10 ÷ 100 = 60.
  2. `total` = 600 + 60 = 660.
  3. `porPersona` = 660 ÷ 4 = 165.
  4. a 6. Se muestran los tres valores en ese orden.

  Cada paso es uno de los subproblemas de la lección. Así se escribe en Swift; lo aprenderás en el Módulo 4, y las pruebas del curso ejecutan esta traducción para comprobar la salida:

  ```swift
  let cuenta = 600
  let porcentaje = 10
  let personas = 4

  let propina = cuenta * porcentaje / 100
  let total = cuenta + propina
  let porPersona = total / personas
  print(propina)
  print(total)
  print(porPersona)
  ```
````

````exercise
id: m02-l01-e3
type: comprension
prompt: |
  ¿Cuál de estos problemas tiene **la misma estructura** que «calcular el total de una compra a partir de una lista de precios»?
choices:
  - text: Contar cuántos alumnos aprobaron, a partir de una lista de calificaciones.
    correct: true
    why: "Mismo patrón de acumulador: empieza en 0 y, por cada calificación aprobatoria, suma 1."
  - text: Ordenar alfabéticamente una lista de nombres.
    correct: false
    why: Ordenar reacomoda los elementos; no reduce la lista a un solo valor.
  - text: Saber si una contraseña tiene al menos 8 caracteres.
    correct: false
    why: Es una sola comparación; no recorre una lista acumulando un resultado.
  - text: Convertir una temperatura de Celsius a Fahrenheit.
    correct: false
    why: Transforma un solo valor; no hay lista que recorrer.
solution: |
  **Contar aprobados** comparte el patrón del acumulador: un valor inicial (0) que se actualiza con cada elemento de la lista. La única diferencia es la regla de actualización: en el total sumas el precio; en el conteo sumas 1 solo si la calificación es aprobatoria.

  Reconocerlo te da la solución casi gratis y también te recuerda el caso límite: con una lista vacía, el conteo es 0, igual que el total.
````

````exercise
id: m02-l01-e4
type: resolver
prompt: |
  Descompón este problema en subproblemas. Para cada uno escribe su nombre, su entrada y su salida, como en el ejemplo de la lista de compras.

  > Una app de gimnasio registra las sesiones de la semana (fecha, minutos y tipo de ejercicio). Al final de la semana debe decirte cuántos minutos entrenaste en total, cuál fue tu sesión más larga y si cumpliste tu meta semanal de minutos.

  Luego indica qué subproblema se parece a uno que ya conoces y qué datos del enunciado no hacen falta para estas tres respuestas.
starter: |
  1. Nombre:        Entrada:        Salida:
hints:
  - Las tres preguntas finales son tres salidas distintas. Cada una puede ser un subproblema.
  - "«Sesión más larga» es el mismo patrón que «la calificación más alta»."
rubric:
  - Hay al menos tres subproblemas y cada uno tiene entrada y salida explícitas.
  - "«Minutos totales» se resuelve con un acumulador que empieza en 0."
  - "«Sesión más larga» se resuelve con el patrón del mayor y considera qué pasa si no hubo sesiones."
  - "«Meta cumplida» recibe los minutos totales y la meta, y devuelve sí o no."
  - Indiqué que la fecha y el tipo de ejercicio no se necesitan para estas tres respuestas.
solution: |
  ```pseudo
  1. Sumar minutos.       Entrada: lista de sesiones.          Salida: minutos totales.
  2. Sesión más larga.    Entrada: lista de sesiones.          Salida: la sesión con más minutos, o «sin sesiones».
  3. Revisar la meta.     Entrada: minutos totales, meta.      Salida: sí, si totales ≥ meta; no, en otro caso.
  4. Mostrar resultados.  Entrada: las tres salidas anteriores. Salida: texto en pantalla.
  ```

  - El subproblema 1 es el **acumulador** del total de una compra: empieza en 0 y suma los minutos de cada sesión.
  - El subproblema 2 es el **mayor de una lista**, con su caso límite: si no hubo sesiones, no hay sesión más larga.
  - El subproblema 3 depende de la salida del 1. Si el 1 está bien probado, el 3 es una sola comparación.
  - La **fecha** y el **tipo de ejercicio** no cambian ninguna de las tres respuestas. Se guardan porque otras funciones de la app podrían usarlos, pero no entran en este cálculo.
````

````exercise
id: m02-l01-e5
type: explicar
prompt: Esta persona descompuso un problema así. Explica qué está mal en la descomposición y cómo la mejorarías.
code: |
  Problema: calcular el promedio de calificaciones de un grupo y mostrarlo

  1. Hacer los cálculos.
  2. Mostrar el promedio con dos decimales y en color rojo si es menor que 6.
rubric:
  - Señalé que el paso 1 es demasiado grande y no tiene entrada ni salida.
  - Separé la suma, el conteo y la división en subproblemas propios.
  - Señalé que el paso 2 mezcla una decisión (si reprobó) con la presentación (color, decimales).
  - Mencioné el caso de un grupo sin calificaciones.
solution: |
  **Paso 1** no es un subproblema: «hacer los cálculos» no dice qué recibe ni qué entrega, y no se puede verificar con un ejemplo. Debe dividirse:

  ```pseudo
  1. Sumar calificaciones.   Entrada: lista.            Salida: suma.
  2. Contar calificaciones.  Entrada: lista.            Salida: cantidad.
  3. Calcular el promedio.   Entrada: suma, cantidad.   Salida: promedio, o «sin datos» si la cantidad es 0.
  4. Decidir si aprueba.     Entrada: promedio.         Salida: sí, si el promedio ≥ 6.
  5. Mostrar.                Entrada: promedio, si aprueba. Salida: texto con dos decimales y color.
  ```

  **Paso 2** mezcla la regla de negocio (¿el promedio es aprobatorio?) con cómo se ve en pantalla. Separarlas permite probar la regla sin interfaz y cambiar el color sin tocar el cálculo.

  El paso 3 hace visible un caso límite que la versión original escondía: un grupo sin calificaciones haría dividir entre 0.
````

````exercise
id: m02-l01-e6
type: diseno
prompt: |
  Abstrae este enunciado: escribe solo la entrada, la salida y las reglas, sin ningún detalle que no cambie el resultado.

  > El cine Las Américas de Morelia vende boletos a 85 pesos. Los martes hay 2 × 1. Los estudiantes con credencial pagan 60 pesos cualquier día, pero no se combina con el 2 × 1. Andrea quiere ir el martes con tres compañeros de la prepa; todos tienen credencial. ¿Cuánto pagan en total, eligiendo la opción más barata?
rubric:
  - La entrada incluye el número de personas, si es martes y cuántas tienen credencial.
  - Escribí las dos reglas de precio y que no se combinan.
  - La salida es el total más barato entre las opciones válidas.
  - Eliminé el nombre del cine, la ciudad y los nombres de las personas.
  - Calculé la respuesta del caso concreto.
solution: |
  ```pseudo
  Entrada: personas, esMartes, personasConCredencial
  Precios: general = 85, estudiante = 60
  Salida: el total más barato

  Opción A (2 × 1, solo si es martes): se pagan personas ÷ 2 boletos generales, redondeando hacia arriba.
  Opción B (credencial): personasConCredencial × 60 + (personas − personasConCredencial) × 85.
  Las opciones no se combinan. Total = la menor de las opciones válidas.
  ```

  Caso concreto: 4 personas, es martes, 4 con credencial. Opción A: 2 boletos × 85 = 170. Opción B: 4 × 60 = 240. Pagan **170**.

  El cine, la ciudad, los nombres y «compañeros de la prepa» no cambian el resultado. «Todos tienen credencial» sí importa, y por eso la entrada lo incluye como número. El «redondeando hacia arriba» de la opción A es una regla que el enunciado no aclara para grupos impares; al abstraer, aparecen las preguntas que hay que hacerle a quien pidió el programa.
````

## Resumen

- Pensamiento computacional: descomponer, reconocer patrones, abstraer y diseñar algoritmos.
- Un subproblema tiene entrada y salida explícitas, y se puede verificar solo.
- Un subproblema que se usa varias veces es un procedimiento con nombre; en Swift, una función.
- El patrón del acumulador (valor inicial que se actualiza con cada elemento) resuelve totales, conteos y máximos.
- Abstraer es quedarse con lo que cambia la respuesta. Pregunta por cada dato: ¿si cambia, cambia el resultado?
- Separa el cálculo de la presentación desde el diseño.
