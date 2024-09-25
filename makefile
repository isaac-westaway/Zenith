.PHONY: build
build:
	zig build

.PHONY: install
install:
	@if ls *.log 1> /dev/null 2>&1; then \
		rm *.log; \
	fi	
	sudo cp -f ./zig-out/bin/Zenith /usr/bin/Zenith

	sudo chmod 755 /usr/bin/Zenith

all: build install