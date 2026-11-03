import { validateCatalog } from '../src/content/validate'
import { loadFromDisk } from './load-content'

const { catalog, issues } = loadFromDisk()
const report = validateCatalog(catalog)
const errors = [...issues, ...report.errors]

const exercises = catalog.lessons.reduce((n, l) => n + l.exercises.length, 0)
console.log(
  `Contenido: ${catalog.stages.length} etapas, ${catalog.modules.length} módulos, ${catalog.lessons.length} lecciones, ` +
    `${exercises} ejercicios, ${catalog.challenges.length} retos, ${catalog.questions.length} preguntas de entrevista, ` +
    `${catalog.projects.length} proyectos, ${catalog.resources.length} recursos.`,
)
if (process.argv.includes('--warnings'))
  for (const w of report.warnings) console.log(`  aviso  ${w.path}: ${w.message}`)
else if (report.warnings.length) console.log(`${report.warnings.length} avisos (ejecuta con --warnings para verlos).`)

if (errors.length) {
  for (const e of errors) console.error(`  error  ${e.path}: ${e.message}`)
  console.error(`\n${errors.length} errores de contenido.`)
  process.exit(1)
}
console.log('Validación de contenido: sin errores.')
