## The `nim_web_worker` module implements the web worker.
## With `import nim_web_worker`, you can use all features provided by this
## module.
##
## To generate the JS file used to launch the worker, add the following code
## to the file to be compiled.
## ```nim
## import nim_web_worker
## when isMainModule:
##   DefaultWorkerTask.assignToWorker # register the actual task to be used
## ```
##
## The name of the JS file generated as above should be `worker.min.js`.
## You can change it by adding the compile option: `-d:WorkerFileName=<name>`.
##

{.experimental: "strictDefs".}

import std/[jsffi, strformat, strutils, sugar]

type
  WorkerReturnCode* {.pure.} = enum
    ## Return code of the worker task.
    Success = "success"
    Failure = "failure"

  WorkerTask* = (varargs[string] {.gcsafe.} ->
    tuple[code: WorkerReturnCode, messages: seq[string]])
    ## Task executed in a new thread.

  WorkerCompleteHandler* = (varargs[string] {.gcsafe.} -> void)
    ## Handler executed after the `WorkerTask` completed.

  Worker* = object
    ## Web Worker.
    webWorker: JsObject
    completeHandler: WorkerCompleteHandler

const
  WorkerFileName {.strdefine.} = "worker.min.js"

  DefaultWorkerTask*: WorkerTask =
    (args: varargs[string]) => (Success, newSeq[string](0))
  DefaultWorkerCompleteHandler*: WorkerCompleteHandler =
    (args: varargs[string]) => (discard)

  HeaderSep = "|-<nim-web-worker-header-sep>-|"
  MessageSep = "|-<nim-web-worker-sep>-|"
  
# ------------------------------------------------
# Task
# ------------------------------------------------

proc getSelf: JsObject {.importjs: "(self)".} ## Returns the web worker object.

func split2(str, sep: string): seq[string] {.inline.} =
  ## Splits `str` by `sep`.
  ## If `str == ""`, returns `@[]`
  ## (unlike `strutils.split`; it returns `@[""]`).
  if str == "": @[] else: str.split sep

proc postMessage(code: WorkerReturnCode, messages: varargs[string]) {.inline.} =
  ## Sends the message to the caller of the worker.
  getSelf().postMessage cstring &"{code}{HeaderSep}{messages.join MessageSep}"

proc run(event: JsObject, task: WorkerTask) {.inline.} =
  ## Runs the task and sends the message to the caller of the worker.
  let (code, messages) = task ($event.data.to(cstring)).split2 MessageSep
  postMessage code, messages

proc run*(worker: Worker, args: varargs[string]) {.inline.} =
  ## Runs the task and sends the message to the caller of the worker.
  worker.webWorker.postMessage cstring args.join MessageSep

proc assignToWorker*(task: WorkerTask) {.inline.} =
  ## Assigns the task to the worker.
  getSelf().onmessage = (event: JsObject) => event.run task

# ------------------------------------------------
# Complete Handler
# ------------------------------------------------

proc runCompleteHandler(worker: Worker, event: JsObject) {.inline.} =
  ## Runs the complete handler.
  # TODO: use `logger` instead of `echo` (generating documentation using
  # logger raises the error due to Nim's bug)
  let messages = ($event.data.to(cstring)).split HeaderSep
  if messages.len != 2:
    echo "Invalid arguments are passed to the complete handler: ", $messages
    return

  case messages[0]
  of $Success:
    worker.completeHandler messages[1].split2 MessageSep
  of $Failure:
    echo messages[1]
  else:
    echo "Invalid return code is passed to the complete handler: ", messages[0]

# ------------------------------------------------
# Constructor
# ------------------------------------------------

proc initWebWorker: JsObject {.importjs: &"new Worker('{WorkerFileName}')".}
  ## Returns the web worker launched by the caller.

func registerOnmessage(worker: Worker) =
  ## Registers `onmessage`.
  # NOTE: inlining this function causes error due to specification
  worker.webWorker.onmessage =
    (event: JsObject) => (worker.runCompleteHandler event)

proc initWorker*(completeHandler = DefaultWorkerCompleteHandler): Worker
                {.inline.} =
  ## Returns the worker.
  result.webWorker = initWebWorker()
  result.registerOnmessage
  result.completeHandler = completeHandler
