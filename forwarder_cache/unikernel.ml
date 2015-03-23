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

  let time_now () = Int32.of_float (Clock.time ())


  let forwarder resolver cache ~src ~dst packet =
    let open Packet in
    match packet.questions with
    | [q] -> (* QDCOUNT=1 *)
        DR.resolve (module Dns.Protocol.Client) resolver resolver_addr resolver_port q.q_class q.q_type q.q_name 
        >>= fun result ->
        Cache.add cache (time_now ()) q.q_name result.answers;
        return (Some (Dns.Query.answer_of_response result))
    | _ -> (* QDCOUNT != 1 *) return None

  let check_cache cache ~src ~dst packet =
    let open Packet in
    match packet.questions with
    | [q] -> (* QDCOUNT=1 *)
      begin
        match Cache.lookup cache (time_now ()) q.q_name with
        | [] -> return None
        | r -> 
        let open Query in
        return (Some 
        {
        rcode=NoError;
        aa= false;
        answer= r;
        authority= [];
        additional= [];
        })
      end
    | _ -> (* QDCOUNT != 1 *) return None

  let start c k s =
    let cache = Cache.create 100 in
    let server = DS.create s k in
    let resolver = DR.create s in
    let processor = (processor_of_process (compose (check_cache cache) (forwarder resolver cache)) :> (module Dns_server.PROCESSOR)) in 
    DS.serve_with_processor server ~port ~processor
end
