package types

import (
	"errors"
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

func NewYYYYMMDDFromDate(ymd string) (YYYYMMDD, error) {
	t, err := time.Parse("2006-01-02", ymd)
	if err != nil {
		return NewYYYYMMDD(), err
	}
	y := YYYYMMDD{
		Year:      t.Year(),
		Month:     int(t.Month()),
		Day:       t.Day(),
		Separator: "-",
	}
	return y, nil
}

func (ymd YYYYMMDD) AsTime() (time.Time, error) {
	t, err := time.Parse("2006-01-02", ymd.String())
	if err != nil {
		return time.Now(), err
	}
	return t, nil
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

func TrimToYYYYMMDD(ymd string) (string, error) {
	if IsValidYYYYMMDD(ymd) != nil {
		return ymd, IsValidYYYYMMDD(ymd)
	}
	re := regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
	match := re.FindStringSubmatch(ymd)
	if len(match) > 0 {
		return match[0], nil
	} else {
		return ymd, errors.New("no match found when trimming YYYY-MM-DD")
	}
}
