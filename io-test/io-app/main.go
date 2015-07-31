package main

import (
	"crypto/rand"
	"fmt"
	"io/ioutil"
	"os"
	"strconv"
	"sync"
)

func main() {
	nArg := os.Getenv("FILE_SIZE_MB")

	n, err := strconv.Atoi(nArg)
	if err != nil {
		panic(err)
	}

	fmt.Println("Starting the test")
	var wg sync.WaitGroup
	for {
		for i := 0; i < 30; i++ {
			wg.Add(1)
			go func() {
				writeReadDelete(n)
				wg.Done()
			}()
		}
		wg.Wait()
	}
}

func writeReadDelete(mByteCount int) {
	f, err := ioutil.TempFile("", "testfile")
	if err != nil {
		panic(err)
	}
	defer func() {
		f.Close()
		os.Remove(f.Name())
	}()

	data := make([]byte, 1024)
	_, err = rand.Read(data)
	if err != nil {
		fmt.Printf("Failed to generate random stuff. Error: %s\n", err.Error())
		panic(err)
	}

	for i := 0; i < mByteCount*1024; i++ {
		_, err = f.WriteAt(data, int64(i*1024))
		if err != nil {
			fmt.Printf("Failed to sync. Error: %s\n", err.Error())
			panic(err)
		}
	}

	err = f.Sync()
	if err != nil {
		fmt.Printf("Failed to sync. Error: %s\n", err.Error())
		panic(err)
	}

	for i := 0; i < mByteCount*1024; i++ {
		_, err = f.ReadAt(data, int64(i*1024))
		if err != nil {
			fmt.Printf("Failed to read. Error: %s\n", err.Error())
			panic(err)
		}
	}

	err = f.Sync()
	if err != nil {
		fmt.Printf("Failed to sync. Error: %s\n", err.Error())
		panic(err)
	}
}
