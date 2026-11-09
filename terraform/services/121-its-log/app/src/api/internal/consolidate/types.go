package consolidate

import (
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/navapbc/its-log/internal/metabase"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
)

type ConsolidationType int

const (
	DailyConsolidation ConsolidationType = iota
	WeeklyConsolidation
	MonthlyConsolidation
	FullConsolidation
)

type ConsolidationParams interface {
	GetApp() metabase.App
	Validate() error
	Glob() string
}

type ConsolidationBase struct{}

// DAILY
type DailyParams struct {
	ConsolidationBase
	App      metabase.App
	YYYYMMDD string
}

func (p *DailyParams) Validate() error {
	return types.IsValidYYYYMMDD(p.YYYYMMDD)
}

func (p *DailyParams) Glob() string {
	return filepath.Join(viper.GetString("storage.path"), fmt.Sprintf("%s_instance_*_%s.%s",
		p.App.AppId,
		p.YYYYMMDD,
		metabase.DUCKDB_EXTENSION))
}

func (p *DailyParams) GetApp() metabase.App {
	return p.App
}

// MONTHLY
type MonthlyParams struct {
	ConsolidationBase
	App         metabase.App
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
			metabase.DUCKDB_EXTENSION,
		))
}

func (p *MonthlyParams) GetApp() metabase.App {
	return p.App
}

// YEARLY
type YearlyParams struct {
	ConsolidationBase
	App        metabase.App
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
			metabase.DUCKDB_EXTENSION,
		))
}

func (p *YearlyParams) GetApp() metabase.App {
	return p.App
}

// FULL

type FullParams struct {
	ConsolidationBase
	App metabase.App
}

func (p *FullParams) Validate() error {
	return nil
}

func (p *FullParams) Glob() string {
	// FIXME: to glob a week, we have to convert the year and week number
	// into a list of valid values, and glob them into the filename... elch.
	// Perhaps there are only `full` consolidations for a year and month?
	return filepath.Join(viper.GetString("archive.path"),
		fmt.Sprintf("%s_daily_%d-*.%s",
			p.App.AppId,
			metabase.DUCKDB_EXTENSION,
		))
}

func (p *FullParams) GetApp() metabase.App {
	return p.App
}
