package response

import "net/http"

type Error struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`
}

type ErrorResponse struct {
	Error Error `json:"error"`
}

func NewError(code, message string, details map[string]any) ErrorResponse {
	return ErrorResponse{Error: Error{Code: code, Message: message, Details: details}}
}

func HTTPStatusForCode(code string) int {
	switch code {
	case "VALIDATION_ERROR":
		return http.StatusBadRequest
	case "KYC_REQUIRED":
		return http.StatusForbidden
	case "PHASE_RESTRICTED":
		return http.StatusForbidden
	case "POSITION_LIMIT":
		return http.StatusForbidden
	case "DAILY_LIMIT":
		return http.StatusForbidden
	case "NOT_FOUND":
		return http.StatusNotFound
	default:
		return http.StatusInternalServerError
	}
}
