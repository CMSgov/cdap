package storage

import "github.com/navapbc/its-log/internal/types"

// We name things based on dates
func (s *Storage) YYYYMMDD() string {
	return s.ILTime.AsYYYYMMDD()
}

func (s *Storage) SetDateYMD(ymd string) error {
	if ymd == "today" {
		s.ILTime = types.NewILTimeToday()
		return nil
	}
	d, e := types.NewILTimeFromYMD(ymd)
	if e == nil {
		s.ILTime = d
	}
	return e
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
