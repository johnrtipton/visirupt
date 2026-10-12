SCRATCH := $(abspath ../../scratch/cyberpunk-resumable)
.PHONY: test build
test:
	mkdir -p $(SCRATCH)/tests
	xcrun swiftc -module-cache-path $(SCRATCH)/ModuleCache Sources/AssetReceiver.swift Tests/main.swift -o $(SCRATCH)/tests/receiver-tests
	@fixture=$$(mktemp -d $(SCRATCH)/tests/run.XXXXXX); $(SCRATCH)/tests/receiver-tests "$$fixture"
build:
	xcodegen generate --spec project.yml
	xcodebuild -project CyberpunkAssetReceiver.xcodeproj -scheme CyberpunkAssetReceiver -configuration Debug -sdk xros -destination 'generic/platform=visionOS' -derivedDataPath $(SCRATCH)/DerivedData -allowProvisioningUpdates build

.PHONY: resume
ASSET_ROOT ?= $(abspath ../../scratch/cyberpunk-startup-file-probe/DerivedData/Build/Products/Debug-xros/CyberpunkStartupFileProbe.app)
resume:
	python3 transfer.py assets --asset-root "$(ASSET_ROOT)"

.PHONY: memory-test
memory-test:
	python3 Tests/hash-memory.py

.PHONY: background-test background-serve
BACKGROUND_PLAN ?= $(abspath ../../scratch/cyberpunk-background-asset/background-transfer-plan.json)
background-test:
	python3 -m unittest discover -s Tests -p test_background_transfer.py
background-serve:
	python3 background_transfer.py serve --asset-root "$(ASSET_ROOT)" --plan "$(BACKGROUND_PLAN)"
