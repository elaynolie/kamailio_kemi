-- request_route{}
function ksr_request_route()
    KSR.info("===== SIP request - from kamailio lua script\n");

    route_reqinit()
    route_natmanage()
    route_canceling()

    if route_withindlg() then
        route_relay()
    end

    route_sipout()
    route_auth()
    route_registrar()
    route_routing()

    if not route_location() then
        route_to_pstn()
    end

    route_relay()
end

-- onreply_route {}
function ksr_reply_route()
    KSR.info("===== SIP response - from kamailio lua script\n")
    KSR.hdr.append("Carrier: 77.51.206.229\r\n")
    route_natmanage()
    route_sdpmanage()
end

--  branch_route{}
function ksr_branch_route_manage_branch()
    KSR.info("===== branch route - MANAGE_BRANCH\n")
    -- KSR.hdr.append("Contact: <sip:" .. KSR.pv.get("$fU") .. "@5.39.220.42>") -- Uncomment if needed
    -- KSR.hdr.append("Contact: <sip:543543623@5.39.220.42>") -- Uncomment if needed
    route_sdpmanage()
end

function ksr_failure_route_manage_failure()
    KSR.info("===== failure route - MANAGE_FAILURE\n")
    
    if KSR.tm.t_check_status("404|503|486") then
        KSR.pv.sets("$ru", "sip:2" .. KSR.pv.get("$rU") .. "@77.51.206.229:5065")
        if KSR.tm.t_relay() < 0 then
            KSR.tm.t_reply(500, "Server Error")
        end
    end

    if KSR.is_INVITE() and KSR.tm.t_check_status("401|407") then
        if KSR.uac.uac_auth() then
            KSR.xlog("L_INFO", "40X auth check handle")
        end
    end
end

function ksr_event_route_topoh_msg_outgoing()
    if KSR.pv.get("$sndto(ip)") == "77.51.206.229" then
        KSR.x.drop()
    end
end

function route_reqinit()
    KSR.info("===== Executing route REQINIT\n")
    KSR.sl.set_reply_no_connect()

    if KSR.pv.get("$si") ~= KSR.pv.get("$myself") then
        if KSR.pv.get("$sht(ipban=>$si)", 1)
        return -1 
    end


    if.KSR.maxfwd.process.maxfwd(10) < 1 then
        KSR.sl.sl_send_reply(483,"Too many hoops")
        return(-1)
    end

    if KSR.tm.is_method("OPTIONS") and KSR.pv.get("$rU") == nil and KSR.pv.get("$ru") == KSR.pv.get("$myself") then
        KSR.sl.sl_send_reply(200, "ok")
        return -1
    end

    if KSR.sanity.sanity_check(17895, 7) < 0 then
        KSR.xlog("Malformed SIP request from " .. KSR.pv.get("$si") .. ":" .. KSR.pv.get("$sp") .. "\n")
        return -1
    end
end

function route_auth()
    if KSR.is_method("REGISTER") then
        if not KSR.auth_check(KSR.pv.get("$fd"),"subscriber", "1") then
            KSR.auth_challenge(KSR.pv.get("$fd"), "0")
            return
        end
        KSR.consume_credentials()
    end
end

function route_registrar()
    if not KSR.is_method("REGISTER") then
        return
    end

    if not KSR.save("location") then
        KSR.sl_reply_error()
    end
end


function route_natmanage()
    KSR.tm.force_rport()
    KSR.xlog("L_INFO", "received avp before: " .. KSR.pv.get("$avp(RECEIVED)"))
    KSR.nathelper.fix_nated_register()
    KSR.xlog("L_INFO", "received after fix_nated_register: " .. KSR.pv.get("$avp(RECEIVED)"))
end


function route_canceling()
    if KSR.siputils.is_method("CANCEL") then
        if KSR.tm.t_check_trans() == false then
            return 
    end
end

function route_withindlg()
    if not KSR.siputils.has_totag() then
        return -1  --  If totag not found return -1 
    end


    if KSR.tm.loose_route() then
        return 1  -- If use loose_route return 1
    end

    -- if use loose_route next route go to route DLURI
    if KSR.tm.loose_route_mode("1") then
        KSR.route("DLGURI")  
    end

    if KSR.siputils.is_method("ACK") then
        if KSR.tm.t_check_trans() then
            return 1  -- Continue if transaction found
        else
            return  -- Exit if transaction not found
        end
    end
    KSR.sl.send_reply(404, "Not here")
    return  -- Exit from this route
end


