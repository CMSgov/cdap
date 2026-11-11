package endpoints

import (
	"encoding/base64"
	"regexp"
	"strings"

	"github.com/go-playground/validator/v10"
	"go.uber.org/zap"
)

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

func validateB64sql(fl validator.FieldLevel) bool {
	b64 := fl.Field().String()
	// Lets try and Base64 decode the string, to make sure it is good.
	decoded, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		zap.L().Info("validateB64: could not decode", zap.String("b64", b64))
		return false
	}

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

func setupValidators() *validator.Validate {
	validate := validator.New()

	// Register custom validators with descriptive names
	validate.RegisterValidation("yyyymmdd", validateYMD)
	validate.RegisterValidation("b64sql", validateB64sql)

	return validate
}
