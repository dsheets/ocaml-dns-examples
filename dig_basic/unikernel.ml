open Lwt
open V1_LWT
open Printf

let domain = "google.com"
let server = Ipaddr.V4.make 8 8 8 8

module Client (C:CONSOLE) (S:STACKV4) = struct

  module U = S.UDPV4
  module DNS = Dns_resolver_mirage.Make(OS.Time)(S)

  let start c s =
    let t = DNS.create s in
    C.log_s c "Started, will begin resolving shortly..." >>= fun () ->
    OS.Time.sleep 2.0 >>= fun () ->
      C.log_s c ("Resolving " ^ domain)
      >>= fun () ->
      DNS.gethostbyname t ~server "google.com"
      >>= fun rl ->
      Lwt_list.iter_s
        (fun r ->
           C.log_s c ("Answer " ^ (Ipaddr.to_string r))
        ) rl

end