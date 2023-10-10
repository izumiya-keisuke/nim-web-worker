# Package

version       = "0.1.0"
author        = "Keisuke Izumiya"
description   = "Web worker implementation in Nim"
license       = "Apache-2.0 OR MPL-2.0"

srcDir        = "src"
installExt    = @["nim"]


# Dependencies

requires "nim ^= 2.0.0"


# Tasks

task test, "Run Tests":
  exec "nimble documentation"
  rmDir "src/htmldocs"

task documentation, "Make Documentation":
  exec "nim doc --project --index -b:js src/nim_web_worker.nim"