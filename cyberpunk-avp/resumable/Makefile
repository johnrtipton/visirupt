SCRATCH := $(abspath ../../scratch/cyberpunk-resumable)
.PHONY: test build
test:
	mkdir -p $(SCRATCH)/tests
	xcrun swiftc -module-cache-path $(SCRATCH)/ModuleCache Sources/AssetReceiver.swift Sources/WriterLease.swift Tests/main.swift -o $(SCRATCH)/tests/receiver-tests
	@fixture=$$(mktemp -d $(SCRATCH)/tests/run.XXXXXX); $(SCRATCH)/tests/receiver-tests "$$fixture"
build:
	xcodegen generate --spec project.yml
	xcodebuild -project CyberpunkAssetReceiver.xcodeproj -scheme CyberpunkAssetReceiver -configuration Debug -sdk xros -destination 'generic/platform=visionOS' -derivedDataPath $(SCRATCH)/DerivedData -allowProvisioningUpdates build

.PHONY: memory-test
memory-test:
	uv run --no-project python Tests/hash-memory.py

.PHONY: background-test background-serve
background-test:
	uv run --no-project python -m unittest discover -s Tests -p test_background_transfer.py
# Transfer/server commands belong to the root CLI so ownership checks cannot be skipped.

.PHONY: lease-test
lease-test:
	mkdir -p $(SCRATCH)/tests
	xcrun swiftc -module-cache-path $(SCRATCH)/ModuleCache Sources/AssetReceiver.swift Sources/WriterLease.swift Tests/writer-lease/main.swift -o $(SCRATCH)/tests/writer-lease-tests
	@fixture=$$(mktemp -d $(SCRATCH)/tests/lease.XXXXXX); $(SCRATCH)/tests/writer-lease-tests "$$fixture"
