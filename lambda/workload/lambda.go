package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)



func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	fmt.Printf("event.HTTPMethod %v\n", request.HTTPMethod)
	fmt.Printf("event.Body %v\n", request.Body)
	fmt.Printf("event.QueryStringParameters %v\n", request.QueryStringParameters)
	fmt.Printf("event %v\n", request)


	body := fmt.Sprintf("{\"message\": \"Hello from lambda\" }")

	return events.APIGatewayProxyResponse{
		Body:       body,
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type":                 "application/json",
			"Access-Control-Allow-Headers": "Content-Type",
			"Access-Control-Allow-Origin":  "*",
			"Access-Control-Allow-Methods": "OPTIONS,POST,GET",
		},
	}, nil
}

func main() {
	lambda.Start(handleRequest)
}
