import * as core from '@actions/core'
import {parseParams} from './parse-params'
import {getValues} from './get-values'
import {setEnv} from './set-env'

async function run(): Promise<void> {
  try {
    const params: string = core.getInput('params')
    const parsed = parseParams(params)
    core.debug(`Getting values for these params:\n${parsed}`)

    core.debug(new Date().toTimeString())
    const values = await getValues(parsed)
    core.debug(new Date().toTimeString())

    core.debug(`Values retrieved from AWS. Setting env...`)
    setEnv(values)
  } catch (error) {
    if (error instanceof Error) core.setFailed(error.message)
  }
}

run()
