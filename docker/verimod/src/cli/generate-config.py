import json, copy, os, sys

# Get the current script's directory
current_dir = os.path.dirname(os.path.abspath(__file__))
# Get the parent directory by going one level up
parent_dir = os.path.dirname(current_dir)
# Add the parent directory to sys.path
sys.path.append(parent_dir + "/module")


def main():

    if len(sys.argv) != 4:
        raise Exception("please run with source input json, template and output json arguments")
    else:
        src_input_path = sys.argv[1]
        template_config_path = sys.argv[2]
        config_path = sys.argv[3]

    with open(src_input_path, 'r') as f:
        src_input = json.load(f)

    with open(template_config_path, 'r') as f:
        template_config = json.load(f)

    merged = dict()
    merged.update(template_config)
    # take first 3 blocks
    src_input["blocks"] = src_input["blocks"][0:3]
    merged.update(src_input)

    with open(config_path, 'w') as f:
        json.dump(merged, f, indent=4)
        f.write('\n')

main()
