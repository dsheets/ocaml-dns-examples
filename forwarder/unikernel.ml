open Lwt
open V1_LWT
open Dns
open Dns_server

let port = 53
let resolver_addr = Ipaddr.V4.make 8 8 8 8
let resolver_port = 53

module Main (C:CONSOLE) (K:KV_RO) (S:STACKV4) = struct

  module U = S.UDPV4
  module DS = Dns_server_mirage.Make(K)(S)
  module DR = Dns_resolver_mirage.Make(OS.Time)(S)

  let process resolver ~src ~dst packet =
      let open Packet in
      match packet.questions with
      | [] -> (* we are not supporting QDCOUNT = 0  *)
          return None 
      | [q] -> 
          DR.resolve (module Dns.Protocol.Client) resolver 
            resolver_addr resolver_port q.q_class q.q_type q.q_name 
          >>= fun result ->
          return (Some (Dns.Query.answer_of_response result))) 
      | _ -> (* we are not supporting QDCOUNT > 1 *)
          return None

  let start c k s =
    let server = DS.create s k in
    let resolver = DR.create s in
    let processor = 
      ((Dns_server.processor_of_process (process resolver)) 
          :> (module Dns_server.PROCESSOR)) in 
    DS.serve_with_processor server ~port ~processor
end
