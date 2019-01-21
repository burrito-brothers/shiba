package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/xwb1989/sqlparser"
)

var indexFile = flag.String("i", "", "index files to check queries against")

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Returns unindexed queries. Reads select sql statements from stdin and checks the provided index file which is the result of analyze.\n")
		fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])

		flag.PrintDefaults()
	}
}

type tableStats map[string][]string

func main() {
	flag.Parse()

	if *indexFile == "" {
		flag.Usage()
		os.Exit(1)
	}

	stats := readTableIndexes(*indexFile)
	r := bufio.NewReader(os.Stdin)

	analyzeQueries(r, stats)

}

func readTableIndexes(path string) tableStats {
	f, err := os.Open(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "index list not found at", path)
		os.Exit(1)
	}

	br := bufio.NewReader(f)

	r := csv.NewReader(br)

	indexes := map[string][]string{}

	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatal(err)
		}

		table := record[0]

		indexes[table] = append(indexes[table], record[1])
	}

	return indexes
}

func analyzeQueries(r io.Reader, stats tableStats) {
	tokens := sqlparser.NewTokenizer(r)
	for {
		stmt, err := sqlparser.ParseNext(tokens)
		if err == io.EOF {
			break
		}

		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}

		switch q := stmt.(type) {
		case *sqlparser.Select:
			if !hasIndex(q, stats) {
				fmt.Println(sqlparser.String(q))
			}
		default:
			fmt.Fprintln(os.Stderr, "Only Select queries are supported", sqlparser.String(stmt))
			os.Exit(1)
		}
	}
}

func hasIndex(q *sqlparser.Select, stats tableStats) bool {
	// fixme: assume simple table from
	table := sqlparser.String(q.From[0])
	// expr :=
	if _, ok := stats[table]; !ok {
		fmt.Fprintln(os.Stderr, "Table does not appear to have an index", sqlparser.String(q))
		return false
	}

	indexed := stats[table]

	var found bool
	sqlparser.Walk(func(node sqlparser.SQLNode) (bool, error) {
		switch node.(type) {
		case *sqlparser.ColName:
			c := sqlparser.String(node)
			for _, v := range indexed {
				if v == c {
					found = true
					return false, nil
				}
			}
		}

		return true, nil
	}, q.Where)

	return found
}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}
