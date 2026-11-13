package endpoints

import (
	"net/http"
	"testing"
	"time"
	"uuid"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/testsupport"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/internal/types"
	"github.com/spf13/viper"
	testify "github.com/stretchr/testify/assert"
)

func TestCreateLog(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)
	engine := testsupport.SetupTestRouter(t, SetupRouter)
	b, w := testsupport.TestPost(t, engine, "log", "/v1/log/create", types.M{"tags": []string{"uno"}}, http.StatusOK)
	t.Log(string(b))
	testify.Equal(t, 200, w.Code)
	// Need to wait for the buffer to flush
	// if we want to see data in a database
	time.Sleep(time.Duration(viper.GetInt("buffer.flushwaitsec")+1) * time.Second)
}

func TestCreateManyLogs(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)
	engine := testsupport.SetupTestRouter(t, SetupRouter)
	for range 10000 {
		_, w := testsupport.TestPost(t, engine, "log", "/v1/log/create", types.M{"tags": []string{"many"}}, http.StatusOK)
		testify.Equal(t, 200, w.Code)
	}
	// Need to wait for the buffer to flush
	// if we want to see data in a database
	time.Sleep(time.Duration(viper.GetInt("buffer.flushwaitsec")+1) * time.Second)
}

func TestCreateWithClusters(t *testing.T) {
	testsupport.SetupTestEnv(t, testsupport.TestStorageHomeDirectory)
	engine := testsupport.SetupTestRouter(t, SetupRouter)
	firstCluster := uuid.New().String()
	secondCluster := uuid.New().String()
	for range 5 {
		body := types.M{
			"tags":    []string{"clustered"},
			"cluster": firstCluster,
		}
		_, w := testsupport.TestPost(t, engine, "log", "/v1/log/create", body, http.StatusOK)
		testify.Equal(t, 200, w.Code)
	}
	for i := range 5 {
		body := types.M{
			"tags":    []string{"data'd"},
			"cluster": secondCluster,
			"data":    types.M{"number": i},
		}
		_, w := testsupport.TestPost(t, engine, "log", "/v1/log/create", body, http.StatusOK)
		testify.Equal(t, 200, w.Code)
	}
	// Need to wait for the buffer to flush
	// if we want to see data in a database
	time.Sleep(time.Duration(viper.GetInt("buffer.flushwaitsec")+1) * time.Second)
}
