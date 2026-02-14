package auth

import (
	"context"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

type FirebaseVerifier struct {
	client *auth.Client
}

var (
	firebaseOnce sync.Once
	firebaseV    *FirebaseVerifier
	firebaseErr  error
)

func NewFirebaseVerifier(ctx context.Context, credsPath string) (*FirebaseVerifier, error) {
	firebaseOnce.Do(func() {
		app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credsPath))
		if err != nil {
			firebaseErr = err
			return
		}
		c, err := app.Auth(ctx)
		if err != nil {
			firebaseErr = err
			return
		}
		firebaseV = &FirebaseVerifier{client: c}
	})
	if firebaseErr != nil {
		return nil, firebaseErr
	}
	return firebaseV, nil
}

func (v *FirebaseVerifier) VerifyIDToken(ctx context.Context, idToken string) (*auth.Token, error) {
	return v.client.VerifyIDToken(ctx, idToken)
}
