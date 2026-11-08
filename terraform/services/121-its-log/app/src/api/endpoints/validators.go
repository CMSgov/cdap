package endpoints

import (
	"regexp"

	"github.com/go-playground/validator/v10"
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

func setupValidators() *validator.Validate {
	validate := validator.New()

	// Register custom validators with descriptive names
	validate.RegisterValidation("yyyymmdd", validateYMD)

	return validate
}
