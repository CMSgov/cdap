package base

import (
	"os"
	"strings"
	"testing"

	"go.uber.org/zap/zapcore"
)

func TestConfirmEnvVars(t *testing.T) {
	// Confirm all vars we expect present, are present
	for _, variable := range minimum {
		t.Setenv(variable, "test value")
	}
	if ConfirmEnvVars() != nil {
		t.Error("all env vars not present")
	}

}

func TestMissingEnvVar(t *testing.T) {
	os.Clearenv()
	for _, variable := range minimum[:len(minimum)-1] {
		t.Setenv(variable, "test value")
	}
	if ConfirmEnvVars() == nil {
		t.Error("missing an env var")
	}

}

func TestConfirmApiKeyMapKeys(t *testing.T) {
	sampleApp := make(map[string]string, 0)

	sampleApp["app_id"] = "test_id"
	sampleApp["key_id"] = "abcd"
	sampleApp["permission"] = "admin"
	sampleApp["key"] = "xyz123"

	if ConfirmApiKeyMapKeys("raw_json", sampleApp) != nil {
		t.Error("good sample app incorrectly denied")
	}

	// Force a failure
	delete(sampleApp, "app_id")

	if ConfirmApiKeyMapKeys("raw_json", sampleApp) == nil {
		t.Error("bad sample app incorrectly approved")
	}

	// Set a bad map key
	sampleApp["app_id"] = "the_doctor"
	sampleApp["bad_key"] = "bad_wolf"

	if ConfirmApiKeyMapKeys("raw_json", sampleApp) == nil {
		t.Error("sample app has an extra/bad key")
	}

}

func TestGetApiKeysNoKeys(t *testing.T) {
	// Clear the env vars first
	os.Clearenv()

	if GetApiKeys() == nil {
		t.Error("should fail with no keys")
	}
}

// '{"app_id": "the_app", "key_id": "uniq", "permission": "log", "key": "32-byte-string"}'
func TestGetApiKeys(t *testing.T) {
	os.Clearenv()

	t.Setenv("ITSLOG_APIKEY_TESTING", `{"app_id": "the_app", "key_id": "uniq", "permission": "log", "key": "32-byte-string32-byte-string32-byte-string32-byte-string"}`)
	if GetApiKeys() != nil {
		t.Error("could not find a key")
	}
}

func TestGetApiKeysBadJson(t *testing.T) {
	os.Clearenv()

	t.Setenv("ITSLOG_APIKEY_TESTING", `{"app_id": the_app", "key_id": "uniq", "permission": "log", "key": "32-byte-string32-byte-string32-byte-string32-byte-string"}`)
	if GetApiKeys() != nil {
		t.Error("JSON failed to parse")
	}
}

func TestGetKeyBundle(t *testing.T) {
	os.Clearenv()

	t.Setenv("ITSLOG_APIKEY_TESTING", `{"app_id": "the_app", "key_id": "uniq", "permission": "log", "key": "32-byte-string32-byte-string32-byte-string32-byte-string"}`)
	if GetApiKeys() != nil {
		t.Error("could not find a key")
	}

	// Now, the stateful variable LiveKeys is loaded with one key.
	key, err := GetKeyBundle("the_app", "uniq")
	if err != nil {
		t.Error("error retrieving key bundle")
	}

	if key.AppId != "the_app" {
		t.Error("key bundle came back malformed")
	}
}

func TestGetKeyBundleFailure(t *testing.T) {
	os.Clearenv()

	t.Setenv("ITSLOG_APIKEY_TESTING", `{"app_id": "the_app", "key_id": "uniq", "permission": "log", "key": "32-byte-string"}`)
	if GetApiKeys() != nil {
		t.Error("could not find a key")
	}

	// Now, the stateful variable LiveKeys is loaded with one key.
	_, err := GetKeyBundle("bogo_id", "uniq")
	if err != nil {
		if !strings.Contains("not find", err.Error()) {
			t.Error("did not throw error with bad app id")
		}
	}
}

func TestConfigureLoggers(t *testing.T) {
	debugLogger := ConfigureLoggers("debug")
	if debugLogger.Level() != zapcore.DebugLevel {
		t.Error("logger not configured for debug")
	}
	prodLogger := ConfigureLoggers("production")
	if prodLogger.Level() != zapcore.InfoLevel {
		t.Error("logger not configured for production")
	}

}
