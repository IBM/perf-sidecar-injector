IMAGE ?= bpradipt/perf-sidecar-injector
TAG ?= $(shell git describe --tags --always)
RELEASE_TAG := v$(shell cat VERSION)
ARCH ?= $(shell uname -m)

ifeq ($(ARCH), x86_64)
	IMAGE_ARCH = $(IMAGE)-amd64
else
	IMAGE_ARCH = $(IMAGE)-$(ARCH)
endif


build: ## Builds the perf-sidecar-injector binary
	dep ensure
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o perf-sidecar-injector .

image: build ## Builds a Linux based image
	docker build -t "$(IMAGE_ARCH):$(TAG)" .

clean: ## Cleans up build artifacts
	rm -f perf-sidecar-injector

push: image ## Pushes the image to dockerhub, REQUIRES SPECIAL PERMISSION
	docker push "$(IMAGE_ARCH):$(TAG)"

release: image ## Pushes the image with latest and version tag to dockerhub, REQUIRES SPECIAL PERMISSION
	docker tag "$(IMAGE_ARCH):$(TAG)" "$(IMAGE_ARCH):$(RELEASE_TAG)"
	docker tag "$(IMAGE_ARCH):$(TAG)" "$(IMAGE_ARCH):latest"
	docker push "$(IMAGE_ARCH):$(RELEASE_TAG)"
	docker push "$(IMAGE_ARCH):latest"

manifest: release ## Create multi-arch manifest
	docker manifest create $(IMAGE):$(RELEASE_TAG) \
	$(IMAGE)-amd64:$(RELEASE_TAG) \
	$(IMAGE)-ppc64le:$(RELEASE_TAG)

	docker manifest create $(IMAGE):latest \
	$(IMAGE)-amd64:latest \
	$(IMAGE)-ppc64le:latest

	docker manifest push $(IMAGE):$(RELEASE_TAG)
	docker manifest push $(IMAGE):latest

help: ## Shows the help
	@echo 'Usage: make <OPTIONS> ... <TARGETS>'
	@echo ''
	@echo 'Available targets are:'
	@echo ''
	@grep -E '^[ a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
        awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ''

.PHONY: build image clean push release manifest help
