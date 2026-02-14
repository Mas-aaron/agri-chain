package bcs

import (
	"context"
	"fmt"
)

type Client interface {
	InvokeChaincode(ctx context.Context, args []string) ([]byte, error)
}

type mockClient struct{}

func NewClient() Client {
	return &mockClient{}
}

func (c *mockClient) InvokeChaincode(_ context.Context, args []string) ([]byte, error) {
	if len(args) < 2 {
		return nil, fmt.Errorf("insufficient args: %v", args)
	}
	ccName := args[0]
	fnName := args[1]
	payloadArgs := args[2:]
	return []byte(fmt.Sprintf(`{"mock":true,"cc":"%s","fn":"%s","args":%v}`, ccName, fnName, payloadArgs)), nil
}