function route_relay()
    if KSR.siputils.is_method("INVITE") then
        if not KSR.tm.t_is_set("branch_route") then
            KSR.tm.t_on_branch("ksr_branch_route_manage_branch")
        end

        if not KSR.tm.t_is_set("failure_route") then
            KSR.tm.t_on_failure("ksr_failure_route_manage_failure")
        end
    end
    if KSR.tm.t_relay() < 0 then
        KSR.sl.sl_reply_error()
    end

    return 1  
end

end

function route_sipout()
    KSR.info("===== Executing route SIPOUT\n")
    -- Add the equivalent of SIPOUT logic here
end

function route_auth()
    KSR.info("===== Executing route AUTH\n")
    -- Add the equivalent of AUTH logic here
end

function route_registrar()
    KSR.info("===== Executing route REGISTRAR\n")
    -- Add the equivalent of REGISTRAR logic here
end

function route_routing()
    KSR.info("===== Executing route ROUTING\n")
    -- Add the equivalent of ROUTING logic here
end

function route_location()
    KSR.info("===== Executing route LOCATION\n")
    -- Add the equivalent of LOCATION logic here
    -- Return true/false based on condition
    return false  -- Example return value; modify based on actual logic
end

function route_to_pstn()
    KSR.info("===== Executing route TO_PSTN\n")
    -- Add the equivalent of TO_PSTN logic here
end


function route_sdpmanage()
    KSR.info("===== Executing route SDPMANAGE\n")
    local rtp_media = "replace-origin replace-session-connection media SIP-source-address symmetric"
    if KSR.pv.get("$rb") == nil or KSR.pv.get("$rb") == "" then
        return 
    end
    if (KSR.siputils.is_request() and KSR.siputils.is_method("BYE")) or 
       (KSR.siputils.is_reply() and KSR.pv.get("$rs") > 299) then
        KSR.xlog.xlog("L_INFO", "Method BYE or SIP cause > 299\n")
        KSR.rtpengine.rtpengine_manage("") 
        return
    end
    KSR.rtpengine.rtpengine_manage(rtp_media)
end





-- Equivalent of route[REQINIT] in KEMI Lua

function ksr_route_reqinit()
    -- Equivalent of `set_reply_no_connect()` in KEMI
    KSR.hdr.append("Reply-To: no-connect\r\n")

    -- Check if the source IP is not the server itself
    if KSR.pv.get("$si") ~= KSR.pv.get("$myself") then
        -- Check if the IP is in the ipban shared table
        if KSR.pv.get("$sht(ipban=>$si)") ~= nil then
            KSR.xlog.xdbg("request from blocked IP - " .. KSR.pv.get("$rm") .. 
                " from " .. KSR.pv.get("$fu") .. " (IP:" .. KSR.pv.get("$si") .. ":" .. KSR.pv.get("$sp") .. ")\n")
            return 1 -- Exit the route
        end

        -- Block requests from specific user agents
        if string.match(KSR.pv.get("$ua"), "friendly%-scanner|sipcli|sipvicious|VaxSIPUserAgent|pplsip|Matrix") then
            KSR.sl.send_reply(503, "Service temporary unavailable")
            return 1 -- Exit the route
        end

        -- Pike module check for rate limiting
        if KSR.pike.pike_check_req() < 0 then
            KSR.xlog.xlog("L_ALERT", "ALERT: pike blocking " .. KSR.pv.get("$rm") ..
                " from " .. KSR.pv.get("$fu") .. " (IP:" .. KSR.pv.get("$si") .. ":" .. KSR.pv.get("$sp") .. ")\n")
            KSR.pv.seti("$sht(ipban=>$si)", 1)
            return 1 -- Exit the route
        end
    end

    -- Check and process Max-Forwards header
    if KSR.maxfwd.process_maxfwd(10) < 0 then
        KSR.sl.send_reply(483, "Too Many Hops")
        return 1 -- Exit the route
    end

    -- Respond to OPTIONS requests for keepalive
    if KSR.siputils.is_method("OPTIONS") and KSR.pv.is_myself("$ru") and KSR.pv.get("$rU") == nil then
        KSR.sl.send_reply(200, "Keepalive")
        return 1 -- Exit the route
    end

    -- Sanity check for malformed SIP requests
    if KSR.sanity.sanity_check("17895", 7) < 0 then
        KSR.xlog.xlog("Malformed SIP request from " .. KSR.pv.get("$si") .. ":" .. KSR.pv.get("$sp") .. "\n")
        return 1 -- Exit the route
    end
end
