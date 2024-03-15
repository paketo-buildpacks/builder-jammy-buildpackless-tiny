package smoke_test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/paketo-buildpacks/occam"
	"github.com/sclevine/spec"

	"runtime"

	. "github.com/onsi/gomega"
	. "github.com/paketo-buildpacks/occam/matchers"
)

func testProcfile(t *testing.T, context spec.G, it spec.S) {
	var (
		Expect     = NewWithT(t).Expect
		Eventually = NewWithT(t).Eventually

		pack   occam.Pack
		docker occam.Docker
		arch   string
	)

	it.Before(func() {
		pack = occam.NewPack().WithVerbose().WithNoColor()
		docker = occam.NewDocker()
		arch = runtime.GOARCH
	})

	context("procfile buildpack specified at build time", func() {
		var (
			image     occam.Image
			container occam.Container

			name    string
			source  string
			process string
		)

		it.Before(func() {
			var err error
			name, err = occam.RandomName()
			Expect(err).NotTo(HaveOccurred())

			if arch == "amd64" {
				fmt.Println("Running on AMD64 architecture")
				process = "amd64-process"
			} else if arch == "arm64" {
				fmt.Println("Running on ARM64 architecture")
				process = "arm64-process"
			}
		})

		it.After(func() {
			Expect(docker.Container.Remove.Execute(container.ID)).To(Succeed())
			Expect(docker.Volume.Remove.Execute(occam.CacheVolumeNames(name))).To(Succeed())
			Expect(docker.Image.Remove.Execute(image.ID)).To(Succeed())
			Expect(os.RemoveAll(source)).To(Succeed())
		})

		it("builds Procfile app successfully", func() {
			var err error
			source, err = occam.Source(filepath.Join("testdata", "procfile"))
			Expect(err).NotTo(HaveOccurred())

			var logs fmt.Stringer
			image, logs, err = pack.Build.
				WithBuilder(Builder).
				WithBuildpacks(
					config.Procfile,
				).
				WithAdditionalBuildArgs("--default-process", process).
				Execute(name, source)
			Expect(err).ToNot(HaveOccurred(), logs.String)

			container, err = docker.Container.Run.
				WithEnv(map[string]string{"PORT": "8080"}).
				WithPublish("8080").
				Execute(image.ID)
			Expect(err).NotTo(HaveOccurred())

			Eventually(container).Should(BeAvailable())

			Expect(logs).To(ContainLines(ContainSubstring("Paketo Buildpack for Procfile")))
		})
	})
}
