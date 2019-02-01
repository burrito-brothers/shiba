package main

import (
	"database/sql"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"os"

	_ "github.com/go-sql-driver/mysql"
)

var user = flag.String("u", "", "user name for database connection")
var password = flag.String("p", "", "password for database connection")
var database = flag.String("db", "", "database name e.g. app_test")

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Reads indexes from the given database and outputs the results in CSV.\n")
		fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])

		flag.PrintDefaults()
	}
}

func main() {
	flag.Parse()

	if *user == "" {
		fmt.Println("missing -u database user")
		flag.Usage()
		os.Exit(1)
	}

	if *database == "" {
		fmt.Println("missing -db database name")
		flag.Usage()
		os.Exit(1)
	}

	db, err := sql.Open("mysql", *user+":"+*password+"@/information_schema?charset=utf8")
	defer db.Close()

	if err != nil {
		if *password == "" {
			fmt.Println("missing -p database password")
			flag.Usage()
			os.Exit(1)
		}
	}

	checkErr(err)

	// query
	// select column_name, column_key from columns where table_schema = "zammad_test";
	rows, err := db.Query("SELECT table_name, column_name FROM columns where TABLE_SCHEMA = ? AND COLUMN_KEY is not null", *database)
	checkErr(err)

	w := csv.NewWriter(os.Stdout)

	count := 0
	for rows.Next() {
		count++
		result := make([]string, 2)

		err = rows.Scan(&result[0], &result[1])
		checkErr(err)

		if err := w.Write(result); err != nil {
			log.Fatalln("error writing record to csv:", err)
		}
	}

	// Write any buffered data to the underlying writer (standard output).
	w.Flush()

	if err := w.Error(); err != nil {
		log.Fatal(err)
	}

	if count == 0 {
		log.Fatal("No rows found for database. It's possible the user does not have permissions to view it.")
	}

}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}
