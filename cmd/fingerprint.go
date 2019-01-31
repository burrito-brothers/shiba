package main

import (
	"bufio"
	"fmt"
	"io"
	"os"

	"github.com/percona/go-mysql/query"
)

func main() {
	r := bufio.NewReader(os.Stdin)

	for {
		sql, err := r.ReadString('\n')

		switch err {
		case nil:
			fmt.Println(query.Fingerprint(sql))
		case io.EOF:
			os.Exit(0)
		default:
			fmt.Fprintln(os.Stderr, "reading standard input:", err)
		}
	}

}
