package storage

import (
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/types"
)

// We name things based on dates
func (s *Storage) YYYYMMDD() string {
	return s.ILTime.AsYYYYMMDD()
}

func (s *Storage) SetDateYMD(ymd string) error {
	switch ymd {
	case constants.TODAY:
		s.ILTime = types.NewILTimeToday()
		return nil
	case constants.YESTERDAY:
		s.ILTime = types.NewILTimeYesterday()
		return nil
	default:
		d, e := types.NewILTimeFromYMD(ymd)
		if e == nil {
			s.ILTime = d
		}
		return e
	}
}

func (s *Storage) SetDateILT(ilt *types.ILTime) {
	s.ILTime = ilt
}

func (s *Storage) SubtractDays(days int) {
	s.ILTime.SubtractDays(days)
}

func (s *Storage) AddDays(days int) {
	s.ILTime.AddDays(days)
}
