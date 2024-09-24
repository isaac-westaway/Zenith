.PHONY: build
build:
	zig build

.PHONY: install
install:
	rm *.log
	
	sudo cp -f ./zig-out/bin/Zenith /usr/bin/Zenith

	sudo chmod 755 /usr/bin/Zenith

all: build install