from django.http import JsonResponse, HttpResponseBadRequest, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from urllib.parse import urlparse, parse_qs
from .verimod import (generate_key_pair, generate_blocks, make_initial_state, make_final_state)
import json
import logging

def check_category_elements_child(pubkey, category_elements_child):
    for element in category_elements_child:
        if element["pubkey"] == pubkey:
            return True
        child_result = check_category_elements_child(pubkey, element["category_elements_child"])
        if child_result:
            return True
    return False

class StateHandler:
    def __init__(self, config_file="/app/config.json"):
        try:
            with open(config_file) as f:
                d = json.load(f)
            self.initial_state = d['initial_state']
            self.blocks = d['blocks']
            self.final_state, _ = make_final_state(self.initial_state, self.blocks)
            self.state = [value for key, value in d.items() if "state" in key]
            self.state.append(self.final_state)
        except Exception as e:
            logging.error(f"Error: No state file found. Exception: {e}")
            raise e

handler = StateHandler()

@csrf_exempt
def handle_request(request):
    if request.method == "GET":
        return handle_get(request)
    elif request.method == "POST":
        return handle_post(request)
    else:
        return HttpResponse("Welcome to verifiable moderation!")

def handle_get(request):
    logging.info("Received GET request.")
    parsed = urlparse(request.get_full_path())
    params = parse_qs(parsed.query)

    try:
        category_type = params["category_type"][0]
        pubkey = params["pubkey"][0]
        result = False
        for state in handler.state:
            for category in state["state"]["all_category"]:
                if category["data"]["category_type"] == category_type:
                    category_elements_child = category["data"]["category_elements_child"]
                    if check_category_elements_child(pubkey, category_elements_child):
                        result = True
                        break
        return JsonResponse({"result": result})
    except Exception as e:
        logging.error(f"Error while handling GET request. Exception: {e}")
        return HttpResponseBadRequest("Error processing request")

@csrf_exempt
def handle_post(request):
    logging.info("Received POST request.")
    try:
        new_block_json = json.loads(request.body.decode('utf-8'))
        new_block = new_block_json["block"]
    except Exception as e:
        logging.error(f"Error: Invalid block. Exception: {e}")
        return HttpResponseBadRequest("Error: Invalid block")

    try:
        newstate = [make_final_state(state, [new_block])[0] for state in handler.state]
        handler.state = newstate
    except Exception as e:
        logging.error(f"Error: Invalid block processing. Exception: {e}")
        return HttpResponseBadRequest("Error: Invalid block")

    return JsonResponse({"result": "ok"})
