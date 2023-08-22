.PHONY: test build

run:
	cairo-compile src/main.cairo --output verifiable-moderation.json --cairo_path src && cairo-run --program=verifiable-moderation.json --print_output --layout=dynamic  --print_info --trace_file=verifiable-moderation-trace.bin --memory_file=verifiable-moderation-memory.bin  --debug_error  --program_input=verifiable-moderation-input.json

build:
	protostar build-cairo0 --disable-hint-validation

test:
	protostar test-cairo0 --disable-hint-validation

clean:
	rm -rf build/*
