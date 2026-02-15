package config

import (
	"os"
)

type Config struct {
	Port                    string
	SQLitePath              string
	FirebaseCredentialsPath string
	MLBaseURL               string
}

func Load() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}
	sqlitePath := os.Getenv("SQLITE_PATH")
	if sqlitePath == "" {
		sqlitePath = "./data/agrichain.db"
	}
	credsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	mlBaseURL := os.Getenv("ML_BASE_URL")
	if mlBaseURL == "" {
		mlBaseURL = "http://127.0.0.1:8001"
	}
	return Config{Port: port, SQLitePath: sqlitePath, FirebaseCredentialsPath: credsPath, MLBaseURL: mlBaseURL}
}
