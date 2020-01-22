P4C = p4c-bm2-ss
P4C_ARGS = --p4runtime-files $(source_base).p4.p4info.txt

source_base = switch
source = $(source_base).p4
compiled_json := $(source_base).json

all: build

run: build
	echo "run"

build:
	$(P4C) --p4v 16 $(P4C_ARGS) p4src/$(source) -o $(compiled_json)

clean:
	rm $(source_base).p4.p4info.txt
	rm $(compiled_json)
