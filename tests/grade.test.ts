import { describe, expect, it } from 'vitest'
import { gradeBlanks, gradeChoices, gradePrediction, splitBlanks } from '../src/exercises/grade'

describe('grading structured answers', () => {
  it('single and multiple choice', () => {
    expect(gradeChoices([1], [false, true, false])).toBe(true)
    expect(gradeChoices([0], [false, true, false])).toBe(false)
    expect(gradeChoices([0, 1], [true, true, false])).toBe(true)
    expect(gradeChoices([0], [true, true, false])).toBe(false)
  })

  it('prediction tolerates trailing spaces and trailing newlines, not real differences', () => {
    expect(gradePrediction('Hello  \n5\n', 'Hello\n5')).toBe(true)
    expect(gradePrediction('Hello\r\n5', 'Hello\n5')).toBe(true)
    expect(gradePrediction('Hello 5', 'Hello\n5')).toBe(false)
    expect(gradePrediction('hello\n5', 'Hello\n5')).toBe(false)
    expect(gradePrediction('3.50', '3.5', ['3.50'])).toBe(true)
  })

  it('blanks with equivalent answers', () => {
    const r = gradeBlanks({ '1': ' // ', '2': 'x' }, [
      { id: '1', answers: ['//'] },
      { id: '2', answers: ['*'] },
    ])
    expect(r).toEqual({ '1': true, '2': false })
  })

  it('splits code into text and blanks', () => {
    expect(splitBlanks('a [[1]] b')).toEqual([
      { kind: 'text', text: 'a ' },
      { kind: 'blank', id: '1' },
      { kind: 'text', text: ' b' },
    ])
  })
})
