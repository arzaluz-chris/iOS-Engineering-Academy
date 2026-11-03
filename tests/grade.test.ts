import { describe, expect, it } from 'vitest'
import { gradeBlanks, gradeChoices, gradePrediction, splitBlanks } from '../src/exercises/grade'

describe('calificación de respuestas estructuradas', () => {
  it('opción única y múltiple', () => {
    expect(gradeChoices([1], [false, true, false])).toBe(true)
    expect(gradeChoices([0], [false, true, false])).toBe(false)
    expect(gradeChoices([0, 1], [true, true, false])).toBe(true)
    expect(gradeChoices([0], [true, true, false])).toBe(false)
  })

  it('predicción tolera espacios finales y saltos al final, no diferencias reales', () => {
    expect(gradePrediction('Hola  \n5\n', 'Hola\n5')).toBe(true)
    expect(gradePrediction('Hola\r\n5', 'Hola\n5')).toBe(true)
    expect(gradePrediction('Hola 5', 'Hola\n5')).toBe(false)
    expect(gradePrediction('hola\n5', 'Hola\n5')).toBe(false)
    expect(gradePrediction('3.50', '3.5', ['3.50'])).toBe(true)
  })

  it('huecos con respuestas equivalentes', () => {
    const r = gradeBlanks({ '1': ' // ', '2': 'x' }, [
      { id: '1', answers: ['//'] },
      { id: '2', answers: ['*'] },
    ])
    expect(r).toEqual({ '1': true, '2': false })
  })

  it('separa el código en texto y huecos', () => {
    expect(splitBlanks('a [[1]] b')).toEqual([
      { kind: 'text', text: 'a ' },
      { kind: 'blank', id: '1' },
      { kind: 'text', text: ' b' },
    ])
  })
})
