// SECURITY STRATEGY — certificate and key material handling:
//
// The following values should NEVER appear in log output, error messages,
// or any other observable output under any circumstances:
//
//   - Private key bytes (encrypted or plaintext)
//   - Passphrase / key encryption material
//   - out.PrivateKey from ACM ExportCertificate
//   - plaintextKey after decryption
//   - Any []byte containing PEM-encoded key material
//
// Safe to log:
//   - File paths (cert=, key=, ca=)
//   - PEM block type strings ("ENCRYPTED PRIVATE KEY" etc.)
//   - Operation success/failure status
//   - Certificate ARN (already redacted in error messages)

package acm

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/acm"
	"github.com/youmark/pkcs8"
)

// CertPaths gathers file paths where fetched certs are written
type CertPaths struct {
	CertFile string
	KeyFile  string
	CAFile   string
}

// Client wraps the ACM SDK client
type Client struct {
	certARN string
	paths   CertPaths
	acm     *acm.Client
}

// New creates a new AWS ACM client using the local role permissions
func New(ctx context.Context, certARN string, paths CertPaths) (*Client, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("loading AWS config: %w", err)
	}
	return &Client{
		certARN: certARN,
		paths:   paths,
		acm:     acm.NewFromConfig(cfg),
	}, nil
}

// generatePassphrase generates a random printable passphrase.
// A fresh passphrase is used on every export — ACM generates a new
// encrypted copy each time so passphrases are never reused.
// SECURITY: must never be logged.
func generatePassphrase() ([]byte, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, fmt.Errorf("generating passphrase: %w", err)
	}
	return []byte(hex.EncodeToString(b)), nil
}

// decryptPrivateKey decrypts the private key returned by ACM ExportCertificate.
// ACM returns PKCS#8 encrypted keys ("ENCRYPTED PRIVATE KEY" PEM block type).
// Decryption happens entirely in memory — the passphrase never touches disk.
// SECURITY: encryptedPEM and passphrase must never be logged.
func decryptPrivateKey(encryptedPEM []byte, passphrase []byte) ([]byte, error) {
	block, _ := pem.Decode(encryptedPEM)
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block from private key")
	}

	// Safe to log — block type contains no key material
	log.Printf("private key PEM block type: %q", block.Type)

	switch block.Type {
	case "ENCRYPTED PRIVATE KEY":
		// ACM ExportCertificate returns PKCS#8 encrypted keys.
		// youmark/pkcs8 handles PBES2+PBKDF2 decryption correctly
		// regardless of the specific parameters ACM chose.
		key, err := pkcs8.ParsePKCS8PrivateKey(block.Bytes, passphrase)
		if err != nil {
			// SECURITY: do not wrap err with any key material context
			return nil, fmt.Errorf("failed to decrypt PKCS#8 private key: %w", err)
		}

		// Marshal back to plaintext PKCS#8 DER
		der, err := x509.MarshalPKCS8PrivateKey(key)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal private key to DER: %w", err)
		}

		plaintext := pem.EncodeToMemory(&pem.Block{
			Type:  "PRIVATE KEY",
			Bytes: der,
		})
		if plaintext == nil {
			return nil, fmt.Errorf("failed to encode plaintext private key to PEM")
		}
		return plaintext, nil

	case "RSA PRIVATE KEY":
		// PKCS#1 — may be encrypted with DEK-Info headers or already plaintext
		if x509.IsEncryptedPEMBlock(block) {
			decryptedDER, err := x509.DecryptPEMBlock(block, passphrase)
			if err != nil {
				return nil, fmt.Errorf("failed to decrypt PKCS#1 private key: %w", err)
			}
			return pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PRIVATE KEY",
				Bytes: decryptedDER,
			}), nil
		}
		// Already plaintext
		return encryptedPEM, nil

	case "PRIVATE KEY":
		// Already plaintext PKCS#8 — verify it parses before returning
		if _, err := x509.ParsePKCS8PrivateKey(block.Bytes); err != nil {
			return nil, fmt.Errorf("failed to parse plaintext PKCS#8 key: %w", err)
		}
		return encryptedPEM, nil

	default:
		return nil, fmt.Errorf("unrecognised PEM block type: %q", block.Type)
	}
}

// FetchAndStore exports the cert from ACM, decrypts the private key
// entirely in memory, and writes plaintext PEM files to disk.
// SECURITY: the passphrase and encrypted key material never touch disk.
func (c *Client) FetchAndStore(ctx context.Context) error {
	passphrase, err := generatePassphrase()
	if err != nil {
		return fmt.Errorf("generating passphrase: %w", err)
	}
	// SECURITY: passphrase must never be logged

	out, err := c.acm.ExportCertificate(ctx, &acm.ExportCertificateInput{
		CertificateArn: &c.certARN,
		Passphrase:     passphrase,
	})
	if err != nil {
		// SECURITY: never log err response body — may contain cert material
		return fmt.Errorf("failed to export certificate from ACM (arn redacted): %w", err)
	}
	// SECURITY: out.Certificate, out.PrivateKey, out.CertificateChain
	// must never be logged under any circumstances

	plaintextKey, err := decryptPrivateKey([]byte(*out.PrivateKey), passphrase)
	if err != nil {
		return fmt.Errorf("decrypting private key: %w", err)
	}
	// SECURITY: plaintextKey must never be logged

	// Verify cert and key match before writing anything to disk
	// tls.X509KeyPair error messages do not include key material
	if _, err := tls.X509KeyPair([]byte(*out.Certificate), plaintextKey); err != nil {
		return fmt.Errorf("cert/key pair verification failed: %w", err)
	}

	if err := writeFile(c.paths.CertFile, []byte(*out.Certificate)); err != nil {
		return fmt.Errorf("writing cert file: %w", err)
	}
	if err := writeFile(c.paths.KeyFile, plaintextKey); err != nil {
		return fmt.Errorf("writing key file: %w", err)
	}
	if err := writeFile(c.paths.CAFile, []byte(*out.CertificateChain)); err != nil {
		return fmt.Errorf("writing CA file: %w", err)
	}

	// SECURITY: only log file paths — never log file contents
	log.Printf("certificates written to disk: cert=%s key=%s ca=%s",
		c.paths.CertFile, c.paths.KeyFile, c.paths.CAFile)

	return nil
}

func writeFile(path string, data []byte) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.Write(data)
	return err
}

// LoadCertificate loads a cert/key pair from disk
func LoadCertificate(certFile, keyFile string) (*tls.Certificate, error) {
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("loading cert/key pair: %w", err)
	}
	return &cert, nil
}

// DecodePEM decodes the first PEM block from data
func DecodePEM(data []byte) (*pem.Block, error) {
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}
	return block, nil
}