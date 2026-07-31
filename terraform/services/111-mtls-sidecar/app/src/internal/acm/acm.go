package acm

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/asn1"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/acm"
	"golang.org/x/crypto/pbkdf2"
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

// ASN.1 structures for PKCS#8 encrypted private key (RFC 5958)
type encryptedPrivateKeyInfo struct {
	EncryptionAlgorithm encryptionAlgorithmIdentifier
	EncryptedData       []byte
}

type encryptionAlgorithmIdentifier struct {
	Algorithm  asn1.ObjectIdentifier
	Parameters asn1.RawValue
}

// PBES2 parameters (RFC 8018)
type pbes2Params struct {
	KeyDerivationFunc algorithmIdentifierWithParams
	EncryptionScheme  algorithmIdentifierWithParams
}

type algorithmIdentifierWithParams struct {
	Algorithm  asn1.ObjectIdentifier
	Parameters asn1.RawValue
}

// PBKDF2 parameters
type pbkdf2Params struct {
	Salt           []byte
	IterationCount int
	PRF            algorithmIdentifierWithParams `asn1:"optional"`
}

// AES-CBC parameters (just an IV)
type aesCBCParams struct {
	IV []byte
}

// OIDs we need
var (
	oidPBES2        = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 5, 13}
	oidPBKDF2       = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 5, 12}
	oidAES256CBC    = asn1.ObjectIdentifier{2, 16, 840, 1, 101, 3, 4, 1, 42}
	oidAES128CBC    = asn1.ObjectIdentifier{2, 16, 840, 1, 101, 3, 4, 1, 2}
	oidHMACSHA256   = asn1.ObjectIdentifier{1, 2, 840, 113549, 2, 9}
)

// decryptPrivateKey decrypts an ENCRYPTED PRIVATE KEY PEM block
// as returned by ACM ExportCertificate using pure standard library
func decryptPrivateKey(encryptedPEM []byte, passphrase []byte) ([]byte, error) {
	block, _ := pem.Decode(encryptedPEM)
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block from private key")
	}

	log.Printf("private key PEM block type: %q", block.Type)

	switch block.Type {
	case "PRIVATE KEY":
		// Already plaintext PKCS#8 — no decryption needed
		return encryptedPEM, nil

	case "RSA PRIVATE KEY":
		if len(block.Headers) > 0 {
			// PKCS#1 encrypted with DEK-Info
			decryptedDER, err := x509.DecryptPEMBlock(block, passphrase)
			if err != nil {
				return nil, fmt.Errorf("failed to decrypt PKCS#1 key: %w", err)
			}
			return pem.EncodeToMemory(&pem.Block{
				Type:  "RSA PRIVATE KEY",
				Bytes: decryptedDER,
			}), nil
		}
		return encryptedPEM, nil

	case "ENCRYPTED PRIVATE KEY":
		// PKCS#8 encrypted — decrypt manually via ASN.1
		der, err := decryptPKCS8(block.Bytes, passphrase)
		if err != nil {
			return nil, fmt.Errorf("failed to decrypt PKCS#8 key: %w", err)
		}

		plaintext := pem.EncodeToMemory(&pem.Block{
			Type:  "PRIVATE KEY",
			Bytes: der,
		})
		if plaintext == nil {
			return nil, fmt.Errorf("failed to encode plaintext key to PEM")
		}
		return plaintext, nil

	default:
		return nil, fmt.Errorf("unrecognised PEM block type: %q", block.Type)
	}
}

// decryptPKCS8 decrypts a PKCS#8 EncryptedPrivateKeyInfo DER blob
// using PBES2 + PBKDF2 + AES-CBC as used by ACM ExportCertificate
func decryptPKCS8(der []byte, passphrase []byte) ([]byte, error) {
	var epki encryptedPrivateKeyInfo
	if _, err := asn1.Unmarshal(der, &epki); err != nil {
		return nil, fmt.Errorf("failed to unmarshal EncryptedPrivateKeyInfo: %w", err)
	}

	if !epki.EncryptionAlgorithm.Algorithm.Equal(oidPBES2) {
		return nil, fmt.Errorf("unsupported encryption algorithm: %v", epki.EncryptionAlgorithm.Algorithm)
	}

	// Parse PBES2 parameters
	var pbes2 pbes2Params
	if _, err := asn1.Unmarshal(epki.EncryptionAlgorithm.Parameters.FullBytes, &pbes2); err != nil {
		return nil, fmt.Errorf("failed to unmarshal PBES2 params: %w", err)
	}

	if !pbes2.KeyDerivationFunc.Algorithm.Equal(oidPBKDF2) {
		return nil, fmt.Errorf("unsupported KDF: %v", pbes2.KeyDerivationFunc.Algorithm)
	}

	// Parse PBKDF2 parameters
	var kdfParams pbkdf2Params
	if _, err := asn1.Unmarshal(pbes2.KeyDerivationFunc.Parameters.FullBytes, &kdfParams); err != nil {
		return nil, fmt.Errorf("failed to unmarshal PBKDF2 params: %w", err)
	}

	// Determine key size from encryption scheme
	var keyLen int
	switch {
	case pbes2.EncryptionScheme.Algorithm.Equal(oidAES256CBC):
		keyLen = 32
	case pbes2.EncryptionScheme.Algorithm.Equal(oidAES128CBC):
		keyLen = 16
	default:
		return nil, fmt.Errorf("unsupported encryption scheme: %v", pbes2.EncryptionScheme.Algorithm)
	}

	// Derive key using PBKDF2-SHA256
	key := pbkdf2.Key(passphrase, kdfParams.Salt, kdfParams.IterationCount, keyLen, sha256.New)

	// Parse AES-CBC IV
	var iv []byte
	if _, err := asn1.Unmarshal(pbes2.EncryptionScheme.Parameters.FullBytes, &iv); err != nil {
		return nil, fmt.Errorf("failed to unmarshal AES IV: %w", err)
	}

	// Decrypt using AES-CBC
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("failed to create AES cipher: %w", err)
	}

	if len(epki.EncryptedData)%aes.BlockSize != 0 {
		return nil, fmt.Errorf("encrypted data is not a multiple of AES block size")
	}

	decrypted := make([]byte, len(epki.EncryptedData))
	cipher.NewCBCDecrypter(block, iv).CryptBlocks(decrypted, epki.EncryptedData)

	// Remove PKCS#7 padding
	decrypted, err = removePKCS7Padding(decrypted)
	if err != nil {
		return nil, fmt.Errorf("failed to remove padding: %w", err)
	}

	return decrypted, nil
}

// removePKCS7Padding removes PKCS#7 padding from decrypted data
func removePKCS7Padding(data []byte) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("empty data")
	}
	padLen := int(data[len(data)-1])
	if padLen == 0 || padLen > aes.BlockSize {
		return nil, fmt.Errorf("invalid padding length: %d", padLen)
	}
	for _, b := range data[len(data)-padLen:] {
		if int(b) != padLen {
			return nil, fmt.Errorf("invalid padding bytes")
		}
	}
	return data[:len(data)-padLen], nil
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
