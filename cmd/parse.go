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
	parseQueries(os.Stdin)
}

func parseQueries(r io.Reader) {
	scanner := bufio.NewScanner(r)

	enc := json.NewEncoder(os.Stdout)

	for scanner.Scan() {
		sql := scanner.Text()
		stmt, err := sqlparser.Parse(sql)

		if err != nil {
			fmt.Println("Unable to parse line", sql)
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}

		switch q := stmt.(type) {
		case *sqlparser.Select:
			parsed := parse(q)
			enc.Encode(parsed)
		case *sqlparser.Insert:
			enc.Encode(parseTable(q))
		default:
			fmt.Fprintln(os.Stderr, "Only Select queries are supported", sqlparser.String(stmt))
			os.Exit(1)
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "reading standard input:", err)
	}
}

func parseTable(q *sqlparser.Insert) string {
	return sqlparser.String(q.Table)
}

func parse(q *sqlparser.Select) query {
	// fixme: assume simple table from
	//tables := sqlparser.String(q.From[0])
	table := sqlparser.String(q.From)
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
