import {setSecret, exportVariable} from '@actions/core'
import {ParamValue} from './get-values'

export const setEnv = (params: ParamValue[]): void => {
  for (const param of params) {
    if (param.secret) {
      setSecret(param.value)
    }
    exportVariable(param.name, param.value)
  }
}
