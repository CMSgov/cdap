package base

import "runtime"

func GetHeapMB() uint64 {

	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	startHeapMB := m.TotalAlloc / 1024 / 1024
	return startHeapMB
}
