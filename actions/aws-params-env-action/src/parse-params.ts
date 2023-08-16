import {setFailed} from '@actions/core'

export const parseParams = (params: string): Record<string, string> => {
  return params.split(/\s+/).reduce<Record<string, string>>((obj, param) => {
    if (!param) return obj
    const splitParam = param.split('=')
    if (!splitParam[0] || !splitParam[1]) {
      setFailed(`Parameter "${param}" is not of the form "ENV_VAR=/aws/param"`)
    }
    obj[splitParam[1]] = splitParam[0]
    return obj
  }, {})
}
