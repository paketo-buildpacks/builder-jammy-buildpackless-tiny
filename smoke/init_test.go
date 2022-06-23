package smoke_test

import (
	"encoding/json"
	"flag"
	"os"
	"testing"
	"time"

	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"

	. "github.com/onsi/gomega"
)

var (
	Builder string

	config struct {
		Procfile string `json:"procfile"`
	}
)

func init() {
	flag.StringVar(&Builder, "name", "", "")
}

func TestSmoke(t *testing.T) {
	Expect := NewWithT(t).Expect

	flag.Parse()

	Expect(Builder).NotTo(Equal(""))

	SetDefaultEventuallyTimeout(60 * time.Second)

	file, err := os.Open("../smoke.json")
	Expect(err).NotTo(HaveOccurred())

	Expect(json.NewDecoder(file).Decode(&config)).To(Succeed())
	Expect(file.Close()).To(Succeed())

	suite := spec.New("Buildpackless Smoke", spec.Parallel(), spec.Report(report.Terminal{}))
	suite("Procfile", testProcfile)
	suite.Run(t)
}
