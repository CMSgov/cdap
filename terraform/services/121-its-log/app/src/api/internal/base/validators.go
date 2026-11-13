package base

import (
	"encoding/base64"
	"fmt"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin/binding"
	"github.com/go-playground/validator/v10"
	"go.uber.org/zap"
)

var validators = []struct {
	name      string
	validator validator.Func
}{
	{"validateYMD", validateYMD},
	{"validateB64SQL", validateB64sql},
	{"validateArrString", validateArrString},
}

// FIXME: Gin has support for this library
// https://oneuptime.com/blog/post/2026-01-30-how-to-implement-request-validation-with-go-playground/view#custom-validators
// We should incorporate it fully. And, improve the error messages that come back.
func validateYMD(fl validator.FieldLevel) bool {
	ymd := fl.Field().String()
	// Simple check: must start with + and be 10-15 chars
	matched, err := regexp.MatchString(`\d{4}-\d{2}-\d{2}`, ymd)
	if err != nil {
		return false
	}
	return matched
}

func CheckNotAllowed(decoded string) bool {
	lowered := strings.ToLower(string(decoded))
	// And, for fun: let's make sure the words "delete" or "update"
	// do not appear anywhere in this ETL. We don't want ETLs to be able to
	// delete data.
	for _, notAllowed := range []string{"insert", "delete", "update"} {
		if strings.Contains(lowered, notAllowed) {
			zap.L().Info("naughty things in sql",
				zap.String("sql", lowered),
				zap.String("not_allowed", notAllowed))
			return false
		}
	}
	return true
}
func validateB64sql(fl validator.FieldLevel) bool {
	b64 := fl.Field().String()
	// Lets try and Base64 decode the string, to make sure it is good.
	decoded, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		zap.L().Info("validateB64: could not decode", zap.String("b64", b64))
		return false
	}
	return CheckNotAllowed(string(decoded))
}

func validateArrString(fl validator.FieldLevel) bool {
	_, ok := fl.Field().Interface().([]string)
	if !ok {
		zap.L().Info("did not validate as string array")
		return false
	}
	return true
}

// func setupValidators() *validator.Validate {
// 	validate := validator.New()

// 	// Register custom validators with descriptive names
// 	var err error
// 	err = validate.RegisterValidation("validateYMD", validateYMD)
// 	if err != nil {
// 		panic("could not register ymd validator")
// 	}
// 	err = validate.RegisterValidation("validateB64SQL", validateB64sql)
// 	if err != nil {
// 		panic("could not register b64 validator")
// 	}

// 	return validate
// }

func SetupValidators() error {
	for _, tv := range validators {
		if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
			v.RegisterValidation(tv.name, tv.validator)
		} else {
			return fmt.Errorf("failed to set up %s", tv.name)
		}
	}
	return nil
}
