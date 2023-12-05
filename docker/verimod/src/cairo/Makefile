.PHONY: test build

run:
	python3 ../cli/generate-input.py ./verifiable-moderation-input.json && \
	cairo-compile src/main.cairo \
		--proof_mode \
		--output verifiable-moderation.json \
		--cairo_path src && \
	cairo-run \
		--program=verifiable-moderation.json \
		--print_output \
		--layout=starknet \
		--print_info \
		--trace_file=verifiable-moderation-trace.bin \
		--memory_file=verifiable-moderation-memory.bin  \
		--debug_error  \
		--program_input=verifiable-moderation-input.json \
		--air_private_input air-private-input.json  \
		--air_public_input air-public-input.json \
		--proof_mode

build:
	protostar build-cairo0 --disable-hint-validation

test:
	protostar test-cairo0 --disable-hint-validation $(TARGET)

clean:
	rm -rf build/*
