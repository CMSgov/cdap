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

// generatePassphrase generates a random printable passphrase
func generatePassphrase() ([]byte, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, fmt.Errorf("generating passphrase: %w", err)
	}
	return []byte(hex.EncodeToString(b)), nil
}

// decryptPrivateKey decrypts the private key returned by ACM ExportCertificate.
// Logs the PEM block type to help identify the correct decryption path.
func decryptPrivateKey(encryptedPEM []byte, passphrase []byte) ([]byte, error) {
	block, _ := pem.Decode(encryptedPEM)
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block from private key")
	}

	// DEBUG — log block type and headers so we know exactly what ACM returned
	// Remove this log once decryption is confirmed working
	log.Printf("DEBUG private key PEM block type: %q headers: %v", block.Type, block.Headers)

	switch block.Type {
	case "ENCRYPTED PRIVATE KEY":
		// PKCS#8 encrypted — ACM ExportCertificate typically returns this format
		// We need an external package to handle this — log and return error for now
		// so we can confirm the block type before adding the right dependency
		return nil, fmt.Errorf(
			"PKCS#8 encrypted key detected (block type: %q) — needs pkcs8 decryption",
			block.Type,
		)

	case "RSA PRIVATE KEY":
		// PKCS#1 — may be encrypted with DEK-Info headers or plaintext
		if len(block.Headers) > 0 {
			// Old-style PEM encryption with DEK-Info — use x509.DecryptPEMBlock
			decryptedDER, err := x509.DecryptPEMBlock(block, passphrase)
			if err != nil {
				return nil, fmt.Errorf("failed to decrypt PKCS#1 private key: %w", err)
			}
			plaintext := pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PRIVATE KEY",
				Bytes: decryptedDER,
			})
			if plaintext == nil {
				return nil, fmt.Errorf("failed to encode decrypted RSA private key to PEM")
			}
			return plaintext, nil
		}
		// Already plaintext — return as-is
		log.Printf("DEBUG private key is plaintext PKCS#1 RSA — no decryption needed")
		return encryptedPEM, nil

	case "PRIVATE KEY":
		// PKCS#8 plaintext — no decryption needed
		log.Printf("DEBUG private key is plaintext PKCS#8 — no decryption needed")
		return encryptedPEM, nil

	default:
		return nil, fmt.Errorf("unrecognised PEM block type: %q", block.Type)
	}
}

// FetchAndStore exports the cert from ACM and writes it to disk
func (c *Client) FetchAndStore(ctx context.Context) error {
	passphrase, err := generatePassphrase()
	if err != nil {
		return fmt.Errorf("generating passphrase: %w", err)
	}

	out, err := c.acm.ExportCertificate(ctx, &acm.ExportCertificateInput{
		CertificateArn: &c.certARN,
		Passphrase:     passphrase,
	})
	if err != nil {
		return fmt.Errorf("failed to export certificate from ACM (arn redacted): %w", err)
	}

	plaintextKey, err := decryptPrivateKey([]byte(*out.PrivateKey), passphrase)
	if err != nil {
		return fmt.Errorf("decrypting private key: %w", err)
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
