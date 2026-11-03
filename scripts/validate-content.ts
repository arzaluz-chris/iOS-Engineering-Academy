import { validateCatalog } from '../src/content/validate'
import { loadFromDisk } from './load-content'

const { catalog, issues } = loadFromDisk()
const report = validateCatalog(catalog)
const errors = [...issues, ...report.errors]

const exercises = catalog.lessons.reduce((n, l) => n + l.exercises.length, 0)
console.log(
  `Content: ${catalog.stages.length} stages, ${catalog.modules.length} modules, ${catalog.lessons.length} lessons, ` +
    `${exercises} exercises, ${catalog.challenges.length} challenges, ${catalog.questions.length} interview questions, ` +
    `${catalog.projects.length} projects, ${catalog.resources.length} resources.`,
)
if (process.argv.includes('--warnings'))
  for (const w of report.warnings) console.log(`  warning  ${w.path}: ${w.message}`)
else if (report.warnings.length) console.log(`${report.warnings.length} warnings (run with --warnings to see them).`)

if (errors.length) {
  for (const e of errors) console.error(`  error  ${e.path}: ${e.message}`)
  console.error(`\n${errors.length} content errors.`)
  process.exit(1)
}
console.log('Content validation: no errors.')
