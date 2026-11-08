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
	DailyConsolidation = iota
	WeeklyConsolidation
	MonthlyConsolidation
	FullConsolidation
)

type ConsolidationKind int

const (
	EventsConsolidation = iota
	SummaryConsolidation
)

type ConsolidationParams interface {
	GetApp() metabase.App
	GetKind() ConsolidationKind
	Validate() error
	Glob() string
}

type ConsolidationBase struct {
	Kind ConsolidationKind
}

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

func (p *DailyParams) GetKind() ConsolidationKind {
	return p.Kind
}

type WeeklyParams struct {
	ConsolidationBase
	App        metabase.App
	YearNumber int
	WeekNumber int
}

func (p *WeeklyParams) Validate() error {
	if p.WeekNumber < 1 || p.WeekNumber > 53 {
		msg := fmt.Sprintf("must provide valid week number (1-53), not %d", p.WeekNumber)
		return errors.New(msg)
	}

	currentYear := time.Now().Year()
	if p.YearNumber < 2000 || p.YearNumber > currentYear {
		msg := fmt.Sprintf("must provide valid year (2000-%d), not %d", currentYear, p.YearNumber)
		return errors.New(msg)
	}
	return nil
}

func (p *WeeklyParams) Glob() string {
	return filepath.Join(viper.GetString("archive.path"),
		fmt.Sprintf("%s_daily_*.%s",
			p.App.AppId,
			metabase.DUCKDB_EXTENSION,
		))
}

func (p *WeeklyParams) GetApp() metabase.App {
	return p.App
}

func (p *WeeklyParams) GetKind() ConsolidationKind {
	return p.Kind
}
