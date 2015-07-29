package main

import (
	"crypto/rand"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
)

func main() {
	port := os.Getenv("PORT")
	responseSizeEnv := os.Getenv("RESPONSE_SIZE_IN_MB")

	responseSize, err := strconv.Atoi(responseSizeEnv)
	if err != nil {
		panic(err)
	}
	fmt.Println("Starting the test")

	data := make([]byte, 1024*1024)
	n, err := rand.Read(data)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Generated %d random bytes for request of size %d\n", n, responseSize)

	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port),
		http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			for i := 0; i < responseSize; i++ {
				_, err := w.Write(data)
				if err != nil {
					fmt.Printf("Failed to write. Error: %s\n", err.Error())
					break
				}

				if f, ok := w.(http.Flusher); ok {
					f.Flush()
				} else {
					fmt.Println("Damn, no flush")
				}
			}
		})))
}
