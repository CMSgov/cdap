package testsupport

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path"
	"strings"
	"testing"

	"go.uber.org/zap"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
)

type TestStorageLocation int

const (
	TestStorageHomeDirectory TestStorageLocation = iota
	TestStorageTempDirectory
)

const GlobalTestStorageLocation = TestStorageHomeDirectory

func SetupTestEnv(t *testing.T, location TestStorageLocation) {
	os.Setenv("x-api-key-log", "01234567890123456789012345678901234567890123456789")
	os.Setenv("x-api-key-admin", "abcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefgh")

	// Env vars
	var kv = []struct {
		key string
		val string
	}{
		{"ITSLOG_SERVE_HOST", "localhost"},
		{"ITSLOG_SERVE_PORT", "8888"},
		{"ITSLOG_APIKEY_PUPPERLOG", fmt.Sprintf(`{"app_id": "pupper", "key_id": "pup_logging", "permission": "log", "key": "%s"}`, os.Getenv("x-api-key-log"))},
		{"ITSLOG_APIKEY_PUPPERADMIN", fmt.Sprintf(`{"app_id": "pupper", "key_id": "pup_admin", "permission": "admin", "key": "%s"}`, os.Getenv("x-api-key-admin"))},
		{"ITSLOG_BUFFER_FLUSHWAITSEC", "1"},
		{"ITSLOG_BUFFER_LENGTH", "2000"},
		{"ITSLOG_GINMODE", "debug"},
		{"ITSLOG_ZAPMODE", "debug"},
		{"ITSLOG_PROXIES_TRUSTED", "TBD"},
		{"ITSLOG_EVENTUAL_CONSISTENCY_SECONDS", "5"},
		{"ITSLOG_INSTANCE_ID", "UNIT-TEST"},
	}
	for _, pair := range kv {
		os.Setenv(pair.key, pair.val)
	}
	os.Setenv("ITSLOG_GINMODE", "debug")
	os.Setenv("ITSLOG_ZAPMODE", "debug")

	// This has to happen after env setup in testing contexts
	switch location {
	case TestStorageTempDirectory:
		// WARNING
		// On the mac, this is a symlinked directory.
		// It may be a source of issues with creating/mounting/testing
		// DuckDB files. Or, normalizing the path. Either way, there are
		// tests that pass on a real disk, and fail on the symlinked directory...
		tmpDir := t.TempDir()
		os.Setenv("ITSLOG_STORAGE_PATH", path.Join(tmpDir, "data"))
		os.Setenv("ITSLOG_ARCHIVE_PATH", path.Join(tmpDir, "archive"))
	case TestStorageHomeDirectory:
		storage_path := path.Join(os.Getenv("HOME"), ".its-log", "unit-test", "data")
		archive_path := path.Join(os.Getenv("HOME"), ".its-log", "unit-test", "archive")
		os.Setenv("ITSLOG_STORAGE_PATH", storage_path)
		os.Setenv("ITSLOG_ARCHIVE_PATH", archive_path)
	default:
		panic("invalid test storage location")
	}
	// Load 'em up
	replacer := strings.NewReplacer(".", "_")
	viper.SetEnvKeyReplacer(replacer)
	viper.SetEnvPrefix("ITSLOG")
	viper.AutomaticEnv()

	err := os.MkdirAll(viper.GetString("storage.path"), 0755)
	if err != nil {
		t.Error("could not create storage directory for testing")
	}
	err = os.MkdirAll(viper.GetString("archive.path"), 0755)
	if err != nil {
		t.Error("could not create archive directory for testing")
	}

	// https://github.com/go-delve/delve/issues/4092
	// The global variable gets corrupted in testing, because it is collected.
	// Or... well, in the AuthMiddleware, base.LiveKeys is fine, but the accessor to key.Key
	// is not.
	err = base.GetApiKeys()
	if err != nil {
		t.Error("could not get api keys")
	}
	zap.L().Debug("found API keys", zap.Int("length", len(base.LiveKeys)))

}

func SetupTestRouter(t *testing.T, rsf func(types.ServeParams) *gin.Engine) *gin.Engine {
	engine := rsf(types.ServeParams{
		Mode: viper.GetString("ginmode"),
	})

	gin.SetMode(gin.TestMode)
	err := base.SetupValidators()
	if err != nil {
		zap.L().Error("validator setup failure", zap.Error(err))
		panic("could not setup json validators")
	}
	return engine
}

// This makes things quieter
// func TestMain(m *testing.M) {
// 	gin.SetMode(gin.TestMode)
// 	os.Exit(m.Run())
// }

func TestPost(t *testing.T,
	engine *gin.Engine,
	key string,
	path string,
	data any,
	expected int) ([]byte, *httptest.ResponseRecorder) {
	w := httptest.NewRecorder()
	req, err := http.NewRequest("POST", path, toReader(data))
	if err != nil {
		t.Error(err)
	}
	req.Header.Set("x-api-key", os.Getenv(fmt.Sprintf("x-api-key-%s", key)))
	engine.ServeHTTP(w, req)
	b, err := io.ReadAll(w.Result().Body)
	if err != nil {
		t.Error("could not read response body")
	}

	if w.Code != expected {
		t.Logf("mismatch: %d expected %d, %s %v", w.Code, expected, path, data)
		t.Logf("response: %s", string(b))
		t.Error(fmt.Errorf("status code expected=%d received=%d", expected, w.Code))
	}
	return b, w
}

func toReader(data any) *strings.Reader {
	body, _ := json.Marshal(data)
	content := strings.NewReader(string(body))
	return content
}
