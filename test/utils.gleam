import gleam/erlang/charlist.{type Charlist}
import gleam/int
import gleam/result

@external(erlang, "os", "cmd")
fn os_cmd(command: Charlist) -> Charlist

pub fn cmd(command: String) -> String {
  command
  |> charlist.from_string
  |> os_cmd
  |> charlist.to_string
}

pub fn getuid() -> Int {
  cmd("id -u")
  |> int.parse
  |> result.lazy_unwrap(fn() { panic })
}

pub fn require_root() {
  case getuid() {
    0 -> Nil
    _ -> panic as "must be run as root"
  }
}
