---
id: p01
number: 1
title: Gestor de gastos en consola
summary: Una aplicación de línea de comandos para registrar gastos, clasificarlos y obtener resúmenes. Practica variables, condicionales, funciones, colecciones y optionals sin interfaz gráfica.
prerequisites: [m04, m05, m06, m07, m08]
objectives:
  - Descomponer un programa en funciones pequeñas con entradas y salidas claras.
  - Elegir entre Array, Set y Dictionary según la operación.
  - Validar texto escrito por la persona usuaria y manejar entradas inválidas sin que el programa se detenga.
requirements:
  - "Comandos: agregar, listar, total, por-categoria, salir."
  - Cada gasto tiene descripción, monto en centavos (Int) y categoría.
  - "Montos inválidos (texto, negativos, cero) se rechazan con un mensaje claro."
  - "El resumen por categoría muestra el total de cada una, ordenado de mayor a menor."
acceptance:
  - Escribir «abc» como monto muestra un error y el programa sigue funcionando.
  - El total coincide con la suma de los gastos listados.
  - Ninguna línea del programa usa force unwrapping.
  - Las funciones de cálculo tienen pruebas con Swift Testing que pasan con `swift test`.
milestones:
  - id: p01-h1
    title: Crear el paquete ejecutable
    tasks: ["Ejecuta `swift package init --type executable` y compila el ejemplo.", "Separa en un target de biblioteca la lógica que vas a probar."]
    concepts: [Swift Package Manager, swift run]
  - id: p01-h2
    title: Modelar un gasto y la lista de gastos
    tasks: ["Define el gasto con descripción, monto en centavos y categoría.", "Escribe una función que devuelva el total."]
    concepts: [Colecciones, Funciones]
  - id: p01-h3
    title: Leer y validar comandos
    tasks: ["Lee líneas con readLine() y trata su resultado optional.", "Convierte el monto con Int(_:) y rechaza valores inválidos."]
    concepts: [Optionals, guard let, Validación]
  - id: p01-h4
    title: Resumen por categoría
    tasks: ["Agrupa con un Dictionary de categoría a total.", "Ordena por total descendente."]
    concepts: [Dictionary, sorted(by:)]
  - id: p01-h5
    title: Pruebas
    tasks: ["Escribe pruebas para total, validación de montos y resumen.", "Incluye casos límite: lista vacía, una sola categoría."]
    concepts: [Swift Testing, Casos límite]
---

## Por qué montos en centavos

Los decimales binarios (`Double`) no representan exactamente valores como 0.1. Sumar dinero con `Double` acumula errores de redondeo. Guardar centavos en un `Int` evita el problema; para mostrar, divides entre 100 al formatear. En apps reales se usa `Decimal`, que verás más adelante.

## Cómo trabajar este proyecto

Avanza por hitos. Al terminar cada uno, ejecuta las pruebas y haz un commit. No hay una solución completa para copiar: si te atoras en un hito, vuelve a la lección del concepto indicado.
