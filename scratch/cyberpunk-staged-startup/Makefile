SHELL := /bin/zsh
ROOT := $(abspath ../..)
HOST_DERIVED := $(CURDIR)/HostDerivedData
.PHONY: adapter host simulator
adapter:
	xcodebuild -project $(ROOT)/scratch/cyberpunk-consolidated-host/CyberpunkConsolidatedHost.xcodeproj -scheme HostAdapters -configuration Debug -sdk xros -destination 'generic/platform=visionOS' -derivedDataPath $(HOST_DERIVED) -allowProvisioningUpdates build
host: adapter
	cp -R $(HOST_DERIVED)/Build/Products/Debug-xros/HostAdapters.framework/. Frameworks/HostAdapters.framework/
	xcodebuild -project CyberpunkStartupFileProbe.xcodeproj -scheme CyberpunkStartupFileProbe -configuration Debug -sdk xros -destination 'generic/platform=visionOS' -derivedDataPath $(CURDIR)/DerivedData -allowProvisioningUpdates build
simulator:
	xcodebuild -project $(ROOT)/scratch/cyberpunk-window-init-simulator/CyberpunkWindowInitSimulator.xcodeproj -scheme AdapterChecks -configuration Debug -sdk xrsimulator -destination 'generic/platform=visionOS Simulator' -derivedDataPath $(ROOT)/scratch/cyberpunk-window-init-simulator/DerivedData CODE_SIGNING_ALLOWED=NO build
