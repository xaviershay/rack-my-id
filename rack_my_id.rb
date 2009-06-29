require 'openid'
#require 'openid/extensions/sreg'
#require 'openid/extensions/pape'
require 'openid/store/memory'

class RackMyId
  include OpenID::Server

  def call(env)
    request = Rack::Request.new(env)
    if request.path == '/'
      response = get_or_post(request)
    end
    
    (response || Rack::Response.new([], 404)).finish
  end

  def server_root
    "http://localhost:9393/"
  end

  def server
    @server ||= Server.new(OpenID::Store::Memory.new, server_root)
  end

  def get_or_post(request)
    if oidreq = server.decode_request(request.params)
      oidresp = case oidreq
      when CheckIDRequest
        resp = oidreq.answer(true, nil, server_root)
        #add_sreg(oidreq, resp)
        #add_pape(oidreq, resp)
        resp
      else
        server.handle_request(oidreq)
      end
    
      finalize_response(oidresp)
    else    
      Rack::Response.new(xrds_xml, 200, {'Content-Type' => 'application/xrds+xml'})
    end
  end

  def finalize_response(oidresp)
    server.signatory.sign(oidresp) if oidresp.needs_signing
    web_response = server.encode_response(oidresp)

    case web_response.code
    when HTTP_OK
      Rack::Response.new(web_response.body, 200)
    when HTTP_REDIRECT
      Rack::Response.new([], 302, "Location" => web_response.headers['location'])
    else
      Rack::Response.new(web_response.body, 500)
    end
  end

  def r(method, path, params=[])
    Rack::Router.new(method, path, params)
  end

  def xrds_xml
    <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS
  xmlns:xrds="xri://$xrds"
  xmlns="xri://$xrd*($v*2.0)">
<XRD>
  <Service priority="0">
    <Type>#{OpenID::OPENID_2_0_TYPE}</Type>
    <URI>#{server_root}</URI>
  </Service>
</XRD>
</xrds:XRDS>
    EOS
  end
  
end
Rack_my_id = Rack::Builder.new do
  run RackMyId.new
end.to_app