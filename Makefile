P4C = p4c-bm2-ss
P4C_ARGS = --p4runtime-files switch.p4.p4info.txt

all:
	$(P4C) --p4v 16 $(P4C_ARGS) p4src/switch.p4
