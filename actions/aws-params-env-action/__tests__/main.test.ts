import {SSMClient, GetParametersCommand} from '@aws-sdk/client-ssm'
import {expect, test, jest, beforeEach, describe} from '@jest/globals'
import {getValues} from '../src/get-values'
import {mockClient} from 'aws-sdk-client-mock'
import {parseParams} from '../src/parse-params'
import {setEnv} from '../src/set-env'
import {exportVariable, setFailed, setSecret} from '@actions/core'

jest.mock('@actions/core')
const mockedExportVariable = jest.mocked(exportVariable)
const mockedSetFailed = jest.mocked(setFailed)
const mockedSetSecret = jest.mocked(setSecret)

// Declare client BEFORE beforeEach so the reference is clear
const client = mockClient(SSMClient)

beforeEach(() => {
  client.reset()
  jest.clearAllMocks()
})

describe('parseParams', () => {
  test('parses whitespace-separated params', () => {
    const params = `
      VARIABLE1=/good/variable
      VARIABLE2=/another/good/variable
      SECRET1=/good/secret
    `
    const parsed = {
      '/good/variable': 'VARIABLE1',
      '/another/good/variable': 'VARIABLE2',
      '/good/secret': 'SECRET1'
    }
    expect(parseParams(params)).toStrictEqual(parsed)
  })

  test('fails on malformed input params', () => {
    const params = `
      /some/variable
      VAR1=
    `
    parseParams(params)
    expect(mockedSetFailed.mock.calls).toHaveLength(2)
    expect(mockedSetFailed.mock.calls[0][0]).toBe(
      'Parameter "/some/variable" is not of the form "ENV_VAR=/aws/param"'
    )
    expect(mockedSetFailed.mock.calls[1][0]).toBe(
      'Parameter "VAR1=" is not of the form "ENV_VAR=/aws/param"'
    )
  })

  test('returns empty object for empty string', () => {
    expect(parseParams('')).toStrictEqual({})
  })

  test('returns empty object for whitespace-only string', () => {
    expect(parseParams('   \n  \t  ')).toStrictEqual({})
  })

  test('handles single param', () => {
    expect(parseParams('MY_VAR=/my/param')).toStrictEqual({
      '/my/param': 'MY_VAR'
    })
  })
})

describe('getValues', () => {
  test('retrieves mixed String and SecureString params', async () => {
    client.on(GetParametersCommand).resolves({
      Parameters: [
        {Name: '/a/variable', Type: 'String', Value: 'variable a value'},
        {Name: '/b/variable', Type: 'String', Value: 'variable b value'},
        {Name: '/a/secret', Type: 'SecureString', Value: 'secret a value'}
      ]
    })
    const parsed = {
      '/a/variable': 'VARIABLE_A',
      '/b/variable': 'VARIABLE_B',
      '/a/secret': 'SECRET_A'
    }
    const retrieved = await getValues(parsed)
    expect(retrieved).toStrictEqual([
      {name: 'VARIABLE_A', value: 'variable a value', secret: false},
      {name: 'VARIABLE_B', value: 'variable b value', secret: false},
      {name: 'SECRET_A', value: 'secret a value', secret: true}
    ])
  })

  test('fails on invalid parameters', async () => {
    client.on(GetParametersCommand).resolves({
      Parameters: [
        {Name: '/a/variable', Type: 'String', Value: 'variable a value'}
      ],
      InvalidParameters: ['/x/variable', '/y/variable']
    })
    const parsed = {
      '/a/variable': 'VARIABLE_A',
      '/x/variable': 'VARIABLE_X',
      '/y/variable': 'VARIABLE_Y'
    }
    await getValues(parsed)
    expect(mockedSetFailed.mock.calls).toHaveLength(1)
    expect(mockedSetFailed.mock.calls[0][0]).toBe(
      'Invalid parameters: /x/variable,/y/variable'
    )
  })

  test('does not fail when InvalidParameters is empty', async () => {
    client.on(GetParametersCommand).resolves({
      Parameters: [
        {Name: '/a/variable', Type: 'String', Value: 'variable a value'}
      ],
      InvalidParameters: []
    })
    await getValues({'/a/variable': 'VARIABLE_A'})
    expect(mockedSetFailed).not.toHaveBeenCalled()
  })

  test('returns empty array when Parameters is undefined', async () => {
    client.on(GetParametersCommand).resolves({
      Parameters: undefined
    })
    const result = await getValues({'/a/variable': 'VARIABLE_A'})
    expect(result).toStrictEqual([])
  })

  test('skips params with missing Name or Value', async () => {
    client.on(GetParametersCommand).resolves({
      Parameters: [
        {Name: '/a/variable', Type: 'String', Value: 'good value'},
        {Name: undefined, Type: 'String', Value: 'orphan value'},
        {Name: '/c/variable', Type: 'String', Value: undefined}
      ]
    })
    const parsed = {
      '/a/variable': 'VARIABLE_A',
      '/c/variable': 'VARIABLE_C'
    }
    const result = await getValues(parsed)
    expect(result).toStrictEqual([
      {name: 'VARIABLE_A', value: 'good value', secret: false}
    ])
  })

  test('returns empty array when Parameters is empty', async () => {
    client.on(GetParametersCommand).resolves({Parameters: []})
    const result = await getValues({})
    expect(result).toStrictEqual([])
  })
})

describe('setEnv', () => {
  test('exports all variables', () => {
    const params = [
      {name: 'VARIABLE_A', value: 'variable a value', secret: false},
      {name: 'VARIABLE_B', value: 'variable b value', secret: false},
      {name: 'SECRET_A', value: 'secret a value', secret: true}
    ]
    setEnv(params)
    expect(mockedExportVariable.mock.calls).toHaveLength(3)
    expect(mockedExportVariable.mock.calls[0]).toStrictEqual([
      'VARIABLE_A',
      'variable a value'
    ])
    expect(mockedExportVariable.mock.calls[1]).toStrictEqual([
      'VARIABLE_B',
      'variable b value'
    ])
    expect(mockedExportVariable.mock.calls[2]).toStrictEqual([
      'SECRET_A',
      'secret a value'
    ])
  })

  test('masks only SecureString values', () => {
    const params = [
      {name: 'VARIABLE_A', value: 'variable a value', secret: false},
      {name: 'SECRET_A', value: 'secret a value', secret: true}
    ]
    setEnv(params)
    expect(mockedSetSecret.mock.calls).toHaveLength(1)
    expect(mockedSetSecret.mock.calls[0][0]).toBe('secret a value')
  })

  test('calls setSecret before exportVariable for secrets', () => {
    const callOrder: string[] = []
    mockedSetSecret.mockImplementation(() => {
      callOrder.push('setSecret')
    })
    mockedExportVariable.mockImplementation(() => {
      callOrder.push('exportVariable')
    })

    setEnv([{name: 'SECRET_A', value: 'secret a value', secret: true}])

    expect(callOrder).toStrictEqual(['setSecret', 'exportVariable'])
  })

  test('does not call setSecret for non-secret params', () => {
    setEnv([
      {name: 'VARIABLE_A', value: 'value a', secret: false},
      {name: 'VARIABLE_B', value: 'value b', secret: false}
    ])
    expect(mockedSetSecret).not.toHaveBeenCalled()
    expect(mockedExportVariable).toHaveBeenCalledTimes(2)
  })

  test('handles empty params array', () => {
    setEnv([])
    expect(mockedExportVariable).not.toHaveBeenCalled()
    expect(mockedSetSecret).not.toHaveBeenCalled()
  })
})
