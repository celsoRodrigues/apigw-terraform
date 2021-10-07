build:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ./lambda/workload/hello -ldflags '-w' ./lambda/workload/lambda.go
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ./lambda/auth/auth -ldflags '-w' ./lambda/auth/auth.go
	@echo "build completed."

mod:
	go mod init acesslambda
tidy:
	go mod tidy

test:
	go test -v --bench=. --benchmem

vendor:
	go mod vendor -v

compress:
	pushd ../../../bin/
	zip Hello.zip ./Hello
	rm ../../../bin/hello

