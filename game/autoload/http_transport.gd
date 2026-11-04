class_name HttpTransport
extends Node
## Sends one HTTP request with an HTTPRequest node and waits for the answer.
## Backend uses it; tests swap in a fake with the same send() method.
## On the web, HTTPRequest uses the browser's fetch, which can't stream, so
## callers show a "thinking" animation while they wait.


## Returns {"code": HTTP status or 0, "body": text, "error": "" | "network" |
## "timeout"}.
func send(method: int, url: String, headers: PackedStringArray, body: String, timeout: float) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return {"code": 0, "body": "", "error": "network"}
	var result: Array = await http.request_completed
	http.queue_free()
	match int(result[0]):
		HTTPRequest.RESULT_SUCCESS:
			return {"code": int(result[1]), "body": (result[3] as PackedByteArray).get_string_from_utf8(), "error": ""}
		HTTPRequest.RESULT_TIMEOUT:
			return {"code": 0, "body": "", "error": "timeout"}
	return {"code": 0, "body": "", "error": "network"}
