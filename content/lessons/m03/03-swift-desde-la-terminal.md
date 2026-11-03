---
id: m03-l03
title: "Swift desde la terminal: archivos sueltos y Swift Packages"
description: Ejecutas Swift sin abrir Xcode, con swift archivo.swift y swiftc, creas un Swift Package con swift package init y lo compilas, ejecutas y pruebas con swift build, swift run y swift test.
module: m03
order: 3
level: inicial
minutes: 45
prerequisites: [m03-l02]
codeStatus: probado
swiftVersion: "6.4"
objectives:
  - Ejecutar un archivo de Swift con swift y compilarlo a un ejecutable con swiftc.
  - Crear un Swift Package ejecutable con swift package init.
  - Explicar qué contienen Package.swift, Sources y Tests.
  - Compilar, ejecutar y probar un paquete con swift build, swift run y swift test.
terms:
  - term: Terminal
    definition: Aplicación para dar órdenes escribiendo comandos. En macOS se llama Terminal y está en Aplicaciones › Utilidades.
  - term: Directorio de trabajo
    definition: La carpeta en la que está «parada» la terminal. Los comandos buscan archivos ahí. Se cambia con cd y se consulta con pwd.
  - term: Ejecutable
    definition: Archivo que contiene un programa ya compilado y se puede ejecutar directamente.
  - term: Swift Package
    definition: Carpeta con un archivo Package.swift que describe uno o más módulos de código, sus dependencias y sus pruebas. Lo maneja Swift Package Manager (SwiftPM).
  - term: Manifiesto
    definition: El archivo Package.swift. Está escrito en Swift y declara el nombre del paquete, sus targets y sus dependencias.
  - term: Swift Package Manager
    definition: La herramienta oficial de Swift para crear, compilar, probar paquetes y descargar dependencias. Se usa con swift package, swift build, swift run y swift test.
mastery:
  - Ejecutar un archivo .swift desde la terminal y explicar en qué se diferencia de compilarlo con swiftc.
  - Crear un paquete ejecutable, cambiar su mensaje y ejecutarlo con swift run.
  - Describir sin consultar la lección qué hay en Package.swift, Sources y Tests.
  - Ejecutar swift test en un paquete y localizar en la salida si las pruebas pasaron.
resources: [swiftpm-docs, swift-cli-getting-started, swift-install]
cards:
  - id: m03-l03-c1
    front: ¿Qué diferencia hay entre `swift hola.swift` y `swiftc hola.swift -o hola`?
    back: "swift hola.swift compila y ejecuta en un solo paso sin dejar un ejecutable. swiftc genera el ejecutable hola, que luego ejecutas con ./hola."
  - id: m03-l03-c2
    front: ¿Qué comando crea un paquete ejecutable?
    back: "`swift package init --type executable`, dentro de una carpeta vacía. El nombre del paquete es el de la carpeta, salvo que uses --name."
  - id: m03-l03-c3
    front: ¿Para qué sirven swift build, swift run y swift test?
    back: swift build compila el paquete; swift run compila si hace falta y ejecuta el producto ejecutable; swift test compila y ejecuta las pruebas.
  - id: m03-l03-c4
    front: ¿Qué es Package.swift?
    back: El manifiesto del paquete. Archivo escrito en Swift que declara nombre, targets (código y pruebas), productos y dependencias.
---

## La idea en una frase

Xcode no es la única forma de ejecutar Swift: la terminal te da un ciclo más rápido para practicar y es la forma en que se prueban los retos de este curso.

> [!nota]
> Las salidas que verás en esta lección se obtuvieron ejecutando los comandos con Swift 6.3.3. En macOS, con otra versión, los mensajes de progreso pueden variar en detalles (números de pasos, tiempos, rutas); los archivos y los resultados son los mismos.

## Lo mínimo de la terminal

Tres comandos bastan para moverte:

```bash
pwd                 # muestra en qué carpeta estás
ls                  # lista lo que hay en la carpeta
cd Documentos       # entra a la carpeta Documentos
```

`cd ..` sube a la carpeta anterior. En la terminal, lo que va después de `#` en una línea es un comentario, igual que `//` en Swift.

## Un archivo suelto: swift y swiftc

