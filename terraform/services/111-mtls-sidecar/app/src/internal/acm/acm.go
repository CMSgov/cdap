package acm

import (
    "context"
    "crypto/tls"
    "encoding/pem"
    "fmt"
    "os"
    "log"

    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/acm"
)

// gather file paths where fetched certs are written
// TODO VERIFY SECURITY CHOICE
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

// export the cert from ACM and writes it to disk
// TODO VERIFY security decision
func (c *Client) FetchAndStore(ctx context.Context) error {
    // NEVER LOG, contains private key material
    out, err := c.acm.ExportCertificate(ctx, &acm.ExportCertificateInput{
        CertificateArn: &c.certARN,
        Passphrase:     []byte(""),
    })
    if err != nil {
        // never log the response — only log that it failed
        return fmt.Errorf("failed to export certificate from ACM (arn redacted): %w", err)
    }

    // never log the values of out.Certificate, out.PrivateKey, out.CertificateChain
    if err := writeFile(c.paths.CertFile, []byte(*out.Certificate)); err != nil {
        return fmt.Errorf("writing cert file: %w", err)
    }
    if err := writeFile(c.paths.KeyFile, []byte(*out.PrivateKey)); err != nil {
        return fmt.Errorf("writing key file: %w", err)
    }
    if err := writeFile(c.paths.CAFile, []byte(*out.CertificateChain)); err != nil {
        return fmt.Errorf("writing CA file: %w", err)
    }

    // only log that it succeeded, never log content
    log.Printf("certificates written to disk: cert=%s key=%s ca=%s",
        c.paths.CertFile, c.paths.KeyFile, c.paths.CAFile)

    return nil
}
// TODO Verify security
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
