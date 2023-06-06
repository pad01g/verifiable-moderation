
# prepare parameters

```
$ python3 verifiable-moderation.py
```

# run cairo program

export name=verifiable-moderation; cairo-compile src/$name/$name.cairo --output $name.json --cairo_path src && cairo-run --program=$name.json --print_output --layout=dynamic  --print_info --trace_file=$name-trace.bin --memory_file=$name-memory.bin  --debug_error  --program_input=$name-input.json

# License

GPLv3