package endpoints

import (
	"net/http"
	"slices"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/base"
	"github.com/navapbc/its-log/internal/constants"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// its-log is intended to be used by a single application.
// For local testing, set `api_key` in the config file.
// For production deployments, set `ITSLOG_API_KEY` to a
// random value at least 48 bytes long. This is intended to be
// a shared, symmetric key between the client and its-log.
//
// python -c 'import secrets ; print(secrets.token_urlsafe(48))'
//
// or
//
// openssl rand -base64 48
//
// would likely do the trick.
//
// This middleware sets the AppId for use downstream

func AuthMiddleWare(permissions []types.PermissionType) gin.HandlerFunc {
	return func(c *gin.Context) {
		api_key := c.GetHeader("x-api-key")
		for _, key := range base.LiveKeys {
			// If this is a valid API key, do more checks.
			if api_key == key.Key {
				keylen := len(api_key)
				doesContain := slices.Contains(permissions, key.Permission)
				// Log if (somehow) a valid API key fails to meet these constraints.
				if !doesContain {
					zap.L().Error("key lacks permissions",
						zap.String("app_id", key.AppId),
						zap.String("key_id", key.KeyId))
				} else if keylen < constants.MINIMUM_API_KEY_LENGTH {
					zap.L().Error("key too short",
						zap.String("app_id", key.AppId),
						zap.String("key_id", key.KeyId))
				} else {
					zap.L().Debug("Found key", zap.String("key_id", key.KeyId))
					c.Set(constants.ITSLOG_KEYID, key.KeyId)
					c.Set(constants.ITSLOG_APPID, key.AppId)
					return
				}
			}
		}
		// Otherwise, fail.
		// This is a very quiet failure for the client.
		// It sends a 401 with no explanation.
		c.AbortWithStatus(http.StatusUnauthorized)
	}
}
