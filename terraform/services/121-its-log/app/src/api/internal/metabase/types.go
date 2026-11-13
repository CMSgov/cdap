package metabase

import (
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/spf13/viper"
)

type EventsRow struct {
	Id       int64
	Inserted time.Time
	KeyId    string
	Cluster  sql.NullString
	Tags     any
	Data     any
}

type MetaType int

const (
	Instance MetaType = iota
	Daily
	Weekly
	Monthly
	Yearly
	Full
)

type MetaParams interface {
	GetApp() types.App
	Validate() error
	Glob() string
}

// Instance
type InstanceParams struct {
	App        types.App
	instanceId string
	YYYYMMDD   string
}

func (p *InstanceParams) Validate() error {
	return types.IsValidYYYYMMDD(p.YYYYMMDD)
}

func (p *InstanceParams) Glob() string {
	panic("instances are not globbed in their construction")
}

func (p *InstanceParams) GetApp() types.App {
	return p.App
}

// DAILY
type DailyParams struct {
	App      types.App
	YYYYMMDD string
}

func (p *DailyParams) Validate() error {
	return types.IsValidYYYYMMDD(p.YYYYMMDD)
}

func (p *DailyParams) Glob() string {
	return filepath.Join(viper.GetString("storage.path"), fmt.Sprintf("%s_instance_*_%s.%s",
		p.App.AppId,
		p.YYYYMMDD,
		DUCKDB_EXTENSION))
}

func (p *DailyParams) GetApp() types.App {
	return p.App
}

// MONTHLY
type MonthlyParams struct {
	App         types.App
	YearNumber  int
	MonthNumber int
}

func (p *MonthlyParams) Validate() error {
	if p.MonthNumber < 1 || p.MonthNumber > 12 {
		msg := fmt.Sprintf("must provide valid week number (1-12), not %d", p.MonthNumber)
		return errors.New(msg)
	}

	currentYear := time.Now().Year()
	if p.YearNumber < 2000 || p.YearNumber > currentYear {
		msg := fmt.Sprintf("must provide valid year (2000-%d), not %d", currentYear, p.YearNumber)
		return errors.New(msg)
	}
	return nil
}

func (p *MonthlyParams) Glob() string {
	// FIXME: to glob a week, we have to convert the year and week number
	// into a list of valid values, and glob them into the filename... elch.
	// Perhaps there are only `full` consolidations for a year and month?
	return filepath.Join(viper.GetString("archive.path"),
		fmt.Sprintf("%s_daily_%d-%02d-*.%s",
			p.App.AppId,
			p.YearNumber,
			p.MonthNumber,
			DUCKDB_EXTENSION,
		))
}

func (p *MonthlyParams) GetApp() types.App {
	return p.App
}

// YEARLY
type YearlyParams struct {
	App        types.App
	YearNumber int
}

func (p *YearlyParams) Validate() error {
	currentYear := time.Now().Year()
	if p.YearNumber < 2000 || p.YearNumber > currentYear {
		msg := fmt.Sprintf("must provide valid year (2000-%d), not %d", currentYear, p.YearNumber)
		return errors.New(msg)
	}
	return nil
}

func (p *YearlyParams) Glob() string {
	// FIXME: to glob a week, we have to convert the year and week number
	// into a list of valid values, and glob them into the filename... elch.
	// Perhaps there are only `full` consolidations for a year and month?
	return filepath.Join(viper.GetString("archive.path"),
		fmt.Sprintf("%s_daily_%d-*.%s",
			p.App.AppId,
			p.YearNumber,
			DUCKDB_EXTENSION,
		))
}

func (p *YearlyParams) GetApp() types.App {
	return p.App
}

// FULL

type FullParams struct {
	App types.App
}

func (p *FullParams) Validate() error {
	return nil
}

func (p *FullParams) Glob() string {
	// FIXME: to glob a week, we have to convert the year and week number
	// into a list of valid values, and glob them into the filename... elch.
	// Perhaps there are only `full` consolidations for a year and month?
	return filepath.Join(viper.GetString("archive.path"),
		fmt.Sprintf("%s_daily_*.%s",
			p.App.AppId,
			DUCKDB_EXTENSION,
		))
}

func (p *FullParams) GetApp() types.App {
	return p.App
}
