package cmd

import (
	"fmt"
	"log"
	"math/rand/v2"
	"os"

	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/endpoints"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/base"
	"github.com/CMSgov/cdap/terraform/services/121-its-log/app/src/api/internal/types"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

// serveCmd represents the serve command
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Serve the its-log API",
	Long: `Serve the its-log API
This takes no parameters; all configuration is provided
via the application's 'config.yaml'.
`,
	Run: serve_cmd,
}

func serve_cmd(cmd *cobra.Command, args []string) {

	// This will panic if we don't have the tools we need.
	err := base.ConfirmEnvVars()
	if err != nil {
		log.Println(err.Error())
		os.Exit(-1)
	}

	defer base.ConfigureLoggers(viper.GetString("zapmode")).Sync()

	// Load the API keys from the environment
	err = base.GetApiKeys()
	zap.L().Debug("found API keys", zap.Int("length", len(base.LiveKeys)))
	if err != nil {
		zap.L().Error(err.Error())
		os.Exit(-2)
	}

	zap.L().Info("storage path", zap.String("storage.path", viper.GetString("storage.path")))
	zap.L().Info("archive path", zap.String("archive.path", viper.GetString("archive.path")))
	// Randomize the instance if we are debugging, and it is the right shape.
	// If there is no instance ID, we need to grab it from the env.
	// This has a particular shape in Fargate.
	if len(viper.GetString("instance.id")) > 0 {
		// Leave it.
	} else if viper.GetString("ginmode") == "debug" {
		id := fmt.Sprintf("DEBUG-INSTANCE-%d", rand.IntN(64))
		viper.Set("instance.id", id)
	} else {
		if len(os.Getenv("ECS_CONTAINER_METADATA_URI_V4")) > 0 {
			// FIXME
			// curl -s "${ECS_CONTAINER_METADATA_URI_V4}/task" | jq -r '.TaskARN' | awk -F/ '{print $NF}'
			viper.Set("instance.id", fmt.Sprintf("%s-%d",
				"aws-instance-", rand.IntN(64)))
		} else {
			// We're local
			viper.Set("instance.id", fmt.Sprintf("%s-%d",
				os.Getenv("HOSTNAME"), rand.IntN(64)))
		}
	}
	zap.L().Info("instance id", zap.String("instance.id", viper.GetString("instance.id")))

	// FIXME: Need CTRL-C/OS signal handling
	endpoints.Serve(types.ServeParams{
		Mode: viper.GetString("ginmode"),
	})

}

func init() {
	rootCmd.AddCommand(serveCmd)
}
