from django.http import JsonResponse, HttpResponseBadRequest, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from urllib.parse import urlparse, parse_qs
from verimod.verimod import ( make_initial_state, make_final_state)
import json
import logging

logger = logging.getLogger('development')

def check_category_elements_child(pubkey, category_elements_child):
    for element in category_elements_child:
        if element["pubkey"] == pubkey:
            return True
        child_result = check_category_elements_child(pubkey, element["category_elements_child"])
        if child_result:
            return True
    return False

class StateHandler:
    def __init__(self, config_file="/app/server/config.json"):
        try:
            with open(config_file) as f:
                d = json.load(f)
            self.initial_state = d['initial_state']
            self.blocks = d['blocks']
            self.state, _ = make_final_state(self.initial_state, self.blocks)
            # self.state = [value for key, value in d.items() if "state" in key]
            # self.state.append(self.final_state)
        except Exception as e:
            logger.error(f"Error: No state file found. Exception: {e}")
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
    logger.info("Received GET request.")
    parsed = urlparse(request.get_full_path())
    params = parse_qs(parsed.query)

    try:
        category_type = params["category_type"][0]
        pubkey = params["pubkey"][0]
        result = False
        logger.info(f"category_type: {category_type}, pubkey: {pubkey}")
        category_type_list = list(map(lambda x: x["data"]["category_type"], handler.state["state"]["all_category"]))
        logger.info(f"category_type_list: {category_type_list}")
        for category in handler.state["state"]["all_category"]:
            if category["data"]["category_type"] == category_type:
                category_elements_child = category["data"]["category_elements_child"]
                check_result = check_category_elements_child(pubkey, category_elements_child)
                logger.info(f"category_type: {category_type}, check_result: {check_result}")
                if check_result:
                    result = True
                    break

        if "root_pubkey" in params:
            root_pubkey = params["root_pubkey"][0]
            state_root_pubkey = handler.state["state"]["root_pubkey"]
            if root_pubkey != state_root_pubkey:
                result = False
                logger.error(f"Error: parameter root_pubkey {root_pubkey} and state root_pubkey {state_root_pubkey} is different.")

        return JsonResponse({"result": result})
    except Exception as e:
        logger.error(f"Error while handling GET request. Exception: {e}")
        return HttpResponseBadRequest("Error processing request")

@csrf_exempt
def handle_post(request):
    logger.info("Received POST request.")
    try:
        new_block_json = json.loads(request.body.decode('utf-8'))
        new_block = new_block_json["block"]
    except Exception as e:
        logger.error(f"Error: Invalid block. Exception: {e}")
        return HttpResponseBadRequest("Error: Invalid block")

    try:
        newstate = make_final_state(handler.state, [new_block])[0]
        handler.state = newstate
    except Exception as e:
        logger.error(f"Error: Invalid block processing. Exception: {e}")
        return HttpResponseBadRequest("Error: Invalid block")

    return JsonResponse({"result": "ok"})
