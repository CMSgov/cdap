import {SSMClient, GetParametersCommand} from '@aws-sdk/client-ssm'
import {setFailed} from '@actions/core'

export type ParamValue = {
  name: string
  value: string
  secret: boolean
}

export const getValues = async (
  paramsObj: Record<string, string>
): Promise<ParamValue[]> => {
  const client = new SSMClient({})
  const input = {
    Names: Object.keys(paramsObj),
    WithDecryption: true
  }
  const command = new GetParametersCommand(input)
  const response = await client.send(command)
  const invalid = response.InvalidParameters
  if (invalid && invalid.length > 0) {
    setFailed(`Invalid parameters: ${invalid}`)
  }
  const params = response.Parameters
  const values: ParamValue[] = []
  if (!params) return values
  for (const param of params) {
    if (!param.Name || !param.Value) continue // Convince typescript these are defined
    values.push({
      name: paramsObj[param.Name],
      value: param.Value,
      secret: param.Type === 'SecureString'
    })
  }
  return values
}
