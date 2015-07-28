package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	location := os.Getenv("DOWNLOAD_LOCATION")

	fmt.Println("Starting the test")

	s := time.Now()
	go func() {
		log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port),
			http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
				totalTime := time.Now().Sub(s)
				fmt.Fprintf(w, "Alive for %s", totalTime)
			})))
	}()

	for {
		downloadFile(location)
		time.Sleep(1 * time.Second)
	}
}

func downloadFile(location string) {
	resp, err := http.Get(location)
	if err != nil {
		fmt.Printf("Failed to download. Error: %s\n", err.Error())
		return
	}
	defer resp.Body.Close()

	n, err := io.Copy(ioutil.Discard, resp.Body)
	if err != nil {
		fmt.Printf("Failed to read. Error: %s\n", err.Error())
		return
	}
	fmt.Printf("Read %d bytes!\n", n)
}
