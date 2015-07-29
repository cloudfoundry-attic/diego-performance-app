package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	m := os.Getenv("MESSAGES_PER_SECOND")
	fmt.Println("Starting the test")
	fmt.Println("MESSAGES_PER_SECOND: ", m, " PORT: ", port)
	messagesPerSecond, err := strconv.Atoi(m)
	if err != nil {
		panic(err)
	}

	writeInterval := time.Second / time.Duration(messagesPerSecond)
	var i uint64
	var s time.Time

	go func() {
		log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port),
			http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {

				totalTime := time.Now().Sub(s)
				rate := float64(totalTime) / float64(i)

				perSecond := float64(time.Second) / rate
				fmt.Fprintf(w, "Alive for %s, %.2f per second, average message rate %f", totalTime, perSecond, rate)
			})))
	}()

	s = time.Now()
	for {
		before := time.Now()
		fmt.Printf("%d line %d\n", before.UnixNano(), i)
		after := time.Now()

		remainder := writeInterval - after.Sub(before)
		if remainder > 0 {
			time.Sleep(remainder)
		}

		i++
	}
}
