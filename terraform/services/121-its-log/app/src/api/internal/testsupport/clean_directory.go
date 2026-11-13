package testsupport

import (
	"os"
	"path"
	"strings"

	"github.com/spf13/viper"
	"go.uber.org/zap"
)

func CleanupTestDirectory(viperTag string, pattern string) error {
	dir := viper.GetString(viperTag)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if strings.Contains(e.Name(), pattern) {
			err := os.Remove(path.Join(dir, e.Name()))
			if err != nil {
				return err
			}
			zap.L().Debug("cleaned up file", zap.String("name", e.Name()))
		}
	}
	return nil
}
