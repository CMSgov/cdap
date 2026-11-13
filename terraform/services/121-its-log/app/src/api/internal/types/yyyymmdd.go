package types

import (
	"fmt"
	"regexp"
	"time"
)

type YYYYMMDD struct {
	Year      int
	Month     int
	Day       int
	Separator string
}

func (ymd YYYYMMDD) String() string {
	return fmt.Sprintf("%d%s%02d%s%02d",
		ymd.Year,
		ymd.Separator,
		ymd.Month,
		ymd.Separator,
		ymd.Day)
}

func NewYYYYMMDD() YYYYMMDD {
	today := time.Now()
	return YYYYMMDD{
		Year:      today.Year(),
		Month:     int(today.Month()),
		Day:       today.Day(),
		Separator: "-",
	}
}

func (ymd YYYYMMDD) SetSeparator(sep string) YYYYMMDD {
	ymd.Separator = sep
	return ymd
}

func IsValidYYYYMMDD(ymd string) error {
	matched, err := regexp.Match(`\d{4}-\d{2}-\d{2}`, []byte(ymd))
	if err != nil {
		return err
	}
	if !matched {
		return fmt.Errorf("not in YYYY-MM-DD form")
	}
	return nil
}