Crea un archivo `hola.swift` con cualquier editor de texto (o en Xcode con *File → New → File…*):

```swift
print("Hola desde un archivo")
```

```output
Hola desde un archivo
```

Hay dos formas de ejecutarlo. La primera compila y ejecuta en un solo paso:

```bash
swift hola.swift
```

```output
Hola desde un archivo
```

La segunda compila a un ejecutable y después lo ejecutas:

```bash
swiftc hola.swift -o hola
./hola
```

```output
Hola desde un archivo
```

Línea por línea:

1. `swiftc` es el compilador. `hola.swift` es la entrada y `-o hola` indica el nombre del ejecutable de salida.
2. `./hola` ejecuta el archivo `hola` de la carpeta actual. El `./` es necesario: la terminal no busca programas en la carpeta actual a menos que se lo indiques.

`swift hola.swift` es cómodo para practicar. `swiftc` produce un archivo que puedes ejecutar muchas veces sin volver a compilar. En ambos casos el código pasa por el compilador antes de ejecutarse, como viste en la lección «Del código fuente al programa».

## Un Swift Package

Para algo más que un archivo, Swift tiene su propio formato de proyecto, el **Swift Package**. Es el formato de las soluciones de los retos de este curso (carpeta `swift/` del repositorio) y el formato con el que se distribuyen bibliotecas en el ecosistema Swift.

### Crearlo

```bash
mkdir Saludo
cd Saludo
swift package init --type executable
```

```output
Creating executable package: Saludo
Creating Package.swift
Creating .gitignore
Creating Sources
Creating Sources/Saludo/Saludo.swift
Creating Tests/
Creating Tests/SaludoTests/
Creating Tests/SaludoTests/SaludoTests.swift
```

El paquete toma el nombre de la carpeta. Con Swift 6.3.3 la estructura generada es:

```plaintext
Saludo/
├── Package.swift
├── Sources/
│   └── Saludo/
│       └── Saludo.swift
└── Tests/
    └── SaludoTests/
        └── SaludoTests.swift
```

> [!version]
> La plantilla de `swift package init` ha cambiado entre versiones: algunas generan `main.swift` en lugar de `Saludo.swift`, y no todas crean la carpeta `Tests`. Si tu estructura es un poco distinta, no es un error.

### Package.swift, el manifiesto

```swift ilustrativo
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Saludo",
    targets: [
        .executableTarget(
            name: "Saludo"
        ),
        .testTarget(
            name: "SaludoTests",
            dependencies: ["Saludo"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Línea por línea (es una versión sin los comentarios que agrega la plantilla):

1. `// swift-tools-version: 6.3` parece un comentario, pero SwiftPM lo lee: es la versión mínima de las herramientas que necesita este paquete. Debe ser la primera línea.
2. `import PackageDescription` trae las definiciones para describir paquetes.
3. `Package(name: …)` declara el paquete.
4. `.executableTarget(name: "Saludo")` declara un módulo que produce un ejecutable. Su código vive en `Sources/Saludo`.
5. `.testTarget(…)` declara las pruebas, en `Tests/SaludoTests`, que dependen del módulo `Saludo`.
6. `swiftLanguageModes: [.v6]` pide compilar en modo de lenguaje Swift 6.

No necesitas entender aún cada palabra de esta sintaxis; la estudiarás en los módulos de Swift. Lo importante es la relación: **cada target del manifiesto corresponde a una carpeta**.

### El código del ejecutable

`Sources/Saludo/Saludo.swift` contiene un programa de ejemplo:

```swift ilustrativo
@main
struct Saludo {
    static func main() {
        print("Hello, world!")
    }
}
```

`@main` marca dónde empieza el programa. Por ahora, considera que todo lo que pongas dentro de `main()` se ejecuta de arriba hacia abajo. En un archivo suelto o en `main.swift` puedes escribir las instrucciones directamente, como en la lección anterior.

### Compilar, ejecutar y probar

```bash
swift build
```

Compila el paquete. La salida termina con una línea parecida a `Build complete! (3.42s)`. Los archivos compilados quedan en la carpeta oculta `.build`, que la plantilla excluye de git con `.gitignore`.

```bash
swift run
```

