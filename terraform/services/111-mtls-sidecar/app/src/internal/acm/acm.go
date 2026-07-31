package acm

import (
    "context"
    "crypto/tls"
    "crypto/rand"
    "crypto/x509"
    "encoding/hex"
    "encoding/pem"
    "fmt"
    "os"
    "log"

    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/acm"
)

// gather file paths where fetched certs are written
type CertPaths struct {
    CertFile string
    KeyFile  string
    CAFile   string
}

// wrap the ACM SDK client
// Keep values within internal/acm context
type Client struct {
    certARN string
    paths   CertPaths
    acm     *acm.Client
}

// create (construct) a new AWS ACM client
// Use the local role permissions to access AWS
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

// generate a passphrase that's random and sufficient
func generatePassphrase() ([]byte, error) {
    b := make([]byte, 16)
    if _, err := rand.Read(b); err != nil {
        return nil, fmt.Errorf("generating passphrase: %w", err)
    }
    // hex encode so it's always printable ASCII
    return []byte(hex.EncodeToString(b)), nil
}

// export the cert from ACM and writes it to disk
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

    // Decrypt the private key before writing to disk
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
    // Create with restricted permissions first, then write
    f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
    if err != nil {
        return err
    }
    defer f.Close()
    _, err = f.Write(data)
    return err
}

// decryptPrivateKey decrypts a passphrase-protected PEM private key
// and returns a plaintext PEM block
func decryptPrivateKey(encryptedPEM []byte, passphrase []byte) ([]byte, error) {
    block, _ := pem.Decode(encryptedPEM)
    if block == nil {
        return nil, fmt.Errorf("failed to decode PEM block from private key")
    }

    decryptedDER, err := x509.DecryptPEMBlock(block, passphrase)
    if err != nil {
        return nil, fmt.Errorf("failed to decrypt private key: %w", err)
    }

    // Determine key type for correct PEM header
    keyType := "RSA PRIVATE KEY"
    if block.Type == "ENCRYPTED PRIVATE KEY" {
        keyType = "PRIVATE KEY"
    }

    plaintext := pem.EncodeToMemory(&pem.Block{
        Type:  keyType,
        Bytes: decryptedDER,
    })
    if plaintext == nil {
        return nil, fmt.Errorf("failed to encode decrypted private key to PEM")
    }

    return plaintext, nil
}

// load a cert/key pair from disk
func LoadCertificate(certFile, keyFile string) (*tls.Certificate, error) {
    cert, err := tls.LoadX509KeyPair(certFile, keyFile)
    if err != nil {
        return nil, fmt.Errorf("loading cert/key pair: %w", err)
    }
    return &cert, nil
}

// decode the first PEM block from data
func DecodePEM(data []byte) (*pem.Block, error) {
    block, _ := pem.Decode(data)
    if block == nil {
        return nil, fmt.Errorf("failed to decode PEM block")
    }
    return block, nil
}
