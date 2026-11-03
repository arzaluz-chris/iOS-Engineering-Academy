# Fase 6. Producción de contenido

## Lote 1 (3 de noviembre de 2026)

| Pieza | Cantidad | Detalle |
| --- | --- | --- |
| Lecciones | 4 | M1: qué es programar; del código fuente al programa; Swift, Xcode e iOS. M4: print, comentarios, literales y expresiones |
| Ejercicios | 16 | Los ocho formatos; los siete de `m04-l01` cubren B a G |
| Tarjetas de repaso | 13 | En el frontmatter de cada lección |
| Retos | 5 | FizzBuzz, Contains Duplicate, Two Sum, Valid Palindrome, Valid Parentheses |
| Preguntas de entrevista | 17 | Swift (4), memoria (1), concurrencia (2), UIKit (2), SwiftUI (1), arquitectura (2), seguridad (3), testing (1), system design (1) |
| Proyectos | 8 | Especificados con requisitos, criterios de aceptación e hitos |
| Recursos | 20 | Verificados el 3 nov 2026 |

## Checklist del lote

| Paso | Resultado |
| --- | --- |
| 1. Escribir lecciones | Hecho |
| 2. Revisar exactitud técnica | Revisión estática. Salidas de predicción calculadas a mano y revisadas; comportamiento de `print`, división entera, precedencia, comentarios anidados y mensajes de error del compilador contrastados con la documentación de Swift |
| 3. Comprobar prerrequisitos | Validador sin errores |
| 4. Verificar ejemplos | Ejemplos de lecciones: **revisados, no ejecutados** (`codeStatus: revisado` o `ilustrativo`). Código de retos: ejecutado en CI |
| 5. Comprobar soluciones | `swift test`: 18 pruebas en 5 suites pasan |
| 6. Verificar enlaces | 20/20 |
| 7. Pruebas y rúbricas | Todas las piezas con rúbrica o calificación automática |
| 8. Validaciones automáticas | `npm run validate` sin errores |
| 9. Corregir errores | Se corrigieron 9 errores de YAML detectados por el validador (valores con «: » sin comillas) |

## Pendiente para el siguiente lote

Verificar en Xcode las salidas de los ejercicios de predicción de `m04-l01` y de `m01-l02`, y cambiar su `codeStatus` a `probado` si coinciden. Después, módulos 2 y 3.
