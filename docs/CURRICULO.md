# Currículo

La fuente de verdad del mapa es `content/curriculum.yaml`. Este documento explica su lógica.

## Secuencia

| Etapa | Módulos | Prerrequisito principal |
| --- | --- | --- |
| 1. Fundamentos de programación | 1–3 | Ninguno |
| 2. Swift esencial | 4–8 | Etapa 1 |
| 3. Swift intermedio y avanzado | 9–13 | Etapa 2 |
| 4. Herramientas e ingeniería de software | 14 | Etapa 3 |
| 5. Algoritmos y estructuras de datos | 15–20 | Colecciones (M7), optionals (M8), protocolos (M10) |
| 6. Fundamentos del desarrollo iOS | 21 | M14 |
| 7. UIKit de cero a avanzado | 22–27 | M21 |
| 8. Concurrencia y memoria | 28–29 | M26, M13 |
| 9. Datos, arquitectura y testing | 30–33 | M29 |
| 10. SwiftUI | 34–39 | M27, M29 |
| 11. Integración UIKit y SwiftUI | 40 | M39 |
| 12. Calidad profesional y seguridad | 41–43 | M33, M31, M40 |
| 13. Tecnologías del sistema (opcional) | 44–45 | M37 |
| 14. Entrevistas técnicas | 46–48 | M20, M42, M43 |
| 15. Ejercer como iOS Engineer | 49 | M48 |

Los algoritmos (etapa 5) pueden estudiarse en paralelo a las etapas 6 y 7 una vez terminado el módulo 10: solo dependen de Swift.

El validador comprueba que cada prerrequisito exista y vaya antes en la numeración, para que la secuencia no tenga ciclos ni saltos hacia adelante.

## Criterios de evaluación

- **Lección completada:** todos sus ejercicios intentados y marcada por el estudiante.
- **Lección dominada:** completada y con el último intento de cada ejercicio correcto.
- **Ejercicios automáticos (A–D):** correcto o incorrecto; completar código admite parcial.
- **Ejercicios con rúbrica (E–H), retos y preguntas:** puntaje = fracción de criterios cumplidos; 100 % correcto, 50 % o más parcial, menos incorrecto. Lo no correcto entra al repaso.
- **Reto dominado:** resuelto de nuevo sin ayuda, marcado por el estudiante.
- **Proyecto:** hitos completados y criterios de aceptación verificados.

## Proyectos

| # | Proyecto | Después de |
| --- | --- | --- |
| 1 | Gestor de gastos en consola | M8 |
| 2 | Biblioteca de algoritmos con pruebas | M16 |
| 3 | Primera app UIKit: lista de lectura | M25 |
| 4 | App UIKit con API pública | M33 |
| 5 | La misma app en SwiftUI | M37 |
| 6 | App híbrida | M40 |
| 7 | App profesional (seguridad, accesibilidad, CI) | M43 |
| 8 | Proyecto final | M48 |

## Banco inicial de retos

Escritos: FizzBuzz, Contains Duplicate, Two Sum, Valid Palindrome, Valid Parentheses.

Planificados (en orden de producción): Reverse String, Valid Anagram, First Non-Repeating Character, Character Frequency, Find Maximum and Minimum, Remove Duplicates, Missing Number, Intersection of Two Arrays, Move Zeroes, Merge Sorted Arrays, Binary Search, Best Time to Buy and Sell Stock, Palindrome Number, Reverse Integer, Factorial, Fibonacci, Climbing Stairs, Maximum Subarray, Product of Array Except Self, Group Anagrams, Longest Substring Without Repeating Characters, Merge Intervals, Implement Stack, Implement Queue, Reverse Linked List, Detect Cycle in Linked List, Maximum Depth of Binary Tree, Level Order Traversal, Number of Islands, Coin Change, Subsets, Permutations, LRU Cache, y el resto de NeetCode 150 por patrón hasta superar 100 retos.
