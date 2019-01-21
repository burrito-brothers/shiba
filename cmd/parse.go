package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/xwb1989/sqlparser"
)

type query struct {
	Table   string   `json:"table"`
	Columns []string `json:"columns"`
}

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Takes queries from stdin and converst them to json.\n")
	}
}

func main() {
	r := bufio.NewReader(os.Stdin)
	parseQueries(r)
}

func parseQueries(r io.Reader) {
	tokens := sqlparser.NewTokenizer(r)
	enc := json.NewEncoder(os.Stdout)

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
			parsed := parse(q)
			enc.Encode(parsed)
		default:
			fmt.Fprintln(os.Stderr, "Only Select queries are supported", sqlparser.String(stmt))
			os.Exit(1)
		}
	}
}

func parse(q *sqlparser.Select) query {
	// fixme: assume simple table from
	table := sqlparser.String(q.From[0])
	columns := []string{}
	sqlparser.Walk(func(node sqlparser.SQLNode) (bool, error) {
		switch node.(type) {
		case *sqlparser.ColName:
			c := sqlparser.String(node)
			columns = append(columns, c)
		}

		return true, nil
	}, q.Where)

	return query{Table: table, Columns: columns}
}
