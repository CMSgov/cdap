# Adding a script, Lambda function, or GitHub Action

Any new code under `terraform/services/**/lambda_src/`, `scripts/*/`, or `actions/*/`
is automatically picked up by `code-checks.yml` and scanned/tested on every pull
request. Nothing needs to be registered manually — detection is based on marker
files:

| Marker file       | Language detected |
|--------------------|--------------------|
| `go.mod`           | Go                 |
| `package.json`     | Node / TypeScript  |
| `requirements.txt` | Python             |

To be considered "check-ready," a directory should have:

1. **A Makefile** with at minimum `install`, `test`, and `lint` targets, so a
   developer can validate changes locally with the same commands CI uses.
   Add a `dry-run` or `plan` target if the code talks to AWS, so local usage
   is self-documenting about needing active credentials.
2. **A `sonar-project.properties` file** covering settings intrinsic to the
   code itself — test directory location, TypeScript config paths, coverage
   report paths. Do not duplicate `sonar.sources` or `sonar.exclusions` here;
   those are set centrally in `checks-reusable.yml` for every caller.
3. **A test suite** with a real `test_command` wired into a `checks.yml`
   file in the same directory (see below). Until this exists, the directory
   still gets a static Sonar scan on every PR, but with no coverage data —
   that's a valid but temporary state, not a passing bar.

## Overriding CI behavior — `checks.yml`

Drop a `checks.yml` next to the code if defaults need overriding:

```yaml
enabled: true                # set false to exclude from checks entirely
test_command: "..."          # overrides the language default
language_version: "3.13"     # overrides the language default
sonar_extra_args: "..."      # rarely needed — prefer sonar-project.properties
```