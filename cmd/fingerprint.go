package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/percona/go-mysql/query"
)

func main() {
	scanner := bufio.NewScanner(os.Stdin)

	for scanner.Scan() {
		sql := scanner.Text()
		fmt.Println(query.Fingerprint(sql))
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "reading standard input:", err)
	}
}
