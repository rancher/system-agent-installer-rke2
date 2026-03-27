TARGETS := $(shell ls scripts)

.dapper:
	@echo Downloading dapper
	@DAPPER_BINARY="dapper-$$(uname -s)-$$(uname -m)"; \
	case "$$DAPPER_BINARY" in \
		dapper-Linux-x86_64)  DAPPER_SHA256="ff6105ec0a2a973d972810a2dbdb9a6bae65031d286eae082d6779e04e4c2255" ;; \
		dapper-Linux-aarch64) DAPPER_SHA256="cbc133224cca7593482855d8dcdec247288ec83f0fc99fbbe0ad8423260930ff" ;; \
		dapper-Linux-arm)     DAPPER_SHA256="5455fb8663fddc41f32feb426aa85599d7595a87ffed5144e89e1ecc88a3586b" ;; \
		dapper-Darwin-x86_64) DAPPER_SHA256="850e5f867d9d04840b64b159a8a74dcb56f964185c4bd6631941df738cbc98b4" ;; \
		dapper-Darwin-arm64)  DAPPER_SHA256="ca0a5c32341e6474f9140433110153e0eef304ef74d0a830194428b103e7b52e" ;; \
		*) echo "No pinned SHA256 for dapper on platform: $$DAPPER_BINARY" >&2; exit 1 ;; \
	esac; \
	curl -fsSL "https://releases.rancher.com/dapper/latest/$$DAPPER_BINARY" > .dapper.tmp; \
	echo "$$DAPPER_SHA256  .dapper.tmp" | sha256sum -c -
	@chmod +x .dapper.tmp
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

TAG ?= ${GITHUB_ACTION_TAG}
PRIME_RIBS ?= ${PRIME_RIBS}
SUFFIX ?= ${TAG_SUFFIX}
NANOSERVER ?= ${NANOSERVER_VERSION}

export DOCKER_BUILDKIT?=1

REPO ?= rancher
IMAGE = $(REPO)/system-agent-installer-rke2:$(TAG)

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
