# development

`its-log` is a [Gin](https://gin-gonic.com/) based Golang API. 

To develop, you should (ideally) configure a debugging environment (provided for VS Code), and for some activities, you will need to run the storage stack, emulating cloud services that `its-log` might rely on in production.

## adding API endpoints

From the "top down," endpoints are attached to the router in `api/endpoints/serve.go`. The function `PourGin` contains a sequence of helpers that attach different endpoints based on functionality.

Using the logging endpoints as an example:

```go
func addLoggingEndpoints(rG *gin.RouterGroup, ch_evt_out chan<- *types.Event) {
	auth_logV1 := rG.Group("/")
	permissions := []types.PermissionType{constants.Log, constants.Test}
	auth_logV1.Use(AuthMiddleWare(permissions))
	auth_logV1.POST(constants.LOG_CREATE, LogCreate(ch_evt_out, constants.Log))
	auth_logV1.POST(constants.LOG_CREATE_DATE, LogCreate(ch_evt_out, constants.Test))
}
```

Each endpoint group is granted role-based permissions. The endpoint URLs are defined in `constants`, as they get re-used in testing (and therefore want to be defined in one place). All `gin` handlers have the signature `func (*gin.Context) {}`, but some of the endpoints in `its-log` are [curried](https://wiki.haskell.org/index.php?title=Currying) so that additional parameters can be passed to the handlers (as in the logging portion of the API).

## types

Wherever possible, `its-log` introduces types/abstractions. The internal "its-log time," or `ILTime` structure is an example. Because we move between several time representations (SQLite does not have great time facilities compared to other DB implementations), it is easiest/safest to encapsulate the manipulation of time (and its representation) in one place.

Also, putting base types in one place helps eliminate circular dependencies.

Types are found in `api/internal/types`. 

## e2e

The end-to-end tests are best run containerized. 

`make e2e`

## etl

`its-log` encapsulates an entire extract/transform/load service. This allows users of `its-log` to write transforms in SQL, Golang, and [Starlark](https://starlark-lang.org/), a Python-like scripting language. These transforms can be added dynamically via API (think as part of "infrastructure as code"), executed, and the results downloaded from the `summary` table.

How to write ETLs in each of these langauges is covered further in the [ETL HOWTO](etl-howto.md).

