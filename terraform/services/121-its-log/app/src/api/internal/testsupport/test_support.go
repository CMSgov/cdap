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

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/types"
	"github.com/spf13/viper"
)

type TestStorageLocation int

const (
	TestStorageHomeDirectory TestStorageLocation = iota
	TestStorageTempDirectory
)

const GlobalTestStorageLocation = TestStorageTempDirectory

func SetupTestEnv(t *testing.T, location TestStorageLocation) {
	os.Setenv("x-api-key-log", "01234567890123456789012345678901234567890123456789")
	os.Setenv("x-api-key-admin", "abcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefgh")
	//tmpDir := t.TempDir()
	tmpDir := os.Getenv("HOME") + "/.its-log"
	os.Mkdir(path.Join(tmpDir, "data"), 0755)
	os.Mkdir(path.Join(tmpDir, "archive"), 0755)

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

	switch location {
	case TestStorageTempDirectory:
		os.Setenv("ITSLOG_STORAGE_PATH", path.Join(tmpDir, "data"))
		os.Setenv("ITSLOG_ARCHIVE_PATH", path.Join(tmpDir, "archive"))
	case TestStorageHomeDirectory:
		os.Setenv("ITSLOG_STORAGE_PATH", path.Join(os.Getenv("HOME"), ".its-log", "data"))
		os.Setenv("ITSLOG_ARCHIVE_PATH", path.Join(os.Getenv("HOME"), ".its-log", "archive"))
	default:
		panic("invalid test storage location")
	}

	// Load 'em up
	replacer := strings.NewReplacer(".", "_")
	viper.SetEnvKeyReplacer(replacer)
	viper.SetEnvPrefix("ITSLOG")
	viper.AutomaticEnv()

	// https://github.com/go-delve/delve/issues/4092
	// The global variable gets corrupted in testing, because it is collected.
	// Or... well, in the AuthMiddleware, base.LiveKeys is fine, but the accessor to key.Key
	// is not.
	err := base.GetApiKeys()
	if err != nil {
		t.Error("could not get api keys")
	}
	zap.L().Debug("found API keys", zap.Int("length", len(base.LiveKeys)))

}

func SetupTestRouter(t *testing.T, rsf func(types.ServeParams) *gin.Engine) *gin.Engine {
	//SetupTestEnv(t)

	engine := rsf(types.ServeParams{
		Mode: viper.GetString("ginmode"),
	})

	gin.SetMode(gin.TestMode)
	return engine
}

// This makes things quieter
// func TestMain(m *testing.M) {
// 	gin.SetMode(gin.TestMode)
// 	os.Exit(m.Run())
// }

func TestPost(t *testing.T, engine *gin.Engine, key string, path string, data any, expected int) ([]byte, *httptest.ResponseRecorder) {
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", path, toReader(data))
	req.Header.Set("x-api-key", os.Getenv(fmt.Sprintf("x-api-key-%s", key)))
	engine.ServeHTTP(w, req)
	if w.Code != expected {
		t.Logf("mismatch: %s %v", path, data)
	}
	b, err := io.ReadAll(w.Result().Body)
	if err != nil {
		t.Error("could not read response body")
	}
	return b, w
}

func toReader(data any) *strings.Reader {
	body, _ := json.Marshal(data)
	content := strings.NewReader(string(body))
	return content
}