```output
Building for debugging...
[0/2] Write swift-version-24593BA9C3E375BF.txt
Build of product 'Saludo' complete! (0.13s)
Hello, world!
```

`swift run` compila lo que haya cambiado y ejecuta el producto. Las tres primeras líneas son del compilador; la última es la salida de tu programa.

```bash
swift test
```

Compila y ejecuta las pruebas. Con la plantilla de Swift 6.3.3, la salida termina con líneas como:

```output
✔ Test example() passed after 0.001 seconds.
✔ Test run with 1 test in 0 suites passed after 0.001 seconds.
```

El símbolo ✔ indica pruebas que pasan; uno que falla se marca con ✘. Escribirás tus propias pruebas con Swift Testing en el módulo de testing; mientras tanto, usarás `swift test` para comprobar tus soluciones de los retos.

## Ejemplo práctico: probar los retos del curso

El repositorio de esta academia tiene un paquete en `swift/` con la solución y las pruebas de cada reto. Desde la carpeta del repositorio:

```bash
cd swift
swift test --filter FizzBuzzTests
```

`--filter` ejecuta solo las pruebas cuyo nombre coincide. Para practicar un reto, escribe tu propia solución en una rama aparte y ejecuta sus pruebas; si todas pasan, tu solución cumple lo que las pruebas verifican.

## Errores frecuentes

> [!error] error: error opening input file 'hola.swift' (No such file or directory)
> La terminal no está en la carpeta del archivo, o el nombre está mal escrito. Usa `pwd` para ver dónde estás, `ls` para ver qué hay y `cd` para llegar a la carpeta correcta.

> [!error] zsh: command not found: hola
> Para ejecutar un programa de la carpeta actual hay que escribir `./hola`, no `hola`.

> [!error] error: Could not find Package.swift in this directory or any of its parent directories.
> Ejecutaste `swift build`, `swift run` o `swift test` fuera de la carpeta del paquete. Entra con `cd` a la carpeta que contiene `Package.swift`.

> [!error] Editar archivos dentro de .build
> `.build` contiene resultados de compilación que se regeneran. Si la cambias, tus cambios se pierden. Edita solo `Sources`, `Tests` y `Package.swift`.

````exercise
id: m03-l03-e1
type: comprension
prompt: Estás en la carpeta de un Swift Package y quieres comprobar que las pruebas pasan. ¿Qué comando usas?
choices:
  - text: "`swift build`"
    correct: false
    why: Solo compila; no ejecuta las pruebas.
  - text: "`swift run`"
    correct: false
    why: Ejecuta el producto ejecutable, no las pruebas.
  - text: "`swift test`"
    correct: true
    why: Compila y ejecuta las pruebas del paquete.
  - text: "`swiftc Package.swift`"
    correct: false
    why: Package.swift es un manifiesto que lee SwiftPM; no se compila así.
solution: |
  **`swift test`** compila el paquete y sus targets de prueba y ejecuta las pruebas. Al final indica cuántas pasaron; las que fallan se marcan con ✘ y muestran qué esperaba la prueba y qué obtuvo.
````

````exercise
id: m03-l03-e2
type: prediccion
prompt: Guardas este programa como `tabla.swift` y ejecutas `swift tabla.swift`. Escribe exactamente lo que aparece en la terminal.
code: |
  print("Tabla del 9")
  print(9 * 1)
  print(9 * 2)
  print(9 * 3)
  print("9 * 4")
output: |
  Tabla del 9
  9
  18
  27
  9 * 4
hints:
  - La última línea está entre comillas.
solution: |
  ```output
  Tabla del 9
  9
  18
  27
  9 * 4
  ```

  Las tres multiplicaciones se calculan. La última línea es un texto entre comillas y se imprime tal cual: `9 * 4`, no 36. Con `swiftc tabla.swift -o tabla` y `./tabla` la salida sería idéntica: cambia cómo se compila, no lo que hace el programa.
````

````exercise
id: m03-l03-e3
type: completar
prompt: |
  Completa la secuencia de comandos para crear un paquete ejecutable llamado `Notas`, ejecutarlo y correr sus pruebas.
code: |
  mkdir Notas
  [[1]] Notas
  swift package init --type [[2]]
  swift [[3]]
  swift [[4]]
