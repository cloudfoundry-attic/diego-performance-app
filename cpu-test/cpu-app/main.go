package main

import (
	"fmt"
	"os"
	"strconv"
)

func main() {
	nArg := os.Getenv("FIB_NUM")

	n, err := strconv.Atoi(nArg)
	if err != nil {
		panic(err)
	}

	fmt.Println("Starting the test")

	for {
		println(calculateNFib(n))
	}
}

func calculateNFib(n int) int {
	if n == 0 {
		return 0
	} else if n < 2 {
		return 1
	} else {
		return calculateNFib(n-1) + calculateNFib(n-2)
	}
}
