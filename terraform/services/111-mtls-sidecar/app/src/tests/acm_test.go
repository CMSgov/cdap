package tests

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/youmark/pkcs8"
)

func TestGeneratePassphrase(t *testing.T) {
	p1, err := generatePassphrase()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(p1) == 0 {
		t.Fatal("expected non-empty passphrase")
	}

	p2, err := generatePassphrase()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if string(p1) == string(p2) {
		t.Error("expected two calls to generate different passphrases")
	}
}

func TestDecryptPrivateKey_PKCS8Encrypted(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}

	passphrase := []byte("test-passphrase-123")

	der, err := pkcs8.MarshalPrivateKey(key, passphrase, nil)
	if err != nil {
		t.Fatalf("marshaling encrypted PKCS8 key: %v", err)
	}
	encryptedPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "ENCRYPTED PRIVATE KEY",
		Bytes: der,
	})

	plaintext, err := decryptPrivateKey(encryptedPEM, passphrase)
	if err != nil {
		t.Fatalf("decryptPrivateKey returned error: %v", err)
	}

	block, _ := pem.Decode(plaintext)
	if block == nil {
		t.Fatal("expected valid PEM block in decrypted output")
	}
	if block.Type != "PRIVATE KEY" {
		t.Errorf("expected PRIVATE KEY block type, got %q", block.Type)
	}

	// confirm the decrypted key actually parses and matches the original
	parsedKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		t.Fatalf("parsing decrypted key: %v", err)
	}
	rsaKey, ok := parsedKey.(*rsa.PrivateKey)
	if !ok {
		t.Fatal("expected *rsa.PrivateKey")
	}
	if rsaKey.N.Cmp(key.N) != 0 {
		t.Error("decrypted key does not match original key")
	}
}

func TestDecryptPrivateKey_WrongPassphrase(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}

	der, err := pkcs8.MarshalPrivateKey(key, []byte("correct-passphrase"), nil)
	if err != nil {
		t.Fatalf("marshaling encrypted PKCS8 key: %v", err)
	}
	encryptedPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "ENCRYPTED PRIVATE KEY",
		Bytes: der,
	})

	_, err = decryptPrivateKey(encryptedPEM, []byte("wrong-passphrase"))
	if err == nil {
		t.Error("expected error when decrypting with wrong passphrase, got nil")
	}
}

func TestDecryptPrivateKey_PlaintextPKCS8(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}

	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("marshaling plaintext PKCS8 key: %v", err)
	}
	plaintextPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: der,
	})

	result, err := decryptPrivateKey(plaintextPEM, nil)
	if err != nil {
		t.Fatalf("unexpected error for already-plaintext key: %v", err)
	}
	if string(result) != string(plaintextPEM) {
		t.Error("expected plaintext key to be returned unchanged")
	}
}

func TestDecryptPrivateKey_PKCS1Encrypted(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}

	der := x509.MarshalPKCS1PrivateKey(key)
	passphrase := []byte("test-passphrase")

	// x509.EncryptPEMBlock is deprecated but legacy tooling may still
	// produce DEK-Info encrypted PKCS1 blocks — test the fallback path
	block, err := x509.EncryptPEMBlock(rand.Reader, "RSA PRIVATE KEY", der, passphrase, x509.PEMCipherAES256) //nolint:staticcheck
	if err != nil {
		t.Fatalf("encrypting PKCS1 block: %v", err)
	}
	encryptedPEM := pem.EncodeToMemory(block)

	plaintext, err := decryptPrivateKey(encryptedPEM, passphrase)
	if err != nil {
		t.Fatalf("decryptPrivateKey returned error: %v", err)
	}

	decodedBlock, _ := pem.Decode(plaintext)
	if decodedBlock == nil || decodedBlock.Type != "RSA PRIVATE KEY" {
		t.Fatal("expected decrypted RSA PRIVATE KEY block")
	}
}

func TestDecryptPrivateKey_UnrecognizedBlockType(t *testing.T) {
	badPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "SOMETHING ELSE",
		Bytes: []byte("not a real key"),
	})

	_, err := decryptPrivateKey(badPEM, []byte("irrelevant"))
	if err == nil {
		t.Error("expected error for unrecognized PEM block type, got nil")
	}
}

func TestDecryptPrivateKey_InvalidPEM(t *testing.T) {
	_, err := decryptPrivateKey([]byte("not pem at all"), []byte("irrelevant"))
	if err == nil {
		t.Error("expected error for invalid PEM input, got nil")
	}
}

func TestWriteFile(t *testing.T) {
	dir := t.TempDir()
	path := dir + "/test-output.pem"

	data := []byte("test file contents")
	if err := writeFile(path, data); err != nil {
		t.Fatalf("writeFile returned error: %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat on written file failed: %v", err)
	}
	if info.Mode().Perm() != 0600 {
		t.Errorf("expected file mode 0600, got %v", info.Mode().Perm())
	}

	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading written file: %v", err)
	}
	if string(got) != string(data) {
		t.Errorf("expected %q, got %q", data, got)
	}
}

func TestWriteFile_InvalidPath(t *testing.T) {
	err := writeFile("/nonexistent-dir-xyz/file.pem", []byte("data"))
	if err == nil {
		t.Error("expected error writing to nonexistent directory, got nil")
	}
}

func TestLoadCertificate(t *testing.T) {
	certPEM, keyPEM := generateSelfSignedCertForTest(t)

	dir := t.TempDir()
	certFile := dir + "/cert.pem"
	keyFile := dir + "/key.pem"

	if err := os.WriteFile(certFile, certPEM, 0600); err != nil {
		t.Fatalf("writing cert file: %v", err)
	}
	if err := os.WriteFile(keyFile, keyPEM, 0600); err != nil {
		t.Fatalf("writing key file: %v", err)
	}

	cert, err := LoadCertificate(certFile, keyFile)
	if err != nil {
		t.Fatalf("LoadCertificate returned error: %v", err)
	}
	if cert == nil {
		t.Fatal("expected non-nil certificate")
	}
}

func TestLoadCertificate_MissingFiles(t *testing.T) {
	_, err := LoadCertificate("/nonexistent/cert.pem", "/nonexistent/key.pem")
	if err == nil {
		t.Error("expected error for missing cert/key files, got nil")
	}
}

func TestDecodePEM(t *testing.T) {
	certPEM, _ := generateSelfSignedCertForTest(t)

	block, err := DecodePEM(certPEM)
	if err != nil {
		t.Fatalf("DecodePEM returned error: %v", err)
	}
	if block.Type != "CERTIFICATE" {
		t.Errorf("expected CERTIFICATE block, got %q", block.Type)
	}
}

func TestDecodePEM_Invalid(t *testing.T) {
	_, err := DecodePEM([]byte("not valid pem"))
	if err == nil {
		t.Error("expected error for invalid PEM, got nil")
	}
}

// helper — generates a minimal self-signed cert/key pair for
// LoadCertificate/DecodePEM tests. Kept local to this file since
// certgen_test.go's helpers live in the external `tests` package
// and aren't importable from here.
func generateSelfSignedCertForTest(t *testing.T) (certPEM, keyPEM []byte) {
	t.Helper()

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}

	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "test"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}

	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("creating certificate: %v", err)
	}

	certPEM = pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	keyPEM = pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	return certPEM, keyPEM
}
