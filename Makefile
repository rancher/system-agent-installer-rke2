TARGETS := $(shell ls scripts)

.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-$$(uname -s)-$$(uname -m) > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

$(TARGETS): .dapper
	./.dapper $@

.DEFAULT_GOAL := build

.PHONY: $(TARGETS)

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

SANITIZED_TAG ?= ${SANITIZED_TAG}
PRIME_RIBS ?= ${PRIME_RIBS_URL}
SUFFIX ?= ${TAG_SUFFIX}
NANOSERVER ?= ${NANOSERVER_VERSION}

export DOCKER_BUILDKIT?=1

REPO ?= rancher
IMAGE = $(REPO)/system-agent-installer-rke2:$(SANITIZED_TAG)

BUILD_OPTS = \
	--platform=$(TARGET_PLATFORMS) \
	--build-arg TAG=$(TAG:$(BUILD_META)=) \
	--build-arg NANOSERVER_VERSION=$(NANOSERVER) \
	--tag "$(IMAGE)"

WINDOWS_BUILD_OPTS = \
	--platform=$(TARGET_PLATFORMS) \
	--build-arg TAG=$(TAG:$(BUILD_META)=) \
	--build-arg NANOSERVER_VERSION=$(NANOSERVER) \
	--tag "$(IMAGE)"

.PHONY: image-build
image-build:
	docker buildx build \
		$(BUILD_OPTS) \
		--load \
		--file ./package/Dockerfile \
		.

.PHONY: image-build-windows
image-build-windows:
	docker buildx build \
		$(WINDOWS_BUILD_OPTS) \
		--load \
		--file ./package/Dockerfile.windows \
		.

.PHONY: push-image
push-image:
	PRIME_RIBS=$(PRIME_RIBS) docker buildx build \
		$(BUILD_OPTS) \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--push \
		--file ./package/Dockerfile \
		.

.PHONY: push-image-windows
push-image-windows:
	PRIME_RIBS=$(PRIME_RIBS) docker buildx build \
		$(WINDOWS_BUILD_OPTS) \
		$(IID_FILE_FLAG) \
		--sbom=true \
		--attest type=provenance,mode=max \
		--push \
		--file ./package/Dockerfile.windows \
		.

.PHONY: publish-manifest
publish-manifest:  						   ## Create and push the runtime manifest
	IMAGE=$(IMAGE) ./scripts/publish-manifest