blanks:
  - id: "1"
    answers: ["cd"]
  - id: "2"
    answers: ["executable"]
  - id: "3"
    answers: ["run"]
  - id: "4"
    answers: ["test"]
solution: |
  ```bash
  mkdir Notas
  cd Notas
  swift package init --type executable
  swift run
  swift test
  ```

  `cd` entra a la carpeta nueva; el paquete toma su nombre. `--type executable` crea un paquete con un producto ejecutable. `swift run` compila y ejecuta; `swift test` compila y ejecuta las pruebas.
````

````exercise
id: m03-l03-e4
type: resolver
prompt: |
  Crea un paquete ejecutable llamado `Saludo` con `swift package init --type executable`. Cambia el programa para que imprima estas dos líneas en lugar de `Hello, world!`:

  ```output
  Hola, soy tu primer paquete
  2 + 2 = 4
  ```

  El 4 debe calcularse. Ejecútalo con `swift run` y después corre `swift test`.
starter: |
  // Sources/Saludo/Saludo.swift
  @main
  struct Saludo {
      static func main() {
          print("Hello, world!")
      }
  }
hints:
  - "Solo cambias el contenido de main(): las líneas print."
  - "print con dos valores los separa con un espacio: print(\"2 + 2 =\", 2 + 2)."
rubric:
  - Creé el paquete con swift package init dentro de una carpeta llamada Saludo.
  - Modifiqué el archivo de Sources y no el de .build.
  - swift run muestra las dos líneas pedidas después de los mensajes de compilación.
  - El 4 se calcula con una expresión.
  - swift test termina sin pruebas fallidas.
solution: |
  ```swift ilustrativo
  @main
  struct Saludo {
      static func main() {
          print("Hola, soy tu primer paquete")
          print("2 + 2 =", 2 + 2)
      }
  }
  ```

  `print("2 + 2 =", 2 + 2)` imprime el texto, un espacio y el resultado de la suma. Si tu plantilla generó `main.swift` en lugar de `Saludo.swift`, escribe solo las dos líneas `print` en ese archivo, sin `@main` ni `struct`.

  La plantilla de pruebas no comprueba nada todavía, así que `swift test` pasa. En el módulo de testing escribirás pruebas que sí verifiquen tu código.
````

````exercise
id: m03-l03-e5
type: explicar
prompt: Explica para qué sirve cada parte de esta estructura y qué pasaría si borraras la carpeta `.build`.
code: |
  Saludo/
  ├── .build/
  ├── Package.swift
  ├── Sources/
  │   └── Saludo/
  │       └── Saludo.swift
  └── Tests/
      └── SaludoTests/
          └── SaludoTests.swift
rubric:
  - Expliqué que Package.swift es el manifiesto y declara los targets.
  - Relacioné Sources/Saludo y Tests/SaludoTests con los targets del manifiesto.
  - Expliqué que .build contiene resultados de compilación.
  - Dije que borrar .build no pierde código; la siguiente compilación la regenera, más lenta.
solution: |
  - `Package.swift` es el **manifiesto**: declara el nombre del paquete y sus targets.
  - `Sources/Saludo` contiene el código del target ejecutable `Saludo`.
  - `Tests/SaludoTests` contiene las pruebas del target `SaludoTests`, que depende de `Saludo`.
  - `.build` contiene resultados de compilación y lo que SwiftPM descarga.

  Si borras `.build` no pierdes código: la siguiente vez que ejecutes `swift build`, `swift run` o `swift test`, SwiftPM la regenera. Esa primera compilación será más lenta porque empieza de cero. Borrarla es, de hecho, un remedio común cuando la compilación se comporta de forma extraña.
````

## Resumen

- `swift archivo.swift` compila y ejecuta en un paso; `swiftc archivo.swift -o nombre` produce un ejecutable que corres con `./nombre`.
- `swift package init --type executable` crea un paquete con `Package.swift`, `Sources` y, en versiones recientes, `Tests`.
- Cada target del manifiesto corresponde a una carpeta.
- `swift build` compila, `swift run` ejecuta, `swift test` prueba; deben ejecutarse en la carpeta del paquete.
- `.build` se regenera; tu código vive en `Sources` y `Tests`.
