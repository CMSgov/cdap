package objectstore

import (
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go/aws/session"

	s3 "github.com/fclairamb/afero-s3"
)

type ObjectStoreSession struct {
	Provider string
	Session  *session.Session
	// Other providers can be added as needed.
}

type ObjectStore struct {
	ObjectStoreSession *ObjectStoreSession
	FS                 string
	Endpoint           string
	Region             string
	Bucket             string
	Path               string
	Key                string
	Secret             string
}

func NewObjectSession(provider string, region string) (*ObjectStoreSession, error) {
	objSess := &ObjectStoreSession{}
	switch provider {
	case "aws":
		sess, _ := session.NewSession(&aws.Config{
			Region: aws.String(region),
		})
		objSess.Provider = "aws"
		objSess.Session = sess
	}

	// // Initialize the file system
	// s3Fs := s3.NewFs(bucket, sess)

	// // And do your thing
	// file, _ := fs.OpenFile("file.txt", os.O_WRONLY, 0777)
	// file.WriteString("Hello world !")
	// file.Close()

	return objSess, nil
}

func NewObjectStore(provider string, region string) *ObjectStore {
	objSess, err := NewObjectSession(provider, region)
	if err != nil {
		panic("could not initialize object store")
	}
	os := &ObjectStore{
		ObjectStoreSession: objSess,
	}
	return os
}

func (os *ObjectStore) SetBucket(bucket string) *ObjectStore {
	s3Fs := s3.NewFsFromConfig(bucket, os.ObjectStoreSession.Session.Config)
}

func (os *ObjectStore) SetKeyAndSecret(keyID string, secret string) {
	// Note: the last parameter is a token, which is for STS creds. May not be necessary here, but
	// worth noting for the future.
	os.Session.Session.Config.Credentials = credentials.NewStaticCredentials(keyID, secret, "")
}
