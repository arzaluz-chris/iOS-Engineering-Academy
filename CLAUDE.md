# Instrucciones para sesiones de desarrollo

Academia personal de iOS para Christian. Sitio estático en GitHub Pages; sin backend. Idioma del contenido: español de México, con términos técnicos e identificadores en inglés.

## Antes de trabajar

1. Lee `docs/ESTADO.md` (qué está hecho y qué sigue), `docs/CONTENIDO.md` (formato del contenido) y, si necesitas contexto, `docs/ESPECIFICACION.md` y `docs/fases/`.
2. Contenido en `content/`, soluciones Swift en `swift/`, aplicación en `src/`.

## Reglas

- Exactitud técnica primero. No inventes versiones, firmas ni comportamientos de APIs; si no se verificó, dilo.
- `codeStatus: probado` solo si el código se compiló y ejecutó. Las salidas de ejercicios de predicción deben estar verificadas.
- Ningún código Swift se califica comparando texto.
- Sin videos en recursos. Enlaza documentación concreta de la API.
- No reveles soluciones antes de que el estudiante las pida.
- No marques algo como terminado si es parcial; actualiza `docs/ESTADO.md` al cerrar cada lote.

## Comandos

```bash
npm run validate   # esquema e integridad del contenido
npm test           # pruebas web
npm run build      # validación + tipos + build
cd swift && swift test
```

Ejecuta `npm run validate && npm test` antes de cada commit.
