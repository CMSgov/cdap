import {SSMClient, GetParametersCommand} from '@aws-sdk/client-ssm'
import {expect, test, jest} from '@jest/globals'
import {getValues} from '../src/get-values'
import {mockClient} from 'aws-sdk-client-mock'
import {parseParams} from '../src/parse-params'
import {setEnv} from '../src/set-env'
import {exportVariable, setFailed, setSecret} from '@actions/core'

jest.mock('@actions/core')
const mockedExportVariable = jest.mocked(exportVariable)
const mockedSetFailed = jest.mocked(setFailed)
const mockedSetSecret = jest.mocked(setSecret)

test('parse input params', () => {
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

test('fail on malformed input params', () => {
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

const client = mockClient(SSMClient)

test('get param values from AWS', async () => {
  client.on(GetParametersCommand).resolves({
    Parameters: [
      {
        Name: '/a/variable',
        Type: 'String',
        Value: 'variable a value'
      },
      {
        Name: '/b/variable',
        Type: 'String',
        Value: 'variable b value'
      },
      {
        Name: '/a/secret',
        Type: 'SecureString',
        Value: 'secret a value'
      }
    ]
  })
  const parsed = {
    '/a/variable': 'VARIABLE_A',
    '/b/variable': 'VARIABLE_B',
    '/a/secret': 'SECRET_A'
  }
  const retrieved = await getValues(parsed)
  const expected = [
    {
      name: 'VARIABLE_A',
      value: 'variable a value',
      secret: false
    },
    {
      name: 'VARIABLE_B',
      value: 'variable b value',
      secret: false
    },
    {
      name: 'SECRET_A',
      value: 'secret a value',
      secret: true
    }
  ]
  expect(retrieved).toStrictEqual(expected)
})

test('fail on invalid parameter', async () => {
  client.on(GetParametersCommand).resolves({
    Parameters: [
      {
        Name: '/a/variable',
        Type: 'String',
        Value: 'variable a value'
      }
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

test('set environment variables', () => {
  const retrievedParams = [
    {
      name: 'VARIABLE_A',
      value: 'variable a value',
      secret: false
    },
    {
      name: 'VARIABLE_B',
      value: 'variable b value',
      secret: false
    },
    {
      name: 'SECRET_A',
      value: 'secret a value',
      secret: true
    }
  ]
  setEnv(retrievedParams)
  expect(mockedExportVariable.mock.calls).toHaveLength(3)
  expect(mockedExportVariable.mock.calls[0][0]).toBe('VARIABLE_A')
  expect(mockedExportVariable.mock.calls[0][1]).toBe('variable a value')
  expect(mockedExportVariable.mock.calls[1][0]).toBe('VARIABLE_B')
  expect(mockedExportVariable.mock.calls[1][1]).toBe('variable b value')
  expect(mockedExportVariable.mock.calls[2][0]).toBe('SECRET_A')
  expect(mockedExportVariable.mock.calls[2][1]).toBe('secret a value')
  expect(mockedSetSecret.mock.calls).toHaveLength(1)
  expect(mockedSetSecret.mock.calls[0][0]).toBe('secret a value')
})
